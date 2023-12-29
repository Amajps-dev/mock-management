# 1-6? 7? 
# Read JSON data from file
function ProcessJson {
    param (
        [Parameter(Mandatory = $true)]
        [String]$JsonFilePath,
        [Parameter(Mandatory = $true)]
        [String]$OutputDirectory
    )

    $jsonObject = Get-Content -Raw -Path $JsonFilePath | ConvertFrom-Json

    # Dictionary/Map to store authorizations
    $authorizationMap = @{}

    # Function to send the request
    function SendRequest($url, $method, $headers, $bodyData) {
        Invoke-RestMethod -Uri $url -Method $method -Headers $headers -Body $bodyData
    }

    # Process authentications and store authorization info
    foreach ($auth in $jsonObject.authentications) {
        if ($auth.type -eq "token") {
            # For token type, set the Authorization directly
            $authorizationMap[$auth.name] = $auth.token
        } elseif ($auth.type -eq "dom-security") {
            # For dom-security, make GET call and set Authorization from response
            Write-Host "Performing dom-security authentication..."
            $url = "https://smarter-dev2.edenred.net/dom-security-api/v1/connect/login"
            $headers = @{
                "x-tenant" = "fr"
                "Content-Type" = "application/x-www-form-urlencoded"
            }
            $bodyData = @{
                "Client_Id" = "developers"
                "Client_Secret" = "e0194196-5e4a-4044-b050-d1e869522764"
            }
            $response = SendRequest -Url $url -Method "POST" -Headers $headers -Body $bodyData
            $authorizationMap[$auth.name] = $response.access_token
        }
    }

    # Resolve and process mocks
    foreach ($mock in $jsonObject.mocks) {
        $target = $mock.target
        $url = $target.url
        $method = $target.method
        $authType = $target.authentication

        # Check if the mock data has a body to include in the request
        $bodyData = $mock.bodyData
        if ($bodyData -eq $null) {
            $bodyData = @{} # If no body data specified, set an empty object
        }

        # Create headers as an ordered dictionary
        $headers = [ordered]@{}
        foreach ($header in $target.headers.PSObject.Properties) {
            $headers[$header.Name] = $header.Value
        }

        # Add configured headers
        $headers["Key"] = "Value" # Add your headers here

        # Add authentication based on type
        if ($authorizationMap.ContainsKey($authType)) {
            $headers["Authorization"] = $authorizationMap[$authType]
        }

        # Adding filter if configured
        if ($mock.filter -ne $null) {
            $filter = @{
                "path" = $mock.filter[0].path
                "value" = $mock.filter[0].value
            }

            # Create a new object and copy all properties from the original mock
            $newMock = $mock | Select-Object *
            $newMock.filter = @($filter)  # Set filter field

            # Replace the original mock with the new one
            $jsonObject.mocks[$jsonObject.mocks.IndexOf($mock)] = $newMock
        }

        # Send request
        Write-Host "Sending mock request to $url with method $method and headers: $($headers | Out-String)"
        SendRequest -Url $url -Method $method -Headers $headers -Body $bodyData
    }
}

# Enter JSON File Path and Output path and execute 
$jsonPath = Read-Host -Prompt "Enter the JSON file path"
$outputDirectory = Read-Host -Prompt "Enter the output directory"

$authInfo = ProcessJson -JsonFilePath $jsonPath -OutputDirectory $outputDirectory
