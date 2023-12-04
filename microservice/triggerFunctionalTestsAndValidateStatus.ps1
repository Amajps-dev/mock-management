# Starts the functional tests using $microservicename, $build, and $env
# It searches for a Jira filter with name=$microservicename-$env-deployments and triggers the functional testing pipeline for all the Test Plans found inside the filter.
# The results can be found into each Test Plan as a new created Test Execution with the $build injected into the Summary

# Verify the functional tests status each 60 seconds for 10 minutes, using $microservicename, $build, and $env. For $env the Environment that triggered the tests have to be provided, not the next one.
# It searches for a Jira filter with name=$microservicename-$env-deployments and checks the functional testing results for all the Test Plans found inside the filter by looking at the Test Executions
# that can be found into each Test Plan with the $build injected into the Summary.
# If no Test Execution with $build in the Summary is found it throws Error.
# If one or more tests are failed inside the Test Execution with $build in name it throws Error.

param (
    [Parameter()]
    [string]$azureDevOpsPat,
    [string]$jiraBasicAuth,
    [string]$env,
    [string]$microservicename,
    [string]$build,
    [string]$xrayClientId,
    [string]$xrayClientSecret
)


# Maximum wait time (900 seconds) and interval time (60 seconds)
$maxWaitTime = 900
$intervalTime = 60

# String to be added alongside with Jira summary. Needed for checking results. Eg:  | build: Angelica-123.0
$addToSummary = " | build: $build"

# String to validate results. A different one is needed as the pipe "|" breaks the script
$stringInExecutionName = "build: $build"

# Filter name that will be searched in Jira
$filterName = "$microservicename-$env-deployments"

# Define baseURLs
$azureUrl = "https://dev.azure.com/edenred-emea-benefits/567b979f-3c97-4699-9c05-c387fe6bd586/"
$jiraUrl = "https://smarter-edenred.atlassian.net/"
$xrayUrl = "https://xray.cloud.getxray.app/"
$tokenUrl = "$xrayUrl/api/v2/authenticate"
$getPlanUrl = "$xrayUrl/api/v2/graphql"

# Define Azure DevOps API credentials
$base64AuthInfo = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes(":$azureDevOpsPat"))
$headersAzureDevOps = @{ Authorization = "Basic $base64AuthInfo" }

# Define headers
$headers = @{
    Authorization = "Basic $jiraBasicAuth"
    ContentType = "application/json"
}

# Define the headers and body for the get Xray token request
$xrayHeaders = @{
    "Content-Type" = "application/json"
}
$xrayBody = @{
    "client_id" = "$xrayClientId"
    "client_secret" = "$xrayClientSecret"
} | ConvertTo-Json

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

# Get Xray token function
function GetXrayToken($tokenUrl, $xrayHeaders, $xrayBody) {
    $response = Invoke-RestMethodWithRetry -Method "POST" -Url $tokenUrl -Headers $xrayHeaders -Body $xrayBody

    if (!$response) {
        Write-Host "Failed to retrieve token"
        exit
    }

    Write-Host "Xray token retrieved."
    return $response
}

# Call Jira REST API to get filter ID using filter name
Write-Host "Searching for filter with name: $filterName"
$filterUrl = "$jiraUrl/rest/api/3/filter/search?maxResults=50&filterName=$filterName&startAt=0"
$filterResponse = Invoke-RestMethodWithRetry "Get" $filterUrl $headers -$null
if ($filterResponse -eq $null) { return }
if ($filterResponse.values.Count -eq 0) {
    Write-Warning "No filter found with the name: $filterName"
    return
}
if ($filterResponse.values.Count -gt 1) {
    Write-Error "More than one filter found with the name: $filterName. Only 1 filter per microservice is supported."
    return
}
$filterId = $filterResponse.values[0].id
Write-Host "Filter found with ID: $filterId"

# Call Jira REST API to get Xray Test plans from the filter
Write-Host "Retrieving Test Plans in filter with ID: $filterId"
$issueUrl = "$jiraUrl/rest/api/3/search?jql=filter=$filterId&fields=summary&maxResults=5000"
$testPlansInFilter = Invoke-RestMethodWithRetry -method "Get" -url $issueUrl -headers $headers
$foundTestPlansCount = $testPlansInFilter.issues.Count
Write-Host "Found Test plans number: $foundTestPlansCount"


