param ($microservice, $environment)

$appConfigurationName = "smarterconfiguration"
$settingsFilePath = "./$microservice/$environment/settings.json"
$secretsFilePath = "./$microservice/$environment/secrets.json"
$featuresFilePath = "./$microservice/$environment/features.json"

Write-Host "Plan settings"
Write-Host "To be added" -ForegroundColor Green
$appConfigSettings = az appconfig kv list -n $appConfigurationName --label $microservice | ConvertFrom-Json | Where-Object { $_.contentType -eq "application/json" }
$settings = Get-Content -Raw $settingsFilePath | ConvertFrom-Json
$settings.PSObject.Properties | ForEach-Object {
    $settingName = $_.Name
    $appConfigSetting = $appConfigSettings | Where-Object { $_.key -eq $settingName }

    if ($appConfigSetting -eq $null) {
        Write-Host "$($_.Name)" -ForegroundColor Green
        Write-Host "    $($_.Value)" -ForegroundColor Green
    }
}

Write-Host "To be updated" -ForegroundColor Yellow
$settings.PSObject.Properties | ForEach-Object {
    $settingName = $_.Name
    $appConfigSetting = $appConfigSettings | Where-Object { $_.key -eq $settingName }

    if($appConfigSetting  -ne $null)
    {
        $appConfigSettingValue = $appConfigSetting.Value.Trim('"')

        if($_.Value -ne $appConfigSettingValue)
        {
            Write-Host "$($_.Name)" -ForegroundColor Yellow
            Write-Host "    $($appConfigSettingValue)" -ForegroundColor Yellow
            Write-Host "    $($_.Value)" -ForegroundColor Yellow
        }
    }
}

Write-Host "To be deleted" -ForegroundColor Red
$appConfigSettings | ForEach-Object {
    $setting = $settings.PSObject.Properties[$_.Key]
    
    if($setting -eq $null)
    {
        Write-Host "$($_.key)" -ForegroundColor Red
        Write-Host "    $($_.Value.Trim('"'))" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "Plan secrets"
Write-Host "To be added" -ForegroundColor Green
$appConfigSecrets = az appconfig kv list -n $appConfigurationName --label $microservice | ConvertFrom-Json | Where-Object { $_.contentType -eq "application/vnd.microsoft.appconfig.keyvaultref+json;charset=utf-8" }
$secrets = Get-Content -Raw $secretsFilePath | ConvertFrom-Json
$secrets.PSObject.Properties | ForEach-Object {
    $secretName = $_.Name
    $appConfigSecret = $appConfigSecrets | Where-Object { $_.key -eq $secretName}

    if ($appConfigSecret -eq $null) {
        Write-Host "$($_.Name)" -ForegroundColor Green
        Write-Host "    $($_.Value)" -ForegroundColor Green
    }
}

Write-Host "To be updated" -ForegroundColor Yellow
$secrets.PSObject.Properties | ForEach-Object {
    $secretName = $_.Name
    $appConfigSecret = $appConfigSecrets | Where-Object {
        $_.key -eq $secretName 
    }

    if($appConfigSecret -ne $null)
    {
        $appConfigSecretValue = $appConfigSecret.Value.Trim('{"uri": "').Trim('"}')
        $appConfigSecretValue = $appConfigSecretValue.Trim('"}')

        if($_.Value.Uri -ne $appConfigSecretValue)
        {
            Write-Host "$($_.Name)" -ForegroundColor Yellow
            Write-Host "    $($appConfigSecretValue)" -ForegroundColor Yellow
            Write-Host "    $($_.Value.Uri)" -ForegroundColor Yellow
        }
    }
}

Write-Host "To be deleted" -ForegroundColor Red
$appConfigSecrets | ForEach-Object {
    $secret = $secrets.PSObject.Properties[$_.Key]
    
    if($secret -eq $null)
    {
        Write-Host "$($_.key)" -ForegroundColor Red
        Write-Host "    $($_.Value.Uri)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "Plan features"

Write-Host "To be added" -ForegroundColor Green
$appConfigFeatures = az appconfig feature list -n $appConfigurationName --label $microservice | ConvertFrom-Json
$features = Get-Content -Raw $featuresFilePath | ConvertFrom-Json
$features.PSObject.Properties | ForEach-Object {
    $featureName = $_.Name
    $appConfigFeature = $appConfigFeatures | Where-Object { $_.name -eq $featureName }

    if ($appConfigFeature -eq $null) {
        Write-Host "$($_.Name)" -ForegroundColor Green
        Write-Host "    $($_.Value.Description)" -ForegroundColor Green
    }
}

Write-Host "To be updated" -ForegroundColor Yellow
$features.PSObject.Properties | ForEach-Object {
    $featureName = $_.Name
    $appConfigFeature = $appConfigFeatures | Where-Object { $_.name -eq $featureName }

    if($appConfigFeature -ne $null)
    {
        $appConfigFeatureDescription = $appConfigFeature.description

        if($_.Value.Description -ne $appConfigFeatureDescription)
        {
            Write-Host "$($_.Name)" -ForegroundColor Yellow
            Write-Host "    $($appConfigFeatureDescription)" -ForegroundColor Yellow
            Write-Host "    $($_.Value.Description)" -ForegroundColor Yellow
        }
    }
}

Write-Host "To be deleted" -ForegroundColor Red
$appConfigFeatures | ForEach-Object {
    $feature = $features.PSObject.Properties[$_.Name]
    
    if($feature -eq $null)
    {
        Write-Host "$($_.Name)" -ForegroundColor Red
        Write-Host "    $($_.Value.Description)" -ForegroundColor Red
    }
}