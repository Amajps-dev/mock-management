param (
    [Parameter()]
    [String]$testplan,
    [String]$environment,
    [string]$pat
)
Write-Host $testplan

$baseUri = "https://dev.azure.com/edenred-emea-benefits/567b979f-3c97-4699-9c05-c387fe6bd586/";
$headers = @{Authorization = $auth };
$base64AuthInfo = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes(":$pat"))

$headers = @{ Authorization = "Basic $base64AuthInfo" }       

$jsonbody = @"
{
    "parameters":  "{\"validator\":  \"false\", \"testplan\":  \"$($testplan)\", \"environment\":  \"$($environment)\"}",
    "definition": {
        "id":  91
    }
}
"@

try {
    $buildTriggerResult = Invoke-RestMethod -Uri "$($baseUri)_apis/build/builds?api-version=5.0-preview.5" -Method Post -ContentType "application/json" -Headers $headers -Body $jsonbody;
    Write-Host "Build trigger result: $($buildTriggerResult)"

    $buildStatusResult  = Invoke-RestMethod -Uri "$($baseUri)_apis/build/builds/$($buildTriggerResult.id)?api-version=7.0" -Method Get -Headers $headers;
    Start-Sleep -Seconds 60
    
    while($buildStatusResult.status -eq "inProgress" -or $buildStatusResult.status -eq "notStarted") {
        $buildStatusResult  = Invoke-RestMethod -Uri "$($baseUri)_apis/build/builds/$($buildTriggerResult.id)?api-version=7.0" -Method Get -Headers $headers;
        Write-Host "Build Status:"
        Write-Host "$($buildStatusResult)"
        Start-Sleep -Seconds 60
    }
    
    if($buildStatusResult.result -eq "succeeded") {
        Write-Host "##vso[task.complete result=Succeeded;]Automated tests succeeded"
    }
    else {
        Write-Host "##vso[task.complete result=Failed;]Automated tests failed"
    }
}
catch {
    if($_.ErrorDetails.Message) {
        $errorObject = $_.ErrorDetails.Message | ConvertFrom-Json

        foreach ($validationError in $errorObject.customProperties.ValidationResults) {
            Write-Warning $validationError.message
        }

        Write-Error $errorObject.message
    }

    throw $_.Exception
}