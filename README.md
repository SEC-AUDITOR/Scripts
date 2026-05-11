<p align="center">
  <img src="https://sec-auditor.com/wp-content/uploads/sec-auditor-logo.png" alt="SEC AUDITOR" width="280" />
</p>

<h1 align="center">SEC AUDITOR – PowerShell Skript-Sammlung</h1>

<p align="center">
  Offizielle Skripte für Dienstleister und Partner von <a href="https://sec-auditor.com">sec-auditor.com</a>
</p>

---

Dieses Repository enthält PowerShell-Skripte, die SEC AUDITOR Kunden und Partner bei der Evaluierung und Integration unterstützen. Die Skripte sind nach Themen in Unterordnern organisiert.

## Ordnerstruktur

| Ordner | Inhalt |
|---|---|
| [`Evaluation/`](./Evaluation/) | Skripte zur Ermittlung aktiver Benutzer – für eine Kostenschätzung |
| [`API/`](./API/) | Demo-Skript zur Nutzung der SEC AUDITOR REST-API mit einem API-Account |

---

## Evaluation

Die Skripte im Ordner [`Evaluation/`](./Evaluation/) helfen dabei, die Anzahl aktiver Benutzer in Ihrer Umgebung zu ermitteln. Da sich die Lizenzkosten bei SEC AUDITOR nach der Anzahl der aktiven Benutzer richten, liefern diese Skripte eine verlässliche Grundlage für eine Kostenkalkulation.

Unterstützte Umgebungen:

- **Microsoft Entra ID** (Azure AD, Cloud-only und Hybrid)
- **On-Premises Active Directory** (klassisches AD mit Domain Controllern)

[→ Zur den Skripten](./Evaluation/)

---

## API-Integration

Das Skript im Ordner [`API/`](./API/) zeigt, wie Sie die SEC AUDITOR REST-API per PowerShell ansprechen – inklusive Authentifizierung über Keycloak (OAuth 2.0) und einem Beispielaufruf zum Abruf von Sicherheitsdaten.

Weitere Informationen zur API finden Sie in unserem [FAQ-Artikel zur API-Nutzung](https://sec-auditor.com/docs/faq/api/).

[→ Zur Dokumentation](./API/)

---

## Voraussetzungen

- **PowerShell 5.1** oder neuer (auf Windows standardmäßig vorhanden)
- Skriptspezifische Voraussetzungen sind in den jeweiligen Unterordnern dokumentiert

---

## Kontakt & Support

|                         | |
|-------------------------|---|
| **Homepage**            | [sec-auditor.com](https://sec-auditor.com) |
| **Support**             | [support@sec-auditor.com](mailto:support@sec-auditor.com) |
| **Dokumentation**       | [sec-auditor.com/docs](https://sec-auditor.com/docs) |