if ($testPlansInFilter -eq $null) { return }

# Extract issue keys and summaries and trigger for each the Functional test pipeline
Write-Host "`nStarting execution for filter results..."

$testPlansInFilter.issues | ForEach-Object {

    # Concatenate build number if provided using $addToSummary. Can be used later to verify status of triggered executions
    $finalSummary = $_.fields.summary + $addToSummary

    Write-Host ("`n######################################################################`n")
    Write-Host ("Starting execution of Test Plan: " + $_.key + "`nSummary: " + $finalSummary + "`nID: " + $_.id)

    # Define the parameters for the build
    $executionkey = $_.key # using test plan key as execution key
    $testplankey = $executionkey # providing same test plan for reporting results
    $definitionId = 561

    $jsonbody = @"
{
    "parameters":  "{\"summary\":  \"$finalSummary\", \"validator\":  \"false\", \"executionkey\":  \"$executionkey\", \"cloneexecution\": \"true\", \"testplankey\":  \"$testplankey\"}",
    "definition":  {
                       "id":  $definitionId
                   }
}
"@

             try {
                 # trigger the pipeline
                 $result = Invoke-RestMethod -Uri "$($azureUrl)_apis/build/builds?api-version=5.0-preview.5" -Method Post -ContentType "application/json" -Headers $headersAzureDevOps -Body $jsonbody
                 Write-Host "Triggered functional pipeline with ID: $($result.buildnumber)"
             }
             catch {
                 if ($_.ErrorDetails.Message) {
                     $errorObject = $_.ErrorDetails.Message | ConvertFrom-Json
                     foreach ($validationError in $errorObject.customProperties.ValidationResults) {
                         Write-Warning $validationError.message
                     }
                     Write-Error $errorObject.message
                 }
                 throw $_.Exception
             }


}

# Saving test started time
$testsStartedTime = [DateTime]::Parse((Get-Date).ToString("o"), [System.Globalization.CultureInfo]::InvariantCulture)
Write-Host "Tests triggered at: $testsStartedTime"

Write-Host ("`n######################################################################`n")

# Send the request to get the Xray token
$token = GetXrayToken $tokenUrl $xrayHeaders $xrayBody

# Define the headers for Test plan details req
$getTestPlanDetailsHeaders = @{
    "Content-Type" = "application/json"
    "Authorization" = "Bearer $token"
}

