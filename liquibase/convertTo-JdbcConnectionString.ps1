param(
    [Parameter(Mandatory=$true)]
    [string]$connectionString
)

if ($connectionString -like "*Server=tcp*") {
    Write-Host "SQL connectionString"

    $parts = $connectionString -split ';'
    $server = ($parts | Where-Object { $_ -match 'Server=tcp' }).Split('=')[1]
    $server = $server -replace 'tcp:', ''  # remove 'tcp:' from the server string
    $server = $server -replace ',', ':'  # replace comma with colon
    $database = ($parts | Where-Object { $_ -match 'Initial Catalog' }).Split('=')[1]
    $user = ($parts | Where-Object { $_ -match 'User ID' }).Split('=')[1]
    $password = ($parts | Where-Object { $_ -match 'Password' }).Split('=')[1]
    $encrypt = ($parts | Where-Object { $_ -match 'Encrypt' }).Split('=')[1].ToLower()
    $trustServerCertificate = ($parts | Where-Object { $_ -match 'TrustServerCertificate' }).Split('=')[1].ToLower()
    $loginTimeout = ($parts | Where-Object { $_ -match 'Connection Timeout' }).Split('=')[1]
    $hostNameInCertificate = "*.database.windows.net"

    $jdbcConnectionString = "jdbc:sqlserver://$server;database=$database;user=$user;password=$password;encrypt=$encrypt;trustServerCertificate=$trustServerCertificate;hostNameInCertificate=$hostNameInCertificate;loginTimeout=$loginTimeout;"

    Write-Host "##vso[task.setvariable variable=JdbcConnectionString]$jdbcConnectionString"

} else {
    Write-Host "Mongo connectionString"
    $user = "user-microservice"
    $password = "vipCXwESKrh2iMuf"
    Write-Host $user
    Write-Host $password

    $jdbcConnectionString = "mongodb+srv://user-pl-0.xufmq.mongodb.net/dom-user-fr"

    Write-Host "##vso[task.setvariable variable=JdbcConnectionString]$jdbcConnectionString"
    Write-Host "##vso[task.setvariable variable=username]$user"
    Write-Host "##vso[task.setvariable variable=password]$password"
}