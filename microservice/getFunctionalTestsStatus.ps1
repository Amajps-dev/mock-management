# Verify the functional tests status using $microservicename, $build, and $env. For $env the Environment that triggered the tests have to be provided, not the next one.
# It searches for a Jira filter with name=$microservicename-$env-deployments and checks the functional testing results for all the Test Plans found inside the filter by looking at the Test Executions
# that can be found into each Test Plan with the $build injected into the Summary.
# If no Test Execution with $build in the Summary is found it throws Error.
# If one or more tests are failed inside the Test Execution with $build in name it throws Error.

param (
    [Parameter()]
    [string]$jiraBasicAuth,
    [string]$xrayClientId,
    [string]$xrayClientSecret,
    [string]$microservicename,
    [string]$buildNumber,
    [string]$env,
    [string]$azureDevOpsPat,
    [string]$buildDefinitionId,
    [string]$buildSourceBranchName
)

Start-Sleep -Seconds 300

# # Define Jira API credentials
# $jiraBasicAuth = "Basic U2ViYXN0aWFuLkRVTUlUUkFTQ1VAY29uc3VsdGluZy1mb3IuZWRlbnJlZC5jb206T0pvWlpDYUlvOWlJVE9DRFBqZ2gyNzRB"
# # Jira Xray API credentials
# $xrayClientId = "16258205559740849C7C66F086E6AA73"
# $xrayClientSecret = "129d07843ea6b6e3ebe39969df075443a7d94c4e45ee4512b090b60267047eb1"
# #### REMOVE THE ABOVE HARDCODED LINES



# $commit = git merge-base release/eb/test-functional-tests develop
# $commit
# Write-Host $commit


$microservicename
$buildNumber
$env
$buildDefinitionId
$buildSourceBranchName


$branchName = $buildSourceBranchName
$definitionId = $buildDefinitionId
Write-Host "Search the first commit of the release on branch $($branchName):"
$baseUri = "https://dev.azure.com/edenred-emea-benefits/567b979f-3c97-4699-9c05-c387fe6bd586";
$base64AuthInfo = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes(":$azureDevOpsPat"))

$headers = @{ Authorization = "Basic $base64AuthInfo" }
$branchReleaseResult = Invoke-RestMethod -Uri "$($baseUri)/_apis/build/builds?definitions=$definitionId&branchName=$branchName&api-version=7.0" -Method Get -ContentType "application/json" -Headers $headers
Write-Host "$($branchReleaseResult.count) commit(s):"
$branchReleaseResult.value | ForEach-Object { Write-Host "    $($_.buildNumber)    $($_.sourceVersion)" }

$firstRelease = $branchReleaseResult.value | Sort-Object @{Expression={ $_.startTime }; Ascending=$true} | Select-Object -First 1
Write-Host "$($firstRelease.buildNumber)    $($firstRelease.sourceVersion) is the first commit of this release"

Write-Host ""
Write-Host "Search the commit on develop from which this release was created:"
$branchName = "refs/heads/develop"

$mainReleaseResult = Invoke-RestMethod -Uri "$($baseUri)/_apis/build/builds?definitions=$definitionId&branchName=$branchName&api-version=7.0" -Method Get -ContentType "application/json" -Headers $headers
Write-Host "$($mainReleaseResult.count) runs for the develop branch"
$mainReleaseResult.value | ForEach-Object { Write-Host "    $($_.buildNumber)    $($_.sourceVersion)" }

$releaseToCheck = $mainReleaseResult.value | Where-Object { $_.sourceVersion -eq $firstRelease.sourceVersion } | Sort-Object @{Expression={ $_.finishTime }; Ascending=$true} | Select-Object -First 1
Write-Host "$($releaseToCheck.buildNumber) $($releaseToCheck.sourceVersion) on $branchName"
$buildNumber = $releaseToCheck.buildNumber






# Filter name to searh in Jira
$filterName = "$microservicename-$env-deployments"

# String used to identify the execution triggered for build
$stringInExecutionName = "build: $buildNumber"
Write-Host "Searching tests results for $microservicename $stringInExecutionName"

# Define a list to store the execution ID and summary of the failed ones
$failedExecutions = @()

