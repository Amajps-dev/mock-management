param ($microservice, $environment, $version, $appConfigurationName)

$settingsFilePath = "./settings/$environment/settings.json"
$secretsFilePath = "./settings/$environment/secrets.json"
$settingsVersion = $version | ConvertTo-Json

$appConfigurationUrl = "https://$($appConfigurationName).azconfig.io"

try
{
    Write-Host "Update settings and secrets"

    if (Test-Path $settingsFilePath) {
        Write-Host "Importing settings to AppConfiguration"
        az appconfig kv import --endpoint $appConfigurationUrl --auth-mode login -s file --path $settingsFilePath --format json --label $microservice --content-type "application/json" -y

        Write-Host "Importing secrets to AppConfiguration"
        az appconfig kv import --endpoint $appConfigurationUrl --auth-mode login -s file --path $secretsFilePath --format json --label $microservice --content-type "application/vnd.microsoft.appconfig.keyvaultref+json;charset=utf-8" --yes 

        Write-Host "Delete AppConfiguration settings not in settings.json"
        $appConfigSettings = az appconfig kv list --endpoint $appConfigurationUrl --auth-mode login --label $microservice | ConvertFrom-Json | Where-Object { $_.contentType -eq "application/json" }
        $settings = Get-Content -Raw $settingsFilePath | ConvertFrom-Json
        $appConfigSettings | ForEach-Object {
            $_.Key
            $setting = $settings.PSObject.Properties[$_.Key]
            $setting

            if($setting -eq $null)
            {
                az appconfig kv delete --endpoint $appConfigurationUrl --auth-mode login --key $_.Key --label $microservice -y --output none
                Write-Host "    Deleted $($_.Key)"
            }
        }

        Write-Host "Delete AppConfiguration secrets not in secrets.json"
        $appConfigSecrets = az appconfig kv list --endpoint $appConfigurationUrl --auth-mode login --label $microservice | ConvertFrom-Json | Where-Object { $_.contentType -eq "application/vnd.microsoft.appconfig.keyvaultref+json;charset=utf-8" }
        $secrets = Get-Content -Raw $secretsFilePath | ConvertFrom-Json
        $appConfigSecrets | ForEach-Object {
            $secret = $secrets.PSObject.Properties[$_.Key]
            if($secret -eq $null)
            {
                az appconfig kv delete --endpoint $appConfigurationUrl --auth-mode login --key $_.Key --label $microservice -y --output none
                Write-Host "    Deleted $($_.Key)"
            }
        }

        az appconfig kv set --endpoint $appConfigurationUrl --auth-mode login --key Sentinel --value $settingsVersion --label $microservice -y --output none
        Write-Host "Sentinel updated to version $settingsVersion"
    } else {
        Write-Warning "No settings file."
        Write-Host "##vso[task.complete result=SucceededWithIssues;]No settings file."
    }
}
catch
{
  Write-Error $_
  Write-Host "##vso[task.logissue type=error]$_"
}