# Checking results
$elapsedTime = 0
while ($elapsedTime -lt $maxWaitTime) {
    Write-Host "Waiting $intervalTime seconds before checking test results. Time elapsed: $elapsedTime seconds. Max wait time: $maxWaitTime seconds..."
    Start-Sleep -Seconds $intervalTime
    $elapsedTime += $intervalTime

    # Executions with no failed tests
    $passedExecutionsKeys = @()
    # Define a list to store the execution ID and summary of the failed ones
    $failedExecutions = @()
    # Total number of executions that match the build in all test plans
    [int]$validExecutionsForBuild = 0

    # Extract Test plans in filter and check status for each
    [int]$executionPageSize = 100

    $testPlansInFilter.issues | ForEach-Object {
        $startAt = 0  # Initialize the start index for pagination

        Write-Host ("`n######################################################################`n")
        Write-Host ("Reviewing Test Plan: " + $_.key + ", Summary: " + $_.fields.summary + ", ID: " + $_.id)
        Write-Host "Checking Test plan status in Jira Xray..."

        # Declare a new array to store all test executions pages found in the test plan
        $allExecutionsPages = @()

        while ($true) {  # Loop for pagination
            Write-Host "Saving Test Plan executions pages starting with: $startAt"

            $getTestPlanDetailsBody = @{
                "query" = "query {getTestPlan(issueId: `"" + $_.id + "`") {issueId jira(fields: [`"summary`", `"key`"]) testExecutions(start: $startAt, limit: $executionPageSize) {results {issueId jira(fields: [`"key`",`"summary`",`"created`"]) testRuns(limit: 100) {results {status { name } }} }}}}"
            } | ConvertTo-Json

            # Send the request to get the Test plan details
            $testPlanDetailsResponse = Invoke-RestMethodWithRetry -method "POST" -url $getPlanUrl -headers $getTestPlanDetailsHeaders -body $getTestPlanDetailsBody
            $allExecutionsPages += $testPlanDetailsResponse.data.getTestPlan.testExecutions.results
            # Update the start index for the next page
            $startAt += $executionPageSize

            # Break the loop if the number of fetched executions is less than the page size
            if ($testPlanDetailsResponse.data.getTestPlan.testExecutions.results.Count -lt $executionPageSize) {
                Write-Host "Finished saving all executions found in Test Plan"
                break
            }
        }

        Write-Host "Total number of executions found in Test Plan:" $allExecutionsPages.Count

        # Saving Test Plan Key and Summary
        $xrayTestPlanKey = $testPlanDetailsResponse.data.getTestPlan.jira.key

        Write-Host "Plan retrieved from Jira Xray. Checking plan details."

        # Iterate over the execution summaries and keys and if the execution Summary contains provided string check if there are failed tests
        $latestExecutionIndex = -1
        $latestExecutionTime = [DateTime]::MinValue

        for ($i = 0; $i -lt $allExecutionsPages.jira.summary.Count; $i++) {
            # Save execution created time
            $currentExecutionTime = [DateTime]::Parse($allExecutionsPages[$i].jira.created, [System.Globalization.CultureInfo]::InvariantCulture)

            # Check if the Summary contains the expected string (build) and that the execution is started after the tests are triggered above
            if ($allExecutionsPages[$i].jira.summary -match "$stringInExecutionName" -and $currentExecutionTime -gt $testsStartedTime) {
                Write-Host "`nFound Execution for build with Key: $($allExecutionsPages[$i].jira.key), Summary: $($allExecutionsPages[$i].jira.summary). TIME: $($allExecutionsPages[$i].jira.created)"
                $latestExecutionIndex = $i
            }
        }

        # If no execution is found for build the tests are still in progress or other issue occurred
        if ($latestExecutionIndex -eq -1) {
            Write-Host "No execution found for provided build. The tests are still in progress or other issue occurred."

            $failedExecutions += @{
                PlanKey = $xrayTestPlanKey
                ErrorMessage = "No execution found for the build"
            }
        } else {
            $validExecutionsForBuild +=1
            # Get the test runs for the most recent execution
            $testRuns = $allExecutionsPages[$latestExecutionIndex].testRuns.results
            Write-Host "`nChecking Execution status..."
            # Check if any test is failed
            $hasFailedTest = $false
            foreach ($testRun in $testRuns) {
                if ($testRun.status.name -eq "FAILED") {
                    Write-Host "Test failed in execution with key: $($allExecutionsPages[$latestExecutionIndex].jira.key)"

                    # Save the execution ID and summary of the failed one
                    $failedExecutions += @{
                        ExecutionID = $($allExecutionsPages[$latestExecutionIndex].jira.key)
                        Summary = $allExecutionsPages[$latestExecutionIndex].jira.summary
                        PlanKey = $xrayTestPlanKey
                    }
                    $hasFailedTest = $true
                    break
                }
            }
            if (-not $hasFailedTest) {
                $passedExecutionsKeys += $($allExecutionsPages[$latestExecutionIndex].jira.key)
                Write-Host "All Execution tests passed."
            }
        }
    }

    Write-Host ("`n######################################################################`n")

    # Exit the while loop if a number of failed or passed executions is equal to the number of test plans started
    if($validExecutionsForBuild -eq $foundTestPlansCount) {
        break
    }
}


# Print the list of failed executions
foreach ($failedExecution in $failedExecutions) {
    if ($null -ne $failedExecution.ErrorMessage) {
        Write-Error "$($failedExecution.ErrorMessage) in Test Plan with Key: $($failedExecution.PlanKey)"
    } else {
        Write-Error "Failed tests found in Execution with key: $($failedExecution.ExecutionID), Summary: $($failedExecution.Summary), Plan key: $($failedExecution.PlanKey)"
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