Config = {}

-- Framework-Einstellungen (nur grundlegende Konfiguration)
Config.Framework = 'esx'           -- Framework: esx
Config.Database = 'oxmysql'        -- Datenbank: oxmysql
Config.Debug = false               -- Debug-Ausgaben in der Konsole
Config.AutoInstallSQL = true       -- SQL beim Start automatisch ausführen (sql/install.sql)

-- Menü-System: ox_lib Context-Menüs (nativ im Spiel, kein HTML-Overlay)
Config.MenuSystem = 'ox_lib'

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
