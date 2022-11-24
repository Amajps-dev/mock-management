param ($microservice)

$appConfigurationName = "smarterconfiguration"
$settingsFilePath = "./$microservice/settings.json"
$secretsFilePath = "./$microservice/secrets.json"
$featuresFilePath = "./$microservice/features.json"
$settingsVersion = "1.0.0" | ConvertTo-Json

Write-Host "Importing settings to AppConfiguration"
az appconfig kv import -n $appConfigurationName -s file --path $settingsFilePath --format json --label $microservice --content-type "application/json" -y

Write-Host "Importing secrets to AppConfiguration"
az appconfig kv import -n $appConfigurationName -s file --path $secretsFilePath --format json --label $microservice --content-type "application/vnd.microsoft.appconfig.keyvaultref+json;charset=utf-8" --yes 

Write-Host "Importing features to AppConfiguration"
$features = Get-Content -Raw $featuresFilePath | ConvertFrom-Json
$features.PSObject.Properties | ForEach-Object {
    $featureName = $_.Name
    $description = $_.Value.Description
    az appconfig feature set -n $appConfigurationName --feature $featureName --label $microservice --description $description -y --output none
}

Write-Host "Delete AppConfiguration settings not in settings.json"
$appConfigSettings = az appconfig kv list -n $appConfigurationName --label $microservice | ConvertFrom-Json | Where-Object { $_.contentType -eq "application/json" }
$settings = Get-Content -Raw $settingsFilePath | ConvertFrom-Json
$appConfigSettings | ForEach-Object {
    $setting = $settings.PSObject.Properties[$_.Key]
    
    if($setting -eq $null)
    {
        az appconfig kv delete -n $appConfigurationName --key $_.Key --label $microservice -y --output none
        Write-Host "    Deleted $($_.Key)"
    }
}

Write-Host "Delete AppConfiguration secrets not in secrets.json"
$appConfigSecrets = az appconfig kv list -n $appConfigurationName --label $microservice | ConvertFrom-Json | Where-Object { $_.contentType -eq "application/vnd.microsoft.appconfig.keyvaultref+json;charset=utf-8" }
$secrets = Get-Content -Raw $secretsFilePath | ConvertFrom-Json
$appConfigSecrets | ForEach-Object {
    $secret = $secrets.PSObject.Properties[$_.Key]
    if($secret -eq $null)
    {
        az appconfig kv delete -n $appConfigurationName --key $_.Key --label $microservice -y --output none
        Write-Host "    Deleted $($_.Key)"
    }
}

Write-Host "Delete AppConfiguration features not in features.json"
$appConfigFeatures = az appconfig feature list -n $appConfigurationName --label $microservice | ConvertFrom-Json
$appConfigFeatures | ForEach-Object {
    $feature = $features.PSObject.Properties[$_.Name]
    if($feature -eq $null)
    {
        az appconfig feature delete -n $appConfigurationName --feature $_.Name --label $microservice -y --output none
        Write-Host "    Deleted $($_.Name)"
    }
}

Write-Host "Update sentinel version in AppConfiguration"
az appconfig kv set -n $appConfigurationName --key Sentinel --value $settingsVersion --label $microservice -y --output none
Write-Host "    Sentinel updated to version $settingsVersion"
