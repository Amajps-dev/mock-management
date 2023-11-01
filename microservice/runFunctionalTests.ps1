# Starts the functional tests using $microservicename, $build, and $env
# It searches for a Jira filter with name=$microservicename-$env-deployments and triggers the functional testing pipeline for all the Test Plans found inside the filter.
# The results can be found into each Test Plan as a new created Test Execution with the $build injected into the Summary

param (
    [Parameter()]
    [string]$azureDevOpsPat,
    [string]$jiraBasicAuth,
    [string]$env,
    [string]$microservicename,
    [string]$build,
    [string]$addToSummary
)

#String to be added alongside with Jira summary. Needed for checking results. Eg:  | build: Angelica-123.0
$addToSummary = " | build: $build"

# Filter name that will be searched in Jira
$filterName = "$microservicename-$env-deployments"

# Define Jira baseURL
$jiraUrl = "https://smarter-edenred.atlassian.net/"

# Define Azure DevOps API credentials
$base64AuthInfo = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes(":$azureDevOpsPat"))
$headersAzureDevOps = @{ Authorization = "Basic $base64AuthInfo" }

# Define headers
$headers = @{
    Authorization = "Basic $jiraBasicAuth"
    ContentType = "application/json"
}

#Retry function
function Get-DataFromApi($url) {
    # Define retry parameters
    $maxRetryCount = 5
    $retryInterval = 3  # seconds

    $retryCount = 0
    while ($true) {
        try {
            $retryCount++
            # Call Jira REST API
            $response = Invoke-RestMethod -Uri $url -Method Get -Headers $headers
            return $response
        }
        catch {
            if ($retryCount -ge $maxRetryCount) {
                Write-Error "Max retries reached. An error occurred: $_"
                return $null
            }
            else {
                Write-Warning "Attempt $retryCount of $maxRetryCount failed. Waiting $retryInterval seconds before retrying..."
                Start-Sleep -Seconds $retryInterval
            }
        }
    }
}

# Call Jira REST API to get filter ID using filter name
Write-Host "Searching for filter with name: $filterName"
$filterUrl = "$jiraUrl/rest/api/3/filter/search?maxResults=50&filterName=$filterName&startAt=0"
$filterResponse = Get-DataFromApi $filterUrl
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

# Call Jira REST API to get issues for the filter
Write-Host "Retrieving Test Plans in filter with ID: $filterId"
$issueUrl = "$jiraUrl/rest/api/3/search?jql=filter=$filterId&fields=summary"
$issueResponse = Get-DataFromApi $issueUrl
if ($issueResponse -eq $null) { return }

# Extract issue keys and summaries and trigger for each the Functional test pipeline
Write-Host "`nStarting execution for filter results..."

$issueResponse.issues | ForEach-Object {

    # Concatenate build number if provided using $addToSummary. Can be used later to verify status of triggered executions
    $finalSummary = $_.fields.summary + $addToSummary

    Write-Output ("`n######################################################################`n")
    Write-Output ("Starting execution of Test Plan: " + $_.key + "`nSummary: " + $finalSummary + "`nID: " + $_.id)

    $baseUri = "https://dev.azure.com/edenred-emea-benefits/567b979f-3c97-4699-9c05-c387fe6bd586/"

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
        $result = Invoke-RestMethod -Uri "$($baseUri)_apis/build/builds?api-version=5.0-preview.5" -Method Post -ContentType "application/json" -Headers $headersAzureDevOps -Body $jsonbody
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

Write-Output ("`n######################################################################`n")