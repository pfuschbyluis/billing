# ESX Rechnungssystem

Deutsches Rechnungssystem für **FiveM ESX Legacy** mit Ingame-Adminpanel, Steuersystem, Discord-Logging und MySQL-Persistenz.

## Features

- Vollständig deutsches UI und Benachrichtigungen
- Ingame-Adminpanel (`/rechnungadmin`) – fast alle Einstellungen ohne `config.lua`-Bearbeitung
- Automatische Rechnungsnummern (z. B. `RE-2026-000001`)
- Steuersystem mit Netto-, Steuer- und Bruttobeträgen
- Firmendaten pro Society (Name, Adresse, Steuernummer, USt-IdNr.)
- Job-spezifische Einstellungen (Berechtigungen, Maximalbeträge, Zahlungsarten, Geldverteilung)
- Spieler-Rechnungsübersicht (`/rechnungen`) mit Bezahlfunktion
- Rechnungen ausstellen (`/rechnung`) für berechtigte Jobs
- Discord-Webhook-Logging
- Mahngebühren bei überfälligen Rechnungen
- Serverseitige Validierung aller kritischen Aktionen

## Abhängigkeiten

- [es_extended](https://github.com/esx-framework/esx_core) (ESX Legacy)
- [oxmysql](https://github.com/overextended/oxmysql)
- [esx_addonaccount](https://github.com/esx-framework/esx_addonaccount) (für Society-Konten)

## Installation

1. Resource in den `resources`-Ordner kopieren:
   ```
   resources/[esx]/esx_rechnungen/
   ```

2. In `server.cfg` eintragen:
   ```
   ensure esx_rechnungen
   ```

3. Server starten – die SQL-Tabellen werden **automatisch** beim ersten Start angelegt.
   In der Live-Console erscheint dazu Feedback, z. B.:
   ```
   [esx_rechnungen] Datenbank-Installation wird gestartet...
   [esx_rechnungen] [1/6] Tabelle 'rechnungen_settings' ... OK
   [esx_rechnungen] Datenbank-Installation abgeschlossen (6/6 erfolgreich).
   ```

   Die automatische Installation kann in der `config.lua` deaktiviert werden:
   ```lua
   Config.AutoInstallSQL = false
   ```
   Dann muss `sql/install.sql` manuell importiert werden.

4. Im Adminpanel Jobs konfigurieren, die Rechnungen ausstellen dürfen.

## Commands

| Command | Beschreibung | Berechtigung |
|---------|-------------|--------------|
| `/rechnungen` | Eigene Rechnungen anzeigen & bezahlen | Alle Spieler |
| `/rechnung` | Neue Rechnung ausstellen | Jobs mit Berechtigung |
| `/rechnungadmin` | Adminpanel öffnen | Admin-Gruppen (siehe config.lua) |

## Adminpanel

Das Adminpanel ist über `/rechnungadmin` erreichbar und bietet vier Bereiche:

### Rechnungen
Alle Rechnungen einsehen, bearbeiten, stornieren oder löschen.

### Jobs
Pro Job konfigurierbar:
- Rechnungen schreiben dürfen
- An Spieler / Firmen ausstellen
- Maximaler Rechnungsbetrag
- Nähe-Pflicht und maximale Entfernung
- Zahlungsarten (Bank, Bargeld)
- Geldziel (Society, Mitarbeiter, prozentuale Aufteilung)
- Job-spezifischer Steuersatz

### Firmen
Pro Society:
- Firmenname und Adresse
- Steuernummer und Umsatzsteuer-ID
- Rechnungspräfix

### Einstellungen
- Discord-Logging und Webhook
- Steuersystem (aktivieren, Standard-Steuersatz)
- Automatische Rechnungsnummern
- Zahlungsfrist und Mahngebühren
- Login-Benachrichtigung bei offenen Rechnungen
- Admin-Berechtigungen

## Rechnungsinhalt

Jede Rechnung enthält:
- Rechnungsnummer, Datum, Fälligkeitsdatum
- Aussteller/Firma mit Adresse
- Steuernummer / USt-IdNr.
- Empfänger und Rechnungsgrund
- Netto-, Steuer- und Bruttobetrag
- Zahlungsstatus

## Serverseitige Sicherheit

Folgende Prüfungen erfolgen ausschließlich serverseitig:
- Job-Berechtigung und Rechnungsrechte
- Betragsvalidierung und Maximalbetrag
- Empfänger-Existenz und Nähe-Prüfung
- Geldverfügbarkeit bei Zahlung
- Society-Existenz
- Admin-Rechte für das Adminpanel

## Exports

```lua
-- Spieler-Rechnungsmenü öffnen
exports['esx_rechnungen']:OpenInvoiceMenu()

-- Adminpanel öffnen (prüft Berechtigung)
exports['esx_rechnungen']:OpenAdminPanel()

-- Rechnungserstellung öffnen
exports['esx_rechnungen']:OpenCreateInvoice()
```

## Konfiguration (config.lua)

Die `config.lua` enthält nur grundlegende Einstellungen:
- Framework- und Datenbank-Auswahl
- Debug-Modus
- Automatische SQL-Installation (`Config.AutoInstallSQL`)
- Admin-Gruppen
- Command-Namen

Alle spielrelevanten Einstellungen werden im Adminpanel verwaltet und in MySQL gespeichert.

## Lizenz

Frei verwendbar für Roleplay-Server.