# Define baseURLs
$jiraUrl = "https://smarter-edenred.atlassian.net/"
$xrayUrl = "https://xray.cloud.getxray.app/"
$getPlanUrl = "$xrayUrl/api/v2/graphql"


#Retry function
function Invoke-RestMethodWithRetry($method, $url, $headers, $body) {
    # Define retry parameters
    $maxRetryCount = 5
    $retryInterval = 3  # seconds

    $retryCount = 0
    while ($true) {
        try {
            $retryCount++
            # Call REST API
            $response = Invoke-RestMethod -Uri $url -Method $method -Headers $headers -Body $body
            return $response
        }
        catch {
            if ($retryCount -ge $maxRetryCount) {
                Write-Error "Max retries reached. An error occurred: $_"
                return $null
            }
            else {
                Write-Warning "Attempt $retryCount of $maxRetryCount failed. Waiting $retryInterval seconds before retrying..."
                Write-Host "Error Details: $($_.Exception.Message)"
                Start-Sleep -Seconds $retryInterval
            }
        }
    }
}

# Call Jira REST API to get filter ID using filter name
# Define headers
$headers = @{
    Authorization = $jiraBasicAuth
    ContentType = "application/json"
}
Write-Host "Searching for filter with name: $filterName"
$filterUrl = "$jiraUrl/rest/api/3/filter/search?maxResults=50&filterName=$filterName&startAt=0"
$filterResponse = Invoke-RestMethodWithRetry "GET" $filterUrl $headers $null
if ($filterResponse -eq $null) { return }
if ($filterResponse.values.Count -eq 0) {
    Write-Warning "No filter found with the name: $filterName"
    Write-Host "##vso[task.complete result=SucceededWithIssues;]No filter found with the name: $filterName"
    return
}
if ($filterResponse.values.Count -gt 1) {
    Write-Error "More than one filter found with the name: $filterName. Only 1 filter per microservice is supported."
    return
}
$filterId = $filterResponse.values[0].id
Write-Host "Filter found with ID: $filterId"

# Call Jira REST API to get issues for the filter
Write-Host "Retrieving Test Plans in filter with ID: $filterId"
$issueUrl = "$jiraUrl/rest/api/3/search?jql=filter=$filterId&fields=summary"
$searchFilterResponse = Invoke-RestMethodWithRetry "GET" $issueUrl $headers $null
if ($searchFilterResponse -eq $null) { return }

# Send the request to get the Xray token
# Define the headers and body for the get Xray token request
$headers1 = @{
    "Content-Type" = "application/json"
}
$body1 = @{
    "client_id" = "$xrayClientId"
    "client_secret" = "$xrayClientSecret"
} | ConvertTo-Json
$tokenUrl = "$xrayUrl/api/v2/authenticate"
$response1 = Invoke-RestMethodWithRetry "POST" $tokenUrl $headers1 $body1
$token = $response1

# Check if the token is retrieved correctly
if (!$token) {
    Write-Host "Failed to retrieve token"
    exit
}else
{
    Write-Host "Xray token retrieved."
}

# Extract Test plans in filter and check status for each
[int]$executionPageSize = 100

