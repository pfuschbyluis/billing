Config = {}

-- Framework-Einstellungen (nur grundlegende Konfiguration)
Config.Framework = 'esx'
Config.Database = 'oxmysql'
Config.Debug = false
Config.AutoInstallSQL = true

-- Custom-Menü Einstellungen
Config.MenuPosition = 'right'      -- Position: right (Popover rechts im Bild)
Config.MenuWidth = 420             -- Breite des Menüs in Pixel

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
