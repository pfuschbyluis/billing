# ESX Rechnungssystem

Deutsches Rechnungssystem für **FiveM ESX Legacy** mit **ox_lib Menüs** (nativ im Spiel), Steuersystem, Discord-Logging und MySQL-Persistenz.

## Features

- **Native ox_lib Menüs** – kein HTML-Overlay, alles direkt im Spiel
- Context-Menüs, Input-Dialoge und Bestätigungen über ox_lib
- Ingame-Adminpanel (`/rechnungadmin`)
- Automatische Rechnungsnummern (z. B. `RE-2026-000001`)
- Steuersystem mit Netto-, Steuer- und Bruttobeträgen
- Firmendaten pro Society (Name, Adresse, Steuernummer, USt-IdNr.)
- Job-spezifische Einstellungen
- Discord-Webhook-Logging
- Automatische SQL-Installation beim Serverstart
- Serverseitige Validierung

## Abhängigkeiten

- [es_extended](https://github.com/esx-framework/esx_core) (ESX Legacy)
- [oxmysql](https://github.com/overextended/oxmysql)
- [ox_lib](https://github.com/overextended/ox_lib)
- [esx_addonaccount](https://github.com/esx-framework/esx_addonaccount) (Society-Konten)

## Installation

1. Resource in `resources/[esx]/esx_rechnungen/` kopieren
2. Sicherstellen, dass **ox_lib** installiert und gestartet ist:
   ```
   ensure ox_lib
   ensure esx_rechnungen
   ```
3. Server starten – SQL-Tabellen werden automatisch angelegt
4. Im Adminpanel Jobs für Rechnungserstellung freischalten

## Commands

| Command | Beschreibung |
|---------|-------------|
| `/rechnungen` | Eigene Rechnungen anzeigen & bezahlen |
| `/rechnung` | Neue Rechnung ausstellen |
| `/rechnungadmin` | Adminpanel (nur Admins) |

## Menü-System

Das Script nutzt **ox_lib Context-Menüs** statt HTML/NUI:

- **Spieler:** Kategorien (Offen/Bezahlt/Überfällig), Detailansicht mit Metadaten, Bezahlung per Bank/Bar
- **Rechnung erstellen:** Schritt-für-Schritt (Empfänger → Formular)
- **Admin:** Rechnungen, Jobs, Firmen, Einstellungen – alles als native Menüs und Dialoge

## Exports

```lua
exports['esx_rechnungen']:OpenInvoiceMenu()
exports['esx_rechnungen']:OpenAdminPanel()
exports['esx_rechnungen']:OpenCreateInvoice()
```

## Konfiguration

Die `config.lua` enthält nur grundlegende Einstellungen. Alle spielrelevanten Optionen werden im Adminpanel verwaltet und in MySQL gespeichert.

## Lizenz

Frei verwendbar für Roleplay-Server.