$searchFilterResponse.issues | ForEach-Object {
    $startAt = 0  # Initialize the start index for pagination

    Write-Output ("`n######################################################################`n")
    Write-Output ("Found Test Plan: " + $_.key + ", Summary: " + $_.fields.summary + ", ID: " + $_.id)
    Write-Host "Checking Test plan status in Jira Xray..."

    # Define the headers and body for the request that retrieves the Test plan details
    $headers2 = @{
        "Content-Type" = "application/json"
        "Authorization" = "Bearer $token"
    }

    # Declare a new array to store all test executions pages found in the test plan
    $allExecutionsPages = @()

    while ($true) {  # Loop for pagination
        Write-Host "Saving executions page starting with: $startAt"

        $body2 = @{
            "query" = "query {getTestPlan(issueId: `"" + $_.id + "`") {issueId jira(fields: [`"summary`", `"key`"]) testExecutions(start: $startAt, limit: $executionPageSize) {results {issueId jira(fields: [`"key`",`"summary`",`"created`"]) testRuns(limit: 100) {results {status { name } }} }}}}"
        } | ConvertTo-Json

        # Send the request to get the Test plan details
        $response2 = Invoke-RestMethodWithRetry "POST" $getPlanUrl $headers2 $body2
        $allExecutionsPages += $response2.data.getTestPlan.testExecutions.results
        # Update the start index for the next page
        $startAt += $executionPageSize

        # Break the loop if the number of fetched executions is less than the page size
        if ($response2.data.getTestPlan.testExecutions.results.Count -lt $executionPageSize) {
            Write-Host "Finished saving all executions found in Test Plan"
            break
        }
    }

    Write-Host "Total number of executions:" $allExecutionsPages.Count

    # Saving Test Plan Key and Summary
    $xrayTestPlanKey = $response2.data.getTestPlan.jira.key

    Write-Host "Plan retrieved from Jira Xray. Checking plan details."

    # Iterate over the execution summaries and keys and if the execution Summary contains provided string check if there are failed tests
    $latestExecutionIndex = -1
    $latestExecutionTime = [DateTime]::MinValue
    $executionCount = 0

    for ($i = 0; $i -lt $allExecutionsPages.jira.summary.Count; $i++) {
        # Check if the Summary contains the expected string (build)
        if ($allExecutionsPages[$i].jira.summary -match "$stringInExecutionName") {
            $executionCount++
            Write-Host "`nFound Execution for build with Key: $($allExecutionsPages[$i].jira.key), Summary: $($allExecutionsPages[$i].jira.summary). TIME: $($allExecutionsPages[$i].jira.created)"

            # Check if the current execution is more recent than the latest found
            $currentExecutionTime = [DateTime]::Parse($allExecutionsPages[$i].jira.created, [System.Globalization.CultureInfo]::InvariantCulture)
            if ($currentExecutionTime -gt $latestExecutionTime) {
                $latestExecutionTime = $currentExecutionTime
                $latestExecutionIndex = $i
            }
        }
    }

    # Selecting the most recent Test Execution for reviewing the status
    if ($executionCount -gt 1) {
        Write-Host "`nMore than 1 Test Execution found for build. Using the lastest: $($allExecutionsPages[$latestExecutionIndex].jira.key) created at: $($allExecutionsPages[$latestExecutionIndex].jira.created)"
    }

    # If no execution is found for build the tests are still in progress or other issue occurred
    if ($latestExecutionIndex -eq -1) {
        Write-Host "No execution found for provided build! The tests are still in progress or other issue occurred."

        $failedExecutions += @{
            PlanKey = $xrayTestPlanKey
            ErrorMessage = "No execution found for the build"
        }
    } else {
        # Get the test runs for the most recent execution
        $testRuns = $allExecutionsPages[$latestExecutionIndex].testRuns.results
        Write-Host "`nChecking execution status..."
        # Check if any test is failed
        foreach ($testRun in $testRuns) {
            if ($testRun.status.name -eq "FAILED") {
                Write-Host "Test failed in execution with key: $($allExecutionsPages[$latestExecutionIndex].jira.key)"

                # Save the execution ID and summary of the failed one
                $failedExecutions += @{
                    ExecutionID = $($allExecutionsPages[$latestExecutionIndex].jira.key)
                    Summary = $allExecutionsPages[$latestExecutionIndex].jira.summary
                    PlanKey = $xrayTestPlanKey
                }
                break
            }
        }
    }
}

Write-Output ("`n######################################################################`n")

# Print the list of failed executions
foreach ($failedExecution in $failedExecutions) {
    Write-Host "Error:"
    if ($null -ne $failedExecution.ErrorMessage) {
        Write-Host "$($failedExecution.ErrorMessage) in Test Plan with Key: $($failedExecution.PlanKey)"
    } else {
        Write-Host "Failed tests found in Execution with key: $($failedExecution.ExecutionID), Summary: $($failedExecution.Summary), Plan key: $($failedExecution.PlanKey)"
    }
}

# Check if any failures occurred and throw an error if there are any
if ($failedExecutions.Count -gt 0) {
    $failedTestPlans = $failedExecutions | ForEach-Object { $_.PlanKey } | Sort-Object -Unique
    $failedTestPlansList = [string]::Join(", ", $failedTestPlans)
    throw "Failures occurred for the following Test Plans: $failedTestPlansList"
} else {
    Write-Host "Success: All tests passed for all test plans."
}