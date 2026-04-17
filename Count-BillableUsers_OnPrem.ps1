<#
.SYNOPSIS
    SEC AUDITOR: Zählt aktive Benutzer im Active Directory (on-prem und hybrid).

.DESCRIPTION
    Fragt den nicht-replizierten Attributwert 'lastLogon' von ALLEN Domain Controllern
    ab und verwendet pro Benutzer den Maximalwert. Das ist der exakteste verfügbare
    Wert für die letzte Anmeldung im AD.

.PARAMETER Days
    Zeitfenster in Tagen. Standard: 90.

.EXAMPLE
    .\Get-ActiveADUsers.ps1

.EXAMPLE
    .\Get-ActiveADUsers.ps1
#>

[int]$Days = 90

if (-not (Get-Module -ListAvailable -Name ActiveDirectory)) {
    Write-Error "Das ActiveDirectory-Modul ist nicht installiert. Bitte RSAT-AD-PowerShell installieren."
    exit 1
}
Import-Module ActiveDirectory -ErrorAction Stop

$CutoffDate     = (Get-Date).AddDays(-$Days)
$CutoffFileTime = $CutoffDate.ToFileTime()

Write-Host "Datum: $($CutoffDate.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Cyan

Write-Host "Ermittle Domain Controller..." -ForegroundColor Cyan
$DCs = Get-ADDomainController -Filter * | Select-Object -ExpandProperty HostName
Write-Host "Gefundene DCs: $($DCs.Count) [$($DCs -join ', ')]" -ForegroundColor Cyan

if ($DCs.Count -eq 0) {
    Write-Error "Keine Domain Controller gefunden."
    exit 1
}

$UserData       = @{}
$UnreachableDCs = @()
$dcCounter      = 0

foreach ($dc in $DCs) {
    $dcCounter++
    Write-Progress -Activity "Abfrage Domain Controller" `
                   -Status "[$dcCounter/$($DCs.Count)] $dc" `
                   -PercentComplete (($dcCounter / $DCs.Count) * 100)

    try {
        $users = Get-ADUser -Filter "Enabled -eq `$true" -Server $dc `
            -Properties lastLogon, UserPrincipalName, DisplayName, DistinguishedName `
            -ErrorAction Stop
    } catch {
        Write-Warning "DC $dc nicht erreichbar: $($_.Exception.Message)"
        $UnreachableDCs += $dc
        continue
    }

    foreach ($u in $users) {
        $key   = $u.ObjectGUID.Guid
        $logon = if ($u.lastLogon) { [int64]$u.lastLogon } else { 0 }

        if (-not $UserData.ContainsKey($key)) {
            $UserData[$key] = [PSCustomObject]@{
                UserPrincipalName = $u.UserPrincipalName
                DisplayName       = $u.DisplayName
                DistinguishedName = $u.DistinguishedName
                MaxLastLogon      = $logon
            }
        } elseif ($logon -gt $UserData[$key].MaxLastLogon) {
            $UserData[$key].MaxLastLogon = $logon
        }
    }
}
Write-Progress -Activity "Abfrage Domain Controller" -Completed

$ExcludedUpnPatterns = @(
    'HealthMailbox*', 'SystemMailbox*', 'FederatedEmail*',
    'DiscoverySearchMailbox*', 'MSOL_*', 'Sync_*'
)

$ExcludedDnPatterns = @(
    '*CN=Monitoring Mailboxes*',
    '*CN=Microsoft Exchange System Objects*'
)

$activeCount = 0
foreach ($u in $UserData.Values) {

    if ($u.MaxLastLogon -le $CutoffFileTime) { continue }

    $skip = $false
    if ($u.UserPrincipalName) {
        foreach ($p in $ExcludedUpnPatterns) {
            if ($u.UserPrincipalName -like $p) { $skip = $true; break }
        }
    }
    if ($skip) { continue }

    foreach ($p in $ExcludedDnPatterns) {
        if ($u.DistinguishedName -like $p) { $skip = $true; break }
    }
    if ($skip) { continue }

    if ($u.UserPrincipalName -like 'Sync_*' -and
        $u.DisplayName -eq 'On-Premises Directory Synchronization Service Account') {
        continue
    }

    $activeCount++
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host " Aktive AD-Benutzer (letzte $Days Tage, alle DCs): $activeCount" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green

if ($UnreachableDCs.Count -gt 0) {
    Write-Host ""
    Write-Warning "Nicht erreichbare DCs wurden übersprungen: $($UnreachableDCs -join ', ')"
    Write-Warning "Ergebnis ist möglicherweise nicht vollständig genau."
}
