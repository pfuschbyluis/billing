# ESX Rechnungssystem

Deutsches Rechnungssystem für **FiveM ESX Legacy** mit **eigenem Custom-Menü**, Steuersystem und MySQL-Persistenz.

## Features

- **Eigenes Custom-Menü** – kein ox_lib, kein Browser-Fenster
- Kompaktes **Popover-Menü** rechts im Bildschirm (slide-in)
- Listen-Navigation mit Zurück-Button (wie ein natives Spielmenü)
- SVG-Icons, Ingame-Dialoge und Toasts
- Adminpanel mit Tabs: Rechnungen, Jobs, Firmen, System
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
| `/rechnungen` | Eigene Rechnungen anzeigen & bezahlen |
| `/rechnung` | Neue Rechnung ausstellen |
| `/rechnungadmin` | Adminpanel (nur Admins) |

## Custom-Menü

Das Menü ist ein schlankes Popover-Panel auf der rechten Seite:

- **Spieler:** Kategorien → Liste → Detail → Bezahlung
- **Erstellen:** Empfänger wählen → Formular
- **Admin:** Tabs mit Statistiken, Formularen und Verwaltung

Alle Dialoge (Bestätigen, Eingabe, Hinweise) laufen im Menü – nichts öffnet sich auf dem PC.

## Konfiguration (`config.lua`)

```lua
Config.MenuWidth = 420        -- Menübreite in Pixel
Config.MenuPosition = 'right' -- Position (right)
```

## Exports

```lua
exports['esx_rechnungen']:OpenInvoiceMenu()
exports['esx_rechnungen']:OpenAdminPanel()
exports['esx_rechnungen']:OpenCreateInvoice()
```

## Lizenz

Frei verwendbar für Roleplay-Server.
