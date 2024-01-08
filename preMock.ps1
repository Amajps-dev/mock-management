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

 

   # Resolve Mocks
    foreach ($mock in $jsonContent.mocks) {
        $requestMethod = $mock.method

        $requestUri = $null
        try {
            $requestUri = [System.Uri]::new($mock.url)
        } catch {
            Write-Host "Invalid URL format: $($mock.url)"
            continue
        }

        if ($authDict.ContainsKey($mock.authentication)) {
            $requestAuth = $authDict[$mock.authentication]
        } else {
            Write-Host "Authentication not found: $($mock.authentication)"
            continue
        }

        if ($authDict[$mock.authentication].Type -ne "None") {
            if ($requestAuth -is [string]) {
                if ($requestHeaders -eq $null) {
                    $requestHeaders = @{}
                }
                $requestHeaders["Authorization"] = $requestAuth
            } else {
                Write-Host "Invalid Authentication value: $requestAuth for $($mock.authentication)"
                Write-Host "Authentications: $($authDict.Keys -join ', ')"
                continue
            }
        }
    }
 

        # Add Authorization header

        $requestHeaders["Authorization"] = $requestAuth

 

        try {

            $response = Invoke-RestMethod -Uri $requestUri -Method $requestMethod -Headers $requestHeaders

 

            # Filter the response if filter is configured

            if ($mock.filter) {

                $response = $response | Select-Object -Property $mock.filter

            }

 

             # Save the payload to the file

            $payloadFilePath = Join-Path -Path $OutputDirectory -ChildPath $mock.file

            $response | ConvertTo-Json | Set-Content -Path $payloadFilePath

 

            # Save the response headers if configured

            if ($mock.headersToSave) {

                $headersToSave = @{}

                foreach ($headerName in $mock.headersToSave) {

                    if ($response.Headers[$headerName]) {

                        $headersToSave[$headerName] = $response.Headers[$headerName]

                    }

                }

 

                # Save the headers to the file with .headers extension

                $headersFilePath = [System.IO.Path]::ChangeExtension($payloadFilePath, "headers")

                $headersToSave | ConvertTo-Json | Set-Content -Path $headersFilePath

            }

           

 

        } catch {

            Write-Host "Error in processing mock request: $_"

        }

    }

}

 

# Enter JSON File Path and Output path and execute

$jsonPath = Read-Host -Prompt "Enter the JSON file path"

$outputDirectory = Read-Host -Prompt "Enter the output directory"

 

ProcessJson -JsonFilePath $jsonPath -OutputDirectory $outputDirectory