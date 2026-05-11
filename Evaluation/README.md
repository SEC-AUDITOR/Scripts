<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://assets.sec-auditor.com/images/logo_gradient_negative.svg" />
    <img src="https://assets.sec-auditor.com/images/logo_gradient.svg" alt="SEC AUDITOR" width="280" />
  </picture>
</p>

<h1 align="center">Evaluierung – Aktive Benutzer zählen</h1>

<p align="center">
  Kostenschätzung vor dem Kauf | <a href="https://sec-auditor.com">sec-auditor.com</a>
</p>

---

Da sich die Lizenzkosten von SEC AUDITOR nach der Anzahl **aktiver Benutzer** richten, helfen diese Skripte dabei, diesen Wert in Ihrer Umgebung zu ermitteln.

Die Skripte laufen lokal in Ihrer Infrastruktur und übertragen keine Daten an Dritte.

---

## Skripte

### `Count-BillableUsers_Entra.ps1` – Microsoft Entra ID (Azure AD)

Zählt aktive Benutzer in einer **Cloud-only oder hybriden Entra ID**-Umgebung über die Microsoft Graph API.

**Funktionsweise:**

| Modus | Voraussetzung | Ergebnis |
|---|---|---|
| **Modus 1** | Entra ID P1 oder P2 | Zählt Benutzer mit tatsächlicher Anmeldeaktivität in den letzten 90 Tagen (interactive + non-interactive Sign-Ins) |
| **Modus 2** (Fallback) | Kein P1/P2 | Zählt alle aktivierten Cloud-only-Benutzer – dieser Wert ist eine **Obergrenze** |

Synchronisierte AD-Benutzer (`onPremisesSyncEnabled`) sowie System- und Servicekonten werden automatisch herausgefiltert.

**Voraussetzungen:**

- PowerShell 5.1 oder neuer
- Ein Browser für die Anmeldung (Device Code Flow – kein Passwort im Skript)
- Das angemeldete Konto benötigt eine der folgenden Entra-Rollen:
  - Reports Reader
  - Security Reader
  - Global Reader
  - Security Administrator
  - Global Administrator
- Admin Consent für die Enterprise App **„Microsoft Graph Command Line Tools"** (App-ID `14d82eec-204b-4c2f-b7e8-296a70dab67e`)

> Falls der Consent noch nicht erteilt wurde, kann ein Administrator folgende URL aufrufen:
> `https://login.microsoftonline.com/{TENANT-ID}/adminconsent?client_id=14d82eec-204b-4c2f-b7e8-296a70dab67e`

**Verwendung:**

```powershell
# Standardaufruf (Tenant wird automatisch erkannt)
.\Count-BillableUsers_Entra.ps1

# Mit expliziter Tenant-ID (empfohlen bei Consent-Problemen)
.\Count-BillableUsers_Entra.ps1 -TenantId "contoso.onmicrosoft.com"
```

---

### `Count-BillableUsers_OnPrem.ps1` – On-Premises Active Directory

Zählt aktive Benutzer in einem **lokalen oder hybriden Active Directory**, indem das Attribut `lastLogon` von **allen Domain Controllern** abgefragt und der jeweils neueste Wert pro Benutzer verwendet wird. Das liefert den exaktesten verfügbaren Wert für die letzte Anmeldung.

System- und Servicekonten (Exchange-Systempostfächer, MSOL-Konten, Sync-Konten u. a.) werden automatisch herausgefiltert.

**Voraussetzungen:**

- PowerShell 5.1 oder neuer
- **RSAT Active Directory-Modul** muss installiert sein:
  ```powershell
  # Installation unter Windows 10/11
  Add-WindowsCapability -Online -Name "Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0"
  ```
- Ausführung auf einem Gerät, das Mitglied der Domain ist
- Lesezugriff auf alle Domain Controller (Standard für Domainmitglieder)

**Verwendung:**

```powershell
.\Count-BillableUsers_OnPrem.ps1
```

Der Schwellenwert für „aktiv" ist standardmäßig auf **90 Tage** eingestellt und kann direkt im Skript in der Variable `$Days` angepasst werden.

---

## Ergebnis interpretieren

Das ausgegebene Ergebnis entspricht der Anzahl der **abrechenbaren Benutzer** (Billable Users), die bei einer SEC AUDITOR Lizenz berücksichtigt werden. Vergleichen Sie diesen Wert mit unserer Kostentabelle in Ihrem Dashboard.

---

## Kontakt & Support

| | |
|---|---|
| **Website** | [sec-auditor.com](https://sec-auditor.com) |
| **Support** | [support@sec-auditor.com](mailto:support@sec-auditor.com) |
| **Angebot anfragen** | [sec-auditor.com](https://sec-auditor.com) |
