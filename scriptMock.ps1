function ProcessJson {
    param (
        [Parameter(Mandatory = $true)]
        [String]$JsonFilePath,
        [Parameter(Mandatory = $true)]
        [String]$OutputDirectory
    )

    # Read the configuration file
    $jsonContent = Get-Content -Raw -Path $JsonFilePath | ConvertFrom-Json
    $authDict = @{}

    # Authentication zone
    foreach ($auth in $jsonContent.authentications) {
        if ($auth.type -eq "token") {
            $authDict[$auth.name] = $auth.token
        } elseif ($auth.type -eq "dom-security") {
            # Extract required parameters and create Uri object
            $tokenURL = $auth.parameters.tokenURL
            $clientId = $auth.parameters.clientId
            $clientSecret = $auth.parameters.clientSecret
 
            $uri = New-Object System.Uri($tokenURL)
 
            # Define headers and data
            $headers = @{
                "x-tenant" = "fr"
                "Content-Type" = "application/x-www-form-urlencoded"
            }
            $bodyData = @{
                "Client_Id" = $clientId
                "Client_Secret" = $clientSecret
            }

            # Execute GET request to obtain the payload
            try {
                $response = Invoke-RestMethod -Uri $uri -Method GET -Headers $headers

                # Output the response to check if data is received correctly
                Write-Host "Response:"
                Write-Host $response

                # Check if 'Authorization' field exists in the response
                if ($response.Headers.Authorization) {
                    $authDict[$auth.name] = $response.Headers.Authorization
                } else {
                    Write-Host "Authorization field not found in the response headers."
                    # Handle this scenario accordingly
                }

            } catch {
                Write-Host "Error in token authentication: $_"
            }

        } elseif ($auth.type -eq "None") {
            # For 'No Auth' type, set an empty value for authorization
            $authDict[$auth.name] = ""
        }
    }

    $authDict
}

# Enter JSON File Path and Output path and execute 
$jsonPath = Read-Host -Prompt "Enter the JSON file path"
$outputDirectory = Read-Host -Prompt "Enter the output directory"

$authInfo = ProcessJson -JsonFilePath $jsonPath -OutputDirectory $outputDirectory

foreach ($key in $authInfo.Keys) {
    Write-Host "Key: $key, Value: $($authInfo[$key])"
}

