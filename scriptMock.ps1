function ProcessJson {
    param (
        [Parameter(Mandatory = $true)]
        [String]$JsonFilePath,

        [Parameter(Mandatory = $true)]
        [String]$OutputDirectory
    )

    # Read the JSON file
    $jsonContent = Get-Content -Raw -Path $JsonFilePath | ConvertFrom-Json
    $authDict = @{}

    # Convert the JSON content to a string
    $jsonString = $jsonContent | ConvertTo-Json

    Write-Host "JSON file processed and saved as payload.json in the output directory."

    # Authentication zone
    foreach ($auth in $jsonContent.authentications) {
        if ($auth.type -eq "token") {
            $authDict[$auth.name] = $auth.token
        } elseif ($auth.type -eq "dom-security") {
            # Extract required parameters and create Uri object
            $tokenURL = $auth.parameters.tokenURL
            $clientId = $auth.parameters.clientId
            $clientSecret = $auth.parameters.clientSecret

            # Check if the URL is valid before creating the Uri object
            if (-not [System.Uri]::TryCreate($tokenURL, [System.UriKind]::Absolute, [ref]$uri)) {
                Write-Host "Invalid URL: $tokenURL"
                # Handle the invalid URL scenario here
                continue  # Skip to the next authentication
            }

             # Define headers and data
            $headers = @{
                "x-tenant" = "fr"
                "Content-Type" = "application/x-www-form-urlencoded"
            }
            $bodyData = @{
                "grant_type" = "client_credentials"
                "client_id" = $clientId
                "client_secret" = $clientSecret
            }
            $bodyString = $bodyData.Keys.ForEach({"$($_)=$($bodyData.$_)"}) -join '&'
            
            # Execute GET request to obtain the payload
            try {
                $response = Invoke-RestMethod -Uri $uri -Method POST -Headers $headers -Body $bodyString -ErrorAction Stop
                            
                Write-Host "Token response:"
                Write-Host "Response Object:"
                Write-Host ($response | Out-String)

                # Check if 'Authorization' field exists in the response
                if ($response) {
                    $token = $response.access_token
                    $authDict[$auth.name] = $token
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
    Write-Host "Authentications:"
    Write-Host ($authDict | Out-String)

    # Resolve Mocks
    foreach ($mock in $jsonContent.mocks) {
        $requestMethod = $mock.target.method
        $requestUri = $mock.target.url

        # Add headers
        $requestHeaders = @{}
        if ($mock.target.headers) {
            foreach ($header in $mock.target.headers.PSObject.Properties) {
                $requestHeaders[$header.Name] = $header.Value
            }
        }

        # Add authentication
        if ($mock.authentication -and $authDict.ContainsKey($mock.authentication)) {
            $requestAuth = $authDict[$mock.authentication]
            if (-not $requestHeaders.ContainsKey("Authorization")) {  
                $requestHeaders["Authorization"] = $requestAuth
            }
        }  

        # Perform the request
        Write-Host "Request Method: $requestMethod"
        Write-Host "Request URI: $requestUri" 

        try {
            Write-Host "Request Headers:"
            Write-Host ($requestHeaders | Out-String)
            $response = Invoke-WebRequest -Uri $requestUri -Method $requestMethod -Headers $requestHeaders 


            Write-Host "Response Headers:"
            Write-Host ($response.Headers | Out-String)
            Write-Host "RawContent Headers:"
            Write-Host ($response.RawContent.Headers | Out-String)
            

            # Save the payload to the file 
            $payloadFilePath = Join-Path -Path $OutputDirectory -ChildPath $mock.file
            $directory = Split-Path -Path $payloadFilePath -Parent
            if (-not (Test-Path -Path $directory)) {
                New-Item -ItemType Directory -Path $directory -Force | Out-Null
            } 
            $response.Content | ConvertFrom-Json | ConvertTo-Json | Set-Content -Path $payloadFilePath  

            Write-Host "Converting to JSON done"

            # Save the response headers if configured
            if ($mock.headers -and $mock.headers.Count -gt 0) {
                Write-Host "Saving response headers..."
                $headersFilePath = Join-Path -Path $OutputDirectory -ChildPath ($mock.file + ".headers")
                $headersToSave = @{}

                foreach ($headerName in $mock.headers) {
                    if ($response.Headers -ne $null -and $response.Headers.ContainsKey($headerName)) {  
                        $headersToSave[$headerName] = $response.Headers[$headerName]  
                    } else {
                        $headersToSave[$headerName] = ""  
                    }
                }

                $headersToSave | ConvertTo-Json -Depth 100 | Set-Content -Path $headersFilePath
                Write-Host "Saving response headers done"
            }

            # Additional code to inspect the response content
            Write-Host "Inspecting response content..."
            Write-Host "Response Object:"
            Write-Host ($response | Out-String)

            # Get detailed information about the response object
            Write-Host "Response Object Properties and Methods:"
            $response | Get-Member

        } catch {
            Write-Host "Error in processing mock request: $_"
            Write-Host "Response:"
            Write-Host $response
            Write-Host $_
        }
    }
}


$jsonPath = Read-Host -Prompt "Enter the JSON file path"
$outputDirectory = Read-Host -Prompt "Enter the output directory"

ProcessJson -JsonFilePath $jsonPath -OutputDirectory $outputDirectory