Config = {}

-- Framework-Einstellungen (nur grundlegende Konfiguration)
Config.Framework = 'esx'
Config.Database = 'oxmysql'
Config.Debug = false
Config.AutoInstallSQL = true

-- Custom-Menü Einstellungen
Config.MenuWidth = 1100           -- Dashboard-Breite in Pixel (max)
Config.MenuPosition = 'center'    -- Zentriertes Dashboard

-- Admin-Berechtigungen (Gruppen aus ESX)
Config.AdminGroups = {
    'admin',
    'superadmin',
    'mod'
}

-- Commands
Config.AdminCommand = 'rechnungadmin'
Config.PlayerCommand = 'rechnungen'
Config.CreateCommand = 'rechnung'
Config.HubCommand = 'rechnungsmenu'  -- Hauptmenü-Command (zusätzlich zum Keybind)

-- Keybind: F7 öffnet das Rechnungs-Hauptmenü
Config.Keybind = 'F7'
Config.KeybindDescription = 'Rechnungssystem öffnen'

-- Welche Jobs Rechnungen ausstellen dürfen (wenn noch nicht im Adminpanel gespeichert):
-- true   = alle Jobs außer 'unemployed' (Standard – praktisch für die meisten Server)
-- false  = NUR Jobs die ein Admin im Panel unter "Jobs" aktiviert hat
-- Tabelle = nur diese Job-Namen, z.B. {'police', 'ambulance', 'mechanic'}
Config.InvoiceJobs = true

-- Standard-Berechtigungen für Jobs ohne eigene DB-Einträge (siehe Config.InvoiceJobs)
Config.DefaultJobPermissions = {
    can_issue = 1,
    can_issue_player = 1,
    can_issue_society = 0,
    max_amount = 10000,
    require_proximity = 1,
    max_distance = 5.0,
    payment_bank = 1,
    payment_cash = 1,
    money_destination = 'society',
    society_percent = 70,
    employee_percent = 30,
    tax_rate = 19.0
}

-- Standardwerte beim ersten Start (werden in DB überschrieben)
Config.DefaultSettings = {
    discord_enabled = false,
    discord_webhook = '',
    tax_enabled = true,
    default_tax_rate = 19.0,
    auto_invoice_numbers = true,
    reminder_fee = 25.0,
    payment_deadline_days = 14,
    show_unpaid_on_login = true,
    admin_can_view = true,
    admin_can_edit = true,
    admin_can_delete = true,
    admin_can_cancel = true,
    default_max_distance = 5.0,
    invoice_prefix = 'RE'
}
