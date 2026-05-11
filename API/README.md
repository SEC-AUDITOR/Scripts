<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://assets.sec-auditor.com/images/logo_gradient_negative.svg" />
    <img src="https://assets.sec-auditor.com/images/logo_gradient.svg" alt="SEC AUDITOR" width="280" />
  </picture>
</p>

<h1 align="center">API-Integration – Demo</h1>

<p align="center">
  Einstieg in die SEC AUDITOR REST-API | <a href="https://sec-auditor.com/docs/faq/api/">API-Dokumentation</a>
</p>

---

SEC AUDITOR bietet eine **REST-API** für die programmatische Integration in eigene Tools, Portale oder Automatisierungen. Dieses Demo-Skript zeigt, wie Sie sich authentifizieren und erste API-Abfragen durchführen.

Weiterführende Informationen und Hintergründe finden Sie in unserem [FAQ-Artikel zur API-Nutzung](https://sec-auditor.com/docs/faq/api/).

---

## Skript: `API-Demo.ps1`

Das Skript demonstriert den vollständigen Ablauf einer API-Nutzung:

1. **Authentifizierung** über Keycloak (OAuth 2.0 / Resource Owner Password Flow) gegen `auth.sec-auditor.com`
2. **JWT-Token dekodieren** und Token-Details ausgeben (Subject, Issuer, Ablaufzeit)
3. **API-Abfrage** – Beispielaufruf zum Abruf des Security Logs (`/api/v1/client/{uuid}/ioe`) für einen bestimmten Mandanten

---

## Voraussetzungen

- PowerShell 5.1 oder neuer
- Ein **API-Account** bei SEC AUDITOR (separater Account, kein normaler Benutzer-Login)

---

## Konfiguration

Öffnen Sie `API-Demo.ps1` und passen Sie die folgenden Variablen an:

```powershell
$username = "api_xxx"   # Ihr API-Benutzername
$password = "yyy"       # Ihr API-Passwort
```

Die Client-UUID für den API-Aufruf (`Get-SecurityLog`) müssen Sie auf die UUID des gewünschten Mandanten setzen:

```powershell
$securityLog = Get-SecurityLog -jwt $accessToken -clientUUID "<ihre-mandanten-uuid>"
```

> **Hinweis:** Speichern Sie Zugangsdaten nicht in Klartext in Skripten, die in Versionsverwaltungen abgelegt werden. Für den Produktiveinsatz empfiehlt sich die Verwendung von `Get-Credential`, Umgebungsvariablen oder einem Secret-Manager.

---

## Ausführung

```powershell
.\API-Demo.ps1
```

**Erwartete Ausgabe:**

```
Access Token:
eyJhbGci...

Token Payload:
{
  "sub": "...",
  "iss": "https://auth.sec-auditor.com/auth/realms/sec-auditor",
  "exp": ...
}

Key Information:
Subject: ...
Issuer:  https://auth.sec-auditor.com/auth/realms/sec-auditor
Expiration: 2025-01-01 12:00:00

Security Log:
...
```

---

## Weitere Ressourcen

- [FAQ: API-Nutzung](https://sec-auditor.com/docs/faq/api/) – Überblick und Einstieg
- [Swagger API-Referenz](https://api.sec-auditor.com/documentation/#/) – vollständige Endpunktdokumentation

---

## Kontakt & Support

| | |
|---|---|
| **Website** | [sec-auditor.com](https://sec-auditor.com) |
| **Support** | [support@sec-auditor.com](mailto:support@sec-auditor.com) |
