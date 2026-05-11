# Keycloak configuration
$keycloakUrl = "https://auth.sec-auditor.com/auth"
$realm = "sec-auditor"
$clientId = "api"

# Construct the token endpoint URL
$tokenEndpoint = "$keycloakUrl/realms/$realm/protocol/openid-connect/token"

# Prompt for username and password
$username ="api_xxx"
$password = "yyy"
$accessToken = ""

# api detail
$apiEndpoint = "https://next-api.sec-auditor.com/api/v1"

# Prepare the request body
$body = @{
    grant_type    = "password"
    client_id     = $clientId
    username      = $username
    password      = $password
}

function Decode-JWT {
    param (
        [string]$token
    )

    $parts = $token.Split('.')
    $decodedPayload = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($parts[1].Replace('-', '+').Replace('_', '/').PadRight(4*[math]::Ceiling($parts[1].Length / 4), '=')))
    return $decodedPayload | ConvertFrom-Json
}


function Get-SecurityLog {
    param (
        [string]$jwt,
        [string]$clientUUID
    )


    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $authHeader = "Bearer $jwt"
    $response = Invoke-RestMethod -Uri "$apiEndpoint/client/$clientUUID/ioe?page=0&pageSize=50" -Method GET -ContentType "application/json" -Headers @{Authorization=$authHeader}
    return $response
}

# Send the request to get the access token
try {
    # Force TLS 1.2
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $response = Invoke-RestMethod -Uri $tokenEndpoint -Method Post -Body $body -ContentType "application/x-www-form-urlencoded"

    # Extract the access token
    $accessToken = $response.access_token

    # Output the access token
    Write-Output "`nAccess Token:"
    Write-Output $accessToken


    Write-Output "`nToken Payload:"
    $payloadJson = Decode-JWT -token $accessToken
    $payloadJson | ConvertTo-Json -Depth 5 | Write-Output

    # Display some key information from the payload
    Write-Output "`nKey Information:"
    Write-Output "Subject: $($payloadJson.sub)"
    Write-Output "Issuer: $($payloadJson.iss)"
    Write-Output "Expiration: $([DateTime]::new(1970,1,1,0,0,0,0,[DateTimeKind]::Utc).AddSeconds($payloadJson.exp))"
}
catch {
    Write-Error "Failed to retrieve access token: $_"
    Write-Host "Error details: $($_.Exception.Message)"
    if ($_.Exception.Response) {
        $result = $_.Exception.Response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($result)
        $reader.BaseStream.Position = 0
        $reader.DiscardBufferedData()
        $responseBody = $reader.ReadToEnd()
        Write-Host "Response body: $responseBody"
    }
}

try {
    $securityLog = Get-SecurityLog -jwt $accessToken -clientUUID "48be143a-def4-4386-b7f6-9e49b7f97497"
    Write-Output "`nSecurity Log:"
    Write-Output $securityLog
}
catch {
    Write-Error "Failed to retrieve security log: $_"
    Write-Host "Error details: $($_.Exception.Message)"
    if ($_.Exception.Response) {
        $result = $_.Exception.Response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($result)
        $reader.BaseStream.Position = 0
        $reader.DiscardBufferedData()
        $responseBody = $reader.ReadToEnd()
        Write-Host "Response body: $responseBody"
    }
}
