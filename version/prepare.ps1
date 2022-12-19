Write-Host "##vso[task.setvariable variable=version;]$version"
Write-Host "Release version is '$version'."
Write-Host "##vso[build.updatebuildnumber]$version"