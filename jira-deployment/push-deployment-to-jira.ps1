param (
  [Parameter()]
  [String]$pat,
  [String]$jiraApiClientSecret,
  [String]$environment,
  [String]$state,
  [string]$buildId,
  [string]$buildNumber,
  [string]$buildDefinitionId,
  [string]$repositoryName
)

try
{
  Write-Host "pat: $pat"
  Write-Host "jiraApiClientSecret: $jiraApiClientSecret"
  Write-Host "environment: $environment"
  Write-Host "state: $state"
  Write-Host "buildId: $buildId"
  Write-Host "buildNumber: $buildNumber"
  Write-Host "buildDefinitionId: $buildDefinitionId"
  Write-Host "repositoryName: $repositoryName"
  Write-Host ""

  switch ($environment)
  {
      "dev" { $environmentType = 'development' }
      "uat" { $environmentType = 'testing' }
      "prod" { $environmentType = 'production' }
      "staging" { $environmentType = 'staging' }
      default {
        Write-Host "##vso[task.logissue type=error]Environment $environment is not supported."
      }
  }

  Write-Host "Jira environment = $environment"

  switch ($state)
  {
      "pending" { $state = 'pending' }
      "InProgress" { $state = 'in_progress' }
      "Succeeded" { $state = 'successful' }
      "Canceled" { $state = 'cancelled' }
      "Failed" { $state = 'failed' }
      "rolledBack" { $state = 'rolled_back' }
      default {
        Write-Host "##vso[task.logissue type=error]State $state is not supported."
      }
  }

  Write-Host "Jira state = $state"
  Write-Host ""
  Write-Host "Get issues"

  $azureDevOpsBaseUrl = "https://dev.azure.com/edenred-emea-benefits/SmartER"

  $base64AuthInfo = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes(":$pat"))
  $headers = @{ Authorization = "Basic $base64AuthInfo" }      
  $getBuildChangeResult = Invoke-WebRequest -URI "$azureDevOpsBaseUrl/_apis/build/builds/$buildId/changes?top=30api-version=7.0" -Method Get -ContentType "application/json" -Headers $headers
  $changes = ($getBuildChangeResult.content | ConvertFrom-Json).value

  $issues = $changes | Select-Object -Property message | Select-String "(lot|ltt|lct|lut|ldt)-([0-9]+)" -AllMatches 
  if($issues.count -eq 0)
  {
    Write-Host "##vso[task.complete result=SucceededWithIssues;]No deployment information to push to Jira."
    exit
  }

  $issues = $issues | ForEach-Object matches | ForEach-Object Value | Select-Object –unique
  $issues = $issues | ForEach-Object { $_.ToUpper() }
  $issues = $issues | Join-String -Property {"$($_)"} -DoubleQuote -Separator ', '

  Write-Host "$issues"
  Write-Host ""

  $getJwtBody = @{
    audience = "api.atlassian.com"
    grant_type = "client_credentials"
    client_id = "kQ1hqYpUdjIWTorIH7rPOn5VmMZohdU9"
    client_secret = $jiraApiClientSecret
  } | ConvertTo-Json

  $getJwtResult = Invoke-WebRequest -URI "https://api.atlassian.com/oauth/token" -Method Post -ContentType "application/json" -Body $getJwtBody
  $jwt = ($getJwtResult.content | ConvertFrom-Json).access_token

  $pipelineUrl = "$azureDevOpsBaseUrl/_build/results?buildId=$buildId&view=results"
  $buildDefinitionUrl = "$azureDevOpsBaseUrl/_build?definitionId=$buildDefinitionId&_a=summary"

  $environmentDisplayName = $environment.SubString(0,1).ToUpper()+$environment.SubString(1)
  $deploymentBody = @"
{
  "deployments": [
    {
      "deploymentSequenceNumber": "$buildId",
      "updateSequenceNumber": $((get-date).ticks),
      "associations": [
        {
          "associationType": "issueIdOrKeys",
          "values": [$issues]
        }
      ],
      "displayName": "$repositoryName/$buildNumber",
      "lastUpdated": "$(Get-Date (Get-Date).ToUniversalTime() -UFormat '+%Y-%m-%dT%H:%M:%S.000Z')",
      "url": "$pipelineUrl",
      "description": "$buildNumber",
      "label": "deployment",
      "state": "$state",
      "pipeline": {
        "id": "$buildId",
        "displayName": "$repositoryName",
        "url": "$buildDefinitionUrl"
      },
      "environment": {
        "id": "$environment",
        "displayName": "$environmentDisplayName",
        "type": "$environmentType"
      },
      "schemaVersion": "1.0"
    }
  ]
}
"@

  Write-Host "Deployment information: $deploymentBody"

  $uri = "https://api.atlassian.com/jira/deployments/0.1/cloud/c86a6e11-6458-49f0-a12b-e051525287f7/bulk"
  $headers = @{Authorization = "Bearer $jwt" };
  $pushDeploymentResult = Invoke-RestMethod -Uri $uri -Method Post -ContentType "application/json" -Headers $headers -Body $deploymentBody

  Write-Host ($pushDeploymentResult | Format-Table | Out-String)

  if ($pushDeploymentResult.acceptedDeployments -ne $null) 
  {
    Write-Host ($pushDeploymentResult.acceptedDeployments | Format-Table | Out-String)
  }
  
  if ($pushDeploymentResult.rejectedDeployments -ne $null) 
  {
    Write-Host "##vso[task.logissue type=error]Push deployment information to Jira failed".
  }
  if ($pushDeploymentResult.unknownAssociations -ne $null) 
  {
    Write-Host "##vso[task.logissue type=error]]Push deployment information to Jira succeeded with issues: $($pushDeploymentResult.unknownAssociations)."
  }
}
catch 
{
  Write-Host "An error occurred:"
  Write-Host $_
}
