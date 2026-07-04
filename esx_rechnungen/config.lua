Config = {}

-- ============================================================
-- Framework
-- ============================================================
Config.Framework = 'esx'          -- 'esx' | 'auto' (auto = ESX)
Config.Database = 'oxmysql'
Config.Debug = false
Config.AutoInstallSQL = true
Config.Locale = 'de'              -- de | en | fr (en/fr in locales/ erweiterbar)

-- ============================================================
-- Access – Menü öffnen
-- ============================================================
Config.Access = {
  command = 'rechnungsmenu',
  keybind = 'F7',
  keybind_description = 'Rechnungssystem öffnen',
  player_command = 'rechnungen',
  create_command = 'rechnung',
  admin_command = 'rechnungadmin',
}

-- Statische Rechnungsstationen (optional, zusätzlich zu F7)
-- jobs = nil → alle Jobs | hours = nil → immer geöffnet
Config.Locations = {
  -- Beispiel:
  -- {
  --   coords = vector3(241.0, 224.0, 106.0),
  --   jobs = { 'police', 'ambulance' },
  --   hours = { open = 8, close = 20 },
  --   blip = { enabled = true, sprite = 500, color = 83, scale = 0.75, label = 'Rechnungen' },
  --   marker = { enabled = true, type = 27, scale = vector3(1.0, 1.0, 1.0), color = { r = 125, g = 82, b = 255, a = 140 } },
  --   radius = 2.5,
  -- },
}

-- ============================================================
-- UI
-- ============================================================
Config.UI = {
  width = 1200,
  position = 'center',
  colors = {
    accent = '#2fd07a',
    accent_glow = 'rgba(47, 208, 122, 0.35)',
    background = '#0b0d10',
    card = '#14181e',
    text = '#eef0f3',
    text_dim = '#9aa0aa',
    success = '#2fd07a',
    warning = '#f5a623',
    danger = '#f0616d',
    info = '#4f9bff',
  },
  logo = 'R',                      -- Logo-Buchstabe im Header
}

-- Legacy-Kompatibilität
Config.MenuWidth = Config.UI.width
Config.MenuPosition = Config.UI.position
Config.HubCommand = Config.Access.command
Config.PlayerCommand = Config.Access.player_command
Config.CreateCommand = Config.Access.create_command
Config.AdminCommand = Config.Access.admin_command
Config.Keybind = Config.Access.keybind
Config.KeybindDescription = Config.Access.keybind_description

-- ============================================================
-- Restrictions – Jobs & Blacklist
-- ============================================================
-- true = alle Jobs außer unemployed | false = nur Adminpanel | Tabelle = nur diese Jobs
Config.InvoiceJobs = true

Config.Blacklist = {
  -- 'unemployed',
  -- 'offduty_police',
}

-- ============================================================
-- Permissions – Rang & Boss
-- ============================================================
Config.Permissions = {
  default_min_grade = 0,           -- Mindest-Rang zum Ausstellen
  boss_auto_manage = true,         -- Boss-Rang darf immer ausstellen
  admin_groups = { 'admin', 'superadmin', 'mod' },
  job_overrides = {
    -- police = { min_grade_issue = 2, min_grade_view = 0 },
  },
}

-- Legacy
Config.AdminGroups = Config.Permissions.admin_groups

-- ============================================================
-- Payment – Konten & Society
-- ============================================================
Config.Payment = {
  methods = { 'bank', 'cash' },    -- Erlaubte Zahlungsarten (global)
  society_enabled = true,
  default_destination = 'society', -- society | employee | split
}

-- ============================================================
-- Taxes & Mahnung
-- ============================================================
Config.Taxes = {
  enabled = true,
  default_rate = 19.0,
  overdue_fee = 25.0,              -- Mahngebühr bei Überfälligkeit
}

-- ============================================================
-- Durations – Fälligkeits-Presets
-- ============================================================
Config.Durations = {
  { label = '1 Tag', days = 1 },
  { label = '3 Tage', days = 3 },
  { label = '1 Woche', days = 7 },
  { label = '2 Wochen', days = 14 },
  { label = '1 Monat', days = 30 },
  { label = '3 Monate', days = 90 },
}

-- ============================================================
-- Limits
-- ============================================================
Config.Limits = {
  max_amount = 10000,
  max_items_per_invoice = 20,
  max_note_length = 2000,
  max_reason_length = 500,
  max_templates = 50,
  default_max_distance = 5.0,
}

-- ============================================================
-- Prefix – Rechnungsnummern
-- ============================================================
Config.Prefix = {
  global = 'RE',                   -- RE-2026-000001
  per_job = true,                  -- Job-Präfix aus Society-Info wenn vorhanden
}

-- ============================================================
-- Overdue – Überfälligkeit & Erinnerungen
-- ============================================================
Config.Overdue = {
  check_interval_minutes = 30,     -- Intervall für Status-Update
  dunning_enabled = true,            -- Mahngebühr bei Überfälligkeit
  reminder_days_before = { 3, 1 }, -- Erinnerung X Tage vor Fälligkeit
  reminder_on_login = true,
}

-- ============================================================
-- Signature
-- ============================================================
Config.Signature = {
  required = true,                 -- Unterschrift Pflicht beim Erstellen
  -- FiveManage API (optional, für externen Upload – sonst lokal in DB)
  fivemanage_api_key = '',
  fivemanage_enabled = false,
}

-- ============================================================
-- Notify
-- ============================================================
-- preset: 'esx' | 'ox_lib' | 'custom'
Config.Notify = {
  preset = 'esx',
  custom_export = nil,             -- z.B. 'my_notify:Alert'
}

-- ============================================================
-- Discord Logging
-- ============================================================
Config.Discord = {
  enabled = false,
  webhook = '',
}

-- ============================================================
-- Default Job Permissions (wenn kein DB-Eintrag)
-- ============================================================
Config.DefaultJobPermissions = {
  can_issue = 1,
  can_issue_player = 1,
  can_issue_society = 0,
  max_amount = Config.Limits.max_amount,
  require_proximity = 1,
  max_distance = Config.Limits.default_max_distance,
  payment_bank = 1,
  payment_cash = 1,
  money_destination = Config.Payment.default_destination,
  society_percent = 70,
  employee_percent = 30,
  tax_rate = Config.Taxes.default_rate,
  min_grade = Config.Permissions.default_min_grade,
}

-- ============================================================
-- DB-Standardwerte (Adminpanel überschreibt diese)
-- ============================================================
Config.DefaultSettings = {
  discord_enabled = Config.Discord.enabled,
  discord_webhook = Config.Discord.webhook,
  tax_enabled = Config.Taxes.enabled,
  default_tax_rate = Config.Taxes.default_rate,
  auto_invoice_numbers = true,
  reminder_fee = Config.Taxes.overdue_fee,
  payment_deadline_days = 14,
  show_unpaid_on_login = Config.Overdue.reminder_on_login,
  admin_can_view = true,
  admin_can_edit = true,
  admin_can_delete = true,
  admin_can_cancel = true,
  default_max_distance = Config.Limits.default_max_distance,
  invoice_prefix = Config.Prefix.global,
  rejection_enabled = true,
}
