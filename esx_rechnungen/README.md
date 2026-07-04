# ESX Rechnungssystem

Deutsches Rechnungssystem für **FiveM ESX Legacy** mit **eigenem Billing-Dashboard**, Steuersystem und MySQL-Persistenz.

## Features

- **Eigenes Billing-Dashboard** – kein ox_lib, kein Browser-Fenster
- Großes, zentriertes Panel im Spiel (RiP-Style, dunkles Lila-Design)
- Tabs: Übersicht, Statistik, Rechnung erstellen, Admin
- Statistik-Karten, ERSTELLT/EMPFANGEN-Untertabs, Suche & Filter
- Rechnungszeilen mit Status-Badge, ANSEHEN und Admin-Löschen
- SVG-Icons, Ingame-Dialoge und Toasts
- Adminpanel: Rechnungen, Jobs, Firmen, System
- Automatische SQL-Installation beim Serverstart
- Serverseitige Validierung

## Abhängigkeiten

- [es_extended](https://github.com/esx-framework/esx_core) (ESX Legacy)
- [oxmysql](https://github.com/overextended/oxmysql)
- [esx_addonaccount](https://github.com/esx-framework/esx_addonaccount) (Society-Konten)

**Kein ox_lib erforderlich.**

## Installation

1. Resource nach `resources/[esx]/esx_rechnungen/` kopieren
2. In `server.cfg`:
   ```
   ensure esx_rechnungen
   ```
3. Server starten – SQL wird automatisch importiert
4. Jobs im Adminpanel freischalten

## Commands

| Command | Beschreibung |
|---------|-------------|
| **F7** / `/rechnungsmenu` | **Billing-Dashboard** öffnen/schließen |
| `/rechnungen` | Dashboard → Übersicht (Empfangen) |
| `/rechnung` | Dashboard → Rechnung erstellen |
| `/rechnungadmin` | Dashboard → Admin |

### F7-Dashboard

Mit **F7** öffnet sich das zentrale Billing-Panel:

- **Übersicht** – Statistik-Karten, Rechnungsliste (Erstellt/Empfangen), Suche & Filter
- **Statistik** – Status-Verteilung und Tageswerte
- **Rechnung erstellen** – Papier-Layout mit Positionen, Vorlagen, Notizen und Unterschrift
- **Admin** – Rechnungen, Jobs, Firmen, Systemeinstellungen (nur Admins)

F7 erneut drücken schließt das Dashboard.

### Rechnung erstellen (Papier-UI)

Beim Tab **Rechnung erstellen** erscheint ein weißes Papier-Formular:

- Aussteller (Persönlich / Firma), Empfänger, Zahlungsfrist, Vorlage
- Positionstabelle mit Beschreibung, Menge und Preis
- Live-Berechnung: Zwischensumme, Steuer, Gesamt
- Notizen und Unterschrift (Pflicht vor dem Erstellen)
- ABBRECHEN zurück zur Übersicht · ERSTELLEN sendet an den Server

## Konfiguration (`config.lua`)

```lua
Config.MenuWidth = 1100        -- Dashboard-Breite in Pixel (max)
Config.MenuPosition = 'center' -- Zentriertes Panel
Config.Keybind = 'F7'          -- Taste für Dashboard
```

## Exports

```lua
exports['esx_rechnungen']:OpenDashboard()     -- F7-Dashboard
exports['esx_rechnungen']:OpenHubMenu()       -- Alias für OpenDashboard
exports['esx_rechnungen']:OpenInvoiceMenu()   -- Übersicht (Empfangen)
exports['esx_rechnungen']:OpenAdminPanel()
exports['esx_rechnungen']:OpenCreateInvoice()
```

## Lizenz

MIT
