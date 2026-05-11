<#
.SYNOPSIS
    SEC AUDITOR: Zählt aktive Benutzer in Entra ID (Cloud-only).

.DESCRIPTION
    Authentifizierung via Device Code Flow (Code im Browser eingeben).
    Ruft die Microsoft Graph API direkt per Invoke-RestMethod ab.

    Modus 1 (Entra ID P1/P2 vorhanden):
      Zählt Benutzer mit Anmeldeaktivität in den letzten X Tagen.
      Berücksichtigt interactive und non-interactive Sign-Ins.

    Modus 2 (Fallback ohne P1/P2):
      Zählt alle aktivierten Cloud-only-Benutzer.
      Dieser Wert ist eine Obergrenze, da keine Anmeldeaktivität
      ausgewertet werden kann.

    Voraussetzungen:
      - PowerShell 5.1 oder neuer (auf jedem Windows vorhanden)
      - Browser für die Anmeldung
      - Das angemeldete Konto benötigt eine der folgenden Entra-Rollen:
        Reports Reader, Security Reader, Global Reader, Security Administrator
        oder Global Administrator
      - Admin Consent für die Enterprise App "Microsoft Graph Command Line Tools"
        muss erteilt sein. Falls nicht, kann ein Admin folgende URL aufrufen:
        https://login.microsoftonline.com/{TENANT-ID}/adminconsent?client_id=14d82eec-204b-4c2f-b7e8-296a70dab67e

.PARAMETER TenantId
    Tenant-ID oder Domain. Standard: 'organizations' (automatische Erkennung).
    Bei Problemen mit Consent die konkrete Tenant-ID angeben.

.EXAMPLE
    .\Get-ActiveEntraUsers.ps1

.EXAMPLE
    .\Get-ActiveEntraUsers.ps1 -TenantId "contoso.onmicrosoft.com"
#>

[CmdletBinding()]
param(  
    [string]$TenantId = 'organizations'
)

[int]$Days = 90,

# Microsoft Graph Command Line Tools (öffentliche Multi-Tenant App von Microsoft)
$ClientId = '14d82eec-204b-4c2f-b7e8-296a70dab67e'
$Scopes   = 'User.Read.All AuditLog.Read.All offline_access'

# TLS 1.2 erzwingen (Windows PowerShell 5.1 verwendet standardmäßig TLS 1.0/1.1)
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# --- Hilfsfunktion: Graph-Fehlerdetails aus Response lesen ---
function Get-GraphError($ErrorRecord) {
    try {
        if ($ErrorRecord.ErrorDetails -and $ErrorRecord.ErrorDetails.Message) {
            return ($ErrorRecord.ErrorDetails.Message | ConvertFrom-Json)
        }
        $resp = $ErrorRecord.Exception.Response
        if ($resp) {
            $stream = $resp.GetResponseStream()
            $reader = New-Object System.IO.StreamReader($stream)
            $raw = $reader.ReadToEnd()
            $reader.Close()
            if ($raw) { return ($raw | ConvertFrom-Json) }
        }
    } catch {}
    return $null
}

# --- Device Code Flow ---
Write-Host "Starte Authentifizierung..." -ForegroundColor Cyan

try {
    $deviceCode = Invoke-RestMethod -Method Post `
        -Uri "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/devicecode" `
        -ContentType 'application/x-www-form-urlencoded' `
        -Body @{ client_id = $ClientId; scope = $Scopes } `
        -ErrorAction Stop
} catch {
    $e = Get-GraphError $_
    Write-Host ""
    Write-Error "Device Code Anfrage fehlgeschlagen: $($_.Exception.Message)"
    if ($e.error_description) {
        Write-Host "Details: $($e.error_description)" -ForegroundColor Red
    }
    Write-Host ""
    Write-Host "Hinweis: Der TenantId-Parameter darf NICHT 'common' sein." -ForegroundColor Yellow
    Write-Host "Verwenden Sie 'organizations', die Tenant-ID oder die Domain." -ForegroundColor Yellow
    return
}

Write-Host ""
Write-Host $deviceCode.message -ForegroundColor Yellow
Write-Host ""

# Auf Benutzeranmeldung warten (Polling)
$tokenBody = @{
    client_id   = $ClientId
    grant_type  = 'urn:ietf:params:oauth:grant-type:device_code'
    device_code = $deviceCode.device_code
}

$token    = $null
$interval = [int]$deviceCode.interval
if ($interval -le 0) { $interval = 5 }
$deadline = (Get-Date).AddSeconds($deviceCode.expires_in)

while ((Get-Date) -lt $deadline) {
    Start-Sleep -Seconds $interval
    try {
        $token = Invoke-RestMethod -Method Post `
            -Uri "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token" `
            -ContentType 'application/x-www-form-urlencoded' `
            -Body $tokenBody -ErrorAction Stop
        break
    } catch {
        $e = Get-GraphError $_
        if (-not $e) {
            Write-Error "Unbekannter Token-Fehler: $($_.Exception.Message)"
            return
        }
        switch ($e.error) {
            'authorization_pending' { <# weiter warten #> }
            'slow_down'            { $interval += 5 }
            'authorization_declined' {
                Write-Error "Anmeldung wurde abgelehnt."
                return
            }
            'expired_token' {
                Write-Error "Anmeldezeitraum abgelaufen. Bitte erneut starten."
                return
            }
            default {
                Write-Host ""
                Write-Error "Token-Fehler: $($e.error)"
                Write-Host "Details: $($e.error_description)" -ForegroundColor Red
                if ($e.error -eq 'interaction_required' -or $e.suberror -eq 'consent_required') {
                    Write-Host ""
                    Write-Host "Ein Admin muss zuerst Consent erteilen:" -ForegroundColor Yellow
                    Write-Host "https://login.microsoftonline.com/$TenantId/adminconsent?client_id=$ClientId" -ForegroundColor Yellow
                }
                return
            }
        }
    }
}

if (-not $token) {
    Write-Error "Authentifizierung fehlgeschlagen (Timeout)."
    return
}

Write-Host "Erfolgreich angemeldet." -ForegroundColor Green

# --- Graph API Abfrage ---
$headers = @{
    Authorization    = "Bearer $($token.access_token)"
    ConsistencyLevel = 'eventual'
    Accept           = 'application/json'
}

$CutoffDate = (Get-Date).AddDays(-$Days).ToUniversalTime()

$ExcludedUpnPatterns = @(
    'HealthMailbox*', 'SystemMailbox*', 'FederatedEmail*',
    'DiscoverySearchMailbox*', 'MSOL_*', 'Sync_*'
)

# --- Versuch 1: Mit signInActivity (erfordert P1/P2) ---
$useSignInActivity = $true
$select = 'id,userPrincipalName,displayName,onPremisesSyncEnabled,signInActivity'
$uri    = "https://graph.microsoft.com/v1.0/users?`$select=$select&`$top=500&`$count=true"

Write-Host "Cutoff-Datum (UTC): $($CutoffDate.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Cyan
Write-Host "Frage Graph API ab (das kann bei grossen Tenants einige Minuten dauern)..." -ForegroundColor Cyan

# Erste Seite abrufen und prüfen, ob signInActivity verfügbar ist
try {
    $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get -ErrorAction Stop
} catch {
    $e = Get-GraphError $_
    $status = $null
    try { $status = $_.Exception.Response.StatusCode.value__ } catch {}
    $code = if ($e -and $e.error) { $e.error.code } else { $null }

    if ($code -eq 'Authentication_RequestFromNonPremiumTenantOrB2CTenant') {
        # Kein P1/P2 -> Fallback auf aktivierte Benutzer
        Write-Host ""
        Write-Host "============================================================" -ForegroundColor Yellow
        Write-Host " Entra ID P1/P2 nicht vorhanden." -ForegroundColor Yellow
        Write-Host " Anmeldeaktivitaet kann nicht ausgewertet werden." -ForegroundColor Yellow
        Write-Host " Fallback: Zaehle alle aktivierten Cloud-only-Benutzer." -ForegroundColor Yellow
        Write-Host "============================================================" -ForegroundColor Yellow
        Write-Host ""

        $useSignInActivity = $false
        $select = 'id,userPrincipalName,displayName,onPremisesSyncEnabled'
        $uri    = "https://graph.microsoft.com/v1.0/users?`$filter=accountEnabled eq true&`$select=$select&`$top=999&`$count=true"

        try {
            $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get -ErrorAction Stop
        } catch {
            $e2 = Get-GraphError $_
            Write-Error "Auch Fallback-Abfrage fehlgeschlagen."
            if ($e2 -and $e2.error) {
                Write-Host "Fehler: $($e2.error.code) - $($e2.error.message)" -ForegroundColor Red
            }
            return
        }
    } elseif ($code -eq 'Authentication_RequestFromUnsupportedUserRole') {
        Write-Host ""
        Write-Error "Graph API Fehler (HTTP $status): $code"
        Write-Host ""
        Write-Host "URSACHE: Das angemeldete Konto hat keine ausreichende Entra-Rolle." -ForegroundColor Yellow
        Write-Host "Erforderlich: Reports Reader, Security Reader, Global Reader" -ForegroundColor Yellow
        Write-Host "oder Security Administrator." -ForegroundColor Yellow
        return
    } elseif ($code -eq 'Authorization_RequestDenied') {
        Write-Host ""
        Write-Error "Graph API Fehler (HTTP $status): $code"
        Write-Host ""
        Write-Host "URSACHE: Fehlende Berechtigung oder Admin Consent nicht erteilt." -ForegroundColor Yellow
        Write-Host "Ein Admin muss Consent erteilen:" -ForegroundColor Yellow
        Write-Host "https://login.microsoftonline.com/$TenantId/adminconsent?client_id=$ClientId" -ForegroundColor Yellow
        return
    } else {
        Write-Host ""
        Write-Error "Graph API Fehler (HTTP $status): $($_.Exception.Message)"
        if ($e -and $e.error) {
            Write-Host "Code: $($e.error.code)" -ForegroundColor Red
            Write-Host "Meldung: $($e.error.message)" -ForegroundColor Red
        }
        return
    }
}

# --- Ergebnisse verarbeiten (erste Seite + Paging) ---
$activeCount  = 0
$totalFetched = 0
$skippedSync  = 0
$firstPage    = $true

do {
    # Erste Seite wurde oben bereits abgerufen
    if (-not $firstPage) {
        try {
            $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get -ErrorAction Stop
        } catch {
            $status = $null
            try { $status = $_.Exception.Response.StatusCode.value__ } catch {}
            if ($status -eq 429) {
                $retry = 30
                Write-Warning "Rate Limit erreicht. Warte $retry Sekunden..."
                Start-Sleep -Seconds $retry
                continue
            }
            $e = Get-GraphError $_
            Write-Error "Graph API Fehler bei Paging (HTTP $status): $($_.Exception.Message)"
            if ($e -and $e.error) {
                Write-Host "Code: $($e.error.code)" -ForegroundColor Red
            }
            return
        }
    }
    $firstPage = $false

    $batch = $response.value
    $totalFetched += $batch.Count

    foreach ($u in $batch) {

        # Nur Cloud-only (nicht aus AD synchronisiert)
        if ($u.onPremisesSyncEnabled -eq $true) { $skippedSync++; continue }

        # System-/Service-Konten
        $skip = $false
        if ($u.userPrincipalName) {
            foreach ($p in $ExcludedUpnPatterns) {
                if ($u.userPrincipalName -like $p) { $skip = $true; break }
            }
        }
        if ($skip) { continue }

        if ($useSignInActivity) {
            # Sign-In-Aktivität prüfen: interactive ODER non-interactive
            $lastInteractive    = $null
            $lastNonInteractive = $null

            if ($u.signInActivity.lastSignInDateTime) {
                $lastInteractive = [DateTime]::Parse($u.signInActivity.lastSignInDateTime)
            }
            if ($u.signInActivity.lastNonInteractiveSignInDateTime) {
                $lastNonInteractive = [DateTime]::Parse($u.signInActivity.lastNonInteractiveSignInDateTime)
            }

            $lastActivity = $null
            if ($lastInteractive -and $lastNonInteractive) {
                $lastActivity = if ($lastInteractive -gt $lastNonInteractive) { $lastInteractive } else { $lastNonInteractive }
            } elseif ($lastInteractive)    { $lastActivity = $lastInteractive }
            elseif ($lastNonInteractive)   { $lastActivity = $lastNonInteractive }

            if (-not $lastActivity -or $lastActivity -lt $CutoffDate) { continue }
        }

        $activeCount++
    }

    Write-Host "  Abgerufen: $totalFetched Benutzer..." -ForegroundColor Gray

    # Paging
    $uri = $response.'@odata.nextLink'

} while ($uri)

# --- Ergebnis ---
Write-Host ""
if ($useSignInActivity) {
    Write-Host "============================================================" -ForegroundColor Green
    Write-Host " Aktive Entra-Benutzer (Cloud-only, letzte $Days Tage): $activeCount" -ForegroundColor Green
    Write-Host "============================================================" -ForegroundColor Green
    Write-Host " Modus: Anmeldeaktivitaet (interactive + non-interactive)" -ForegroundColor Gray
} else {
    Write-Host "============================================================" -ForegroundColor Yellow
    Write-Host " Aktivierte Entra-Benutzer (Cloud-only): $activeCount" -ForegroundColor Yellow
    Write-Host "============================================================" -ForegroundColor Yellow
    Write-Host " HINWEIS: Ohne Entra ID P1/P2 kann die Anmeldeaktivitaet" -ForegroundColor Yellow
    Write-Host " nicht ausgewertet werden. Der angezeigte Wert ist die" -ForegroundColor Yellow
    Write-Host " Anzahl aller aktivierten Cloud-only-Benutzer und damit" -ForegroundColor Yellow
    Write-Host " eine Obergrenze fuer die tatsaechlich aktiven Benutzer." -ForegroundColor Yellow
}
Write-Host " Gesamt abgerufen: $totalFetched | Synchronisierte uebersprungen: $skippedSync" -ForegroundColor Gray
