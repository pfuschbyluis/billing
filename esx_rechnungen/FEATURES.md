# ESX Rechnungssystem – Feature-Übersicht

Vergleich zur RiP-Billing-Spezifikation. Alles Wichtige ist über `config.lua` steuerbar.

## Config-Kategorien

| Kategorie | Config-Sektion | Status |
|-----------|----------------|--------|
| Access (Command, Keybind, Stationen) | `Config.Access`, `Config.Locations` | ✅ |
| Restrictions (Jobs, Blacklist) | `Config.InvoiceJobs`, `Config.Blacklist` | ✅ |
| Payment (Bank/Bar, Society) | `Config.Payment` + Adminpanel Jobs | ✅ |
| Taxes & Mahnung | `Config.Taxes`, `Config.Overdue` | ✅ |
| Durations (Presets) | `Config.Durations` | ✅ |
| Limits | `Config.Limits` | ✅ |
| Permissions (Rang, Boss) | `Config.Permissions` | ✅ |
| Prefix | `Config.Prefix` + Society-Info | ✅ |
| Overdue & Erinnerungen | `Config.Overdue` | ✅ |
| Signature | `Config.Signature` | ✅ (lokal; FiveManage optional) |
| Blacklist | `Config.Blacklist` | ✅ |
| Blips & Marker | `Config.Locations` | ✅ |
| Notify | `Config.Notify` (esx / ox_lib / custom) | ✅ |
| Übersetzungen | `Config.Locale`, `locales/de.lua` | ✅ |
| UI-Farben & Logo | `Config.UI.colors`, `Config.UI.logo` | ✅ |
| Discord | `Config.Discord` + Adminpanel | ✅ |

## Features

| Feature | Status |
|---------|--------|
| Privat & Business (Persönlich/Firma) | ✅ |
| Vorlagen-System | ✅ |
| Statistik-Dashboard mit Chart | ✅ |
| Rang-Berechtigungen | ✅ |
| Steuer & Mahngebühr | ✅ |
| Unterschrift zeichnen | ✅ |
| Flexible Fälligkeiten | ✅ |
| Zahlungsmethoden Bank/Bar | ✅ |
| Ablehnen mit Grund + Benachrichtigung | ✅ |
| Überfälligkeits-Erkennung | ✅ |
| Erinnerungen vor Fälligkeit | ✅ |
| Suche & Filter | ✅ |
| Job-Präfixe | ✅ |
| Rechnungsstationen | ✅ |
| Adminpanel (MySQL) | ✅ |
| Exports & Events | ✅ |
| Tablet / Physical Items / FiveManage Upload | ❌ (nicht geplant) |

## Schnellstart

```lua
-- config.lua
Config.InvoiceJobs = true          -- alle Jobs dürfen ausstellen
Config.Permissions.default_min_grade = 0
Config.Blacklist = { 'unemployed' }
```

Resource neu starten: `ensure esx_rechnungen`
