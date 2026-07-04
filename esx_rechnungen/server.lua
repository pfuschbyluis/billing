--[[
    ESX Rechnungssystem - Server
    Serverseitige Logik, Validierung, Datenbank und Discord-Logging
]]

local ESX = exports['es_extended']:getSharedObject()

-- Cache für globale Einstellungen
local GlobalSettings = {}
local JobSettings = {}
local SocietyInfo = {}

-- ============================================================
-- Hilfsfunktionen
-- ============================================================

--- Konsolen-Ausgabe mit Farbe für die Live-Console
---@param level string 'info' | 'success' | 'error'
---@param message string
local function ConsoleLog(level, message)
    local color = '^7'
    if level == 'success' then color = '^2'
    elseif level == 'error' then color = '^1'
    elseif level == 'info' then color = '^3'
    end

    print(('%s[esx_rechnungen]^7 %s'):format(color, message))
end

--- Extrahiert einen lesbaren Namen aus einem SQL-Statement
---@param statement string
---@return string
local function GetStatementLabel(statement)
    local tableName = statement:match('CREATE TABLE IF NOT EXISTS [`"]?(%w+)[`"]?')
    if tableName then
        return ("Tabelle '%s'"):format(tableName)
    end

    if statement:match('^%s*INSERT') then
        return 'Standard-Einstellungen'
    end

    return 'SQL-Statement'
end

--- Teilt SQL-Datei in einzelne Statements auf
---@param sql string
---@return table
local function ParseSQLStatements(sql)
    local statements = {}
    local current = ''

    for line in sql:gmatch('[^\r\n]+') do
        local trimmed = line:match('^%s*(.-)%s*$')
        if trimmed ~= '' and not trimmed:match('^%-%-') then
            current = current .. ' ' .. trimmed
            if trimmed:sub(-1) == ';' then
                local statement = current:sub(1, -2):match('^%s*(.-)%s*$')
                if statement and statement ~= '' then
                    table.insert(statements, statement)
                end
                current = ''
            end
        end
    end

    return statements
end

--- Führt sql/install.sql automatisch aus
---@return boolean success
local function InstallDatabase()
    if not Config.AutoInstallSQL then
        ConsoleLog('info', 'Automatische SQL-Installation ist deaktiviert (Config.AutoInstallSQL = false).')
        return true
    end

    local resourceName = GetCurrentResourceName()
    local sqlContent = LoadResourceFile(resourceName, 'sql/install.sql')

    if not sqlContent or sqlContent == '' then
        ConsoleLog('error', 'SQL-Datei nicht gefunden: sql/install.sql')
        return false
    end

    local statements = ParseSQLStatements(sqlContent)
    if #statements == 0 then
        ConsoleLog('error', 'Keine gültigen SQL-Statements in sql/install.sql gefunden.')
        return false
    end

    ConsoleLog('info', '============================================================')
    ConsoleLog('info', 'Datenbank-Installation wird gestartet...')
    ConsoleLog('info', ('Gefundene SQL-Statements: %d'):format(#statements))

    local successCount = 0
    local failCount = 0

    for index, statement in ipairs(statements) do
        local label = GetStatementLabel(statement)
        local ok, err = pcall(function()
            MySQL.query.await(statement)
        end)

        if ok then
            successCount = successCount + 1
            ConsoleLog('success', ('[%d/%d] %s ... OK'):format(index, #statements, label))
        else
            failCount = failCount + 1
            ConsoleLog('error', ('[%d/%d] %s ... FEHLER: %s'):format(index, #statements, label, tostring(err)))
        end
    end

    ConsoleLog('info', '------------------------------------------------------------')
    if failCount == 0 then
        ConsoleLog('success', ('Datenbank-Installation abgeschlossen (%d/%d erfolgreich).'):format(successCount, #statements))
    else
        ConsoleLog('error', ('Datenbank-Installation mit Fehlern beendet (%d OK, %d FEHLER).'):format(successCount, failCount))
    end
    ConsoleLog('info', '============================================================')

    return failCount == 0
end

--- Führt Schema-Migrationen für bestehende Installationen aus
local function RunMigrations()
    local migrations = {
        "ALTER TABLE rechnungen_invoices ADD COLUMN notes TEXT DEFAULT NULL",
        "ALTER TABLE rechnungen_invoices ADD COLUMN line_items JSON DEFAULT NULL",
        "ALTER TABLE rechnungen_invoices ADD COLUMN signature MEDIUMTEXT DEFAULT NULL",
        "ALTER TABLE rechnungen_invoices ADD COLUMN duration_days INT DEFAULT NULL",
        "ALTER TABLE rechnungen_invoices ADD COLUMN issuer_mode VARCHAR(20) DEFAULT 'personal'",
        "ALTER TABLE rechnungen_invoices MODIFY payment_status ENUM('open','paid','cancelled','overdue','rejected') NOT NULL DEFAULT 'open'",
        [[CREATE TABLE IF NOT EXISTS rechnungen_contacts (
            id INT NOT NULL AUTO_INCREMENT,
            owner_identifier VARCHAR(60) NOT NULL,
            contact_name VARCHAR(100) NOT NULL,
            contact_identifier VARCHAR(60) NOT NULL,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            UNIQUE KEY owner_contact (owner_identifier, contact_identifier)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]],
        [[CREATE TABLE IF NOT EXISTS rechnungen_templates (
            id INT NOT NULL AUTO_INCREMENT,
            owner_identifier VARCHAR(60) NOT NULL,
            job_name VARCHAR(50) DEFAULT NULL,
            is_shared TINYINT(1) NOT NULL DEFAULT 0,
            name VARCHAR(100) NOT NULL,
            title VARCHAR(200) DEFAULT NULL,
            notes TEXT DEFAULT NULL,
            line_items JSON DEFAULT NULL,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]],
        [[CREATE TABLE IF NOT EXISTS rechnungen_user_prefs (
            identifier VARCHAR(60) NOT NULL,
            theme VARCHAR(10) NOT NULL DEFAULT 'dark',
            view_mode VARCHAR(10) NOT NULL DEFAULT 'table',
            account_mode VARCHAR(10) NOT NULL DEFAULT 'personal',
            updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (identifier)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]]
    }

    for _, statement in ipairs(migrations) do
        pcall(function()
            MySQL.query.await(statement)
        end)
    end
end

--- Standard-Vorlagen für Rechnungserstellung
---@return table
local function GetDefaultTemplates()
    return {
        { name = 'Reparatur', items = { { description = 'Reparatur', units = 1, price = 100 } }, notes = '' },
        { name = 'Dienstleistung', items = { { description = 'Dienstleistung', units = 1, price = 250 } }, notes = '' },
        { name = 'Material', items = { { description = 'Material', units = 1, price = 50 } }, notes = '' }
    }
end

--- Charaktername aus Identifier (auch offline)
---@param identifier string
---@return string
local function GetCharacterName(identifier)
    local row = MySQL.single.await('SELECT firstname, lastname FROM users WHERE identifier = ? LIMIT 1', { identifier })
    if row and row.firstname then
        return (row.firstname .. ' ' .. (row.lastname or '')):gsub('%s+$', '')
    end

    row = MySQL.single.await('SELECT name FROM users WHERE identifier = ? LIMIT 1', { identifier })
    if row and row.name then
        return row.name
    end

    return identifier
end

--- Vorlagen aus DB + Standard
---@param identifier string
---@param jobName string
---@return table
local function GetTemplatesForPlayer(identifier, jobName)
    local templates = {}
    for _, tpl in ipairs(GetDefaultTemplates()) do
        templates[#templates + 1] = tpl
    end

    local dbTemplates = MySQL.query.await(
        'SELECT * FROM rechnungen_templates WHERE owner_identifier = ? OR (is_shared = 1 AND job_name = ?) ORDER BY name ASC',
        { identifier, jobName }
    ) or {}

    for _, t in ipairs(dbTemplates) do
        local items = {}
        if t.line_items then
            items = type(t.line_items) == 'string' and json.decode(t.line_items) or t.line_items
        end
        templates[#templates + 1] = {
            id = t.id,
            name = t.name,
            title = t.title,
            items = items or {},
            notes = t.notes or '',
            is_shared = t.is_shared == 1,
            is_custom = true
        }
    end

    return templates
end

--- Benutzereinstellungen laden
---@param identifier string
---@return table
local function GetUserPrefs(identifier)
    local row = MySQL.single.await('SELECT * FROM rechnungen_user_prefs WHERE identifier = ?', { identifier })
    if not row then
        return { theme = 'dark', view_mode = 'table', account_mode = 'personal' }
    end
    return {
        theme = row.theme or 'dark',
        view_mode = row.view_mode or 'table',
        account_mode = row.account_mode or 'personal'
    }
end

--- Kontakte laden
---@param identifier string
---@return table
local function GetContacts(identifier)
    return MySQL.query.await(
        'SELECT id, contact_name, contact_identifier, created_at FROM rechnungen_contacts WHERE owner_identifier = ? ORDER BY contact_name ASC',
        { identifier }
    ) or {}
end

--- Baut Chart-Daten für die letzten N Tage
---@param invoices table
---@param days number
---@return table
local function BuildChartData(invoices, days)
    local labels = {}
    local values = {}

    for i = days - 1, 0, -1 do
        local ts = os.time() - (i * 86400)
        local day = os.date('%Y-%m-%d', ts)
        labels[#labels + 1] = os.date('%d.%m', ts)

        local dayTotal = 0
        for _, inv in ipairs(invoices) do
            local createdDay = string.sub(tostring(inv.created_at or ''), 1, 10)
            if createdDay == day then
                dayTotal = dayTotal + (tonumber(inv.gross_amount) or 0)
            end
        end
        values[#values + 1] = dayTotal
    end

    return { labels = labels, values = values }
end

--- Debug-Ausgabe nur wenn Config.Debug aktiv
local function DebugPrint(...)
    if Config.Debug then
        print('[esx_rechnungen:DEBUG]', ...)
    end
end

--- Prüft ob ein Spieler Admin-Rechte hat (serverseitig)
---@param source number
---@return boolean
local function IsPlayerAdmin(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return false end

    local group = xPlayer.getGroup()
    for _, adminGroup in ipairs(Config.AdminGroups) do
        if group == adminGroup then
            return true
        end
    end
    return false
end

--- Lädt alle globalen Einstellungen aus der Datenbank
local function LoadGlobalSettings()
    local result = MySQL.query.await('SELECT setting_key, setting_value FROM rechnungen_settings')
    GlobalSettings = {}

    if result then
        for _, row in ipairs(result) do
            GlobalSettings[row.setting_key] = row.setting_value
        end
    end

    -- Fallback auf Config-Defaults
    for key, value in pairs(Config.DefaultSettings) do
        if GlobalSettings[key] == nil then
            GlobalSettings[key] = tostring(value)
        end
    end

    DebugPrint('Globale Einstellungen geladen:', json.encode(GlobalSettings))
end

--- Lädt alle Job-Einstellungen aus der Datenbank
local function LoadJobSettings()
    local result = MySQL.query.await('SELECT * FROM rechnungen_job_settings')
    JobSettings = {}

    if result then
        for _, row in ipairs(result) do
            JobSettings[row.job_name] = row
        end
    end

    DebugPrint('Job-Einstellungen geladen:', #result or 0, 'Jobs')
end

--- Lädt alle Society-Informationen aus der Datenbank
local function LoadSocietyInfo()
    local result = MySQL.query.await('SELECT * FROM rechnungen_society_info')
    SocietyInfo = {}

    if result then
        for _, row in ipairs(result) do
            SocietyInfo[row.society_name] = row
        end
    end

    DebugPrint('Society-Informationen geladen:', #result or 0, 'Societies')
end

--- Speichert eine globale Einstellung in DB und Cache
---@param key string
---@param value string
local function SaveGlobalSetting(key, value)
    GlobalSettings[key] = tostring(value)
    MySQL.insert.await(
        'INSERT INTO rechnungen_settings (setting_key, setting_value) VALUES (?, ?) ON DUPLICATE KEY UPDATE setting_value = ?',
        { key, tostring(value), tostring(value) }
    )
end

--- Holt einen globalen Einstellungswert
---@param key string
---@param default any
---@return any
local function GetGlobalSetting(key, default)
    local val = GlobalSettings[key]
    if val == nil then return default end

    if val == 'true' then return true end
    if val == 'false' then return false end

    local num = tonumber(val)
    if num then return num end

    return val
end

--- Prüft ob Job-Einstellungen Rechnungen erlauben
---@param jobSettings table|nil
---@return boolean
local function CanJobIssueInvoices(jobSettings)
    if not jobSettings then return false end
    local v = jobSettings.can_issue
    return v == 1 or v == true or v == '1' or v == 'true'
end

--- Prüft ob ein Job auf der Blacklist steht
---@param jobName string
---@return boolean
local function IsJobBlacklisted(jobName)
    for _, name in ipairs(Config.Blacklist or {}) do
        if name == jobName then return true end
    end
    return false
end

--- Prüft ob ein Job per Config Rechnungen ausstellen darf (Fallback ohne DB-Eintrag)
---@param jobName string
---@return boolean
local function IsJobAllowedByConfig(jobName)
    if not jobName or jobName == '' or jobName == 'unemployed' then
        return false
    end

    if IsJobBlacklisted(jobName) then
        return false
    end

    local rule = Config.InvoiceJobs
    if rule == true then
        return true
    end
    if rule == false or rule == nil then
        return false
    end
    if type(rule) == 'table' then
        for _, name in ipairs(rule) do
            if name == jobName then
                return true
            end
        end
    end
    return false
end

--- Prüft Rang-Berechtigung zum Ausstellen
---@param xPlayer table
---@return boolean
---@return string|nil
local function HasGradePermission(xPlayer)
    local job = xPlayer.getJob()
    if IsJobBlacklisted(job.name) then
        return false, _U('job_blacklisted', job.label or job.name)
    end

    if Config.Permissions.boss_auto_manage and job.grade_name == 'boss' then
        return true
    end

    local minGrade = Config.Permissions.default_min_grade or 0
    local overrides = Config.Permissions.job_overrides and Config.Permissions.job_overrides[job.name]
    if overrides and overrides.min_grade_issue then
        minGrade = overrides.min_grade_issue
    end

    local jobSettings = JobSettings[job.name]
    if jobSettings and jobSettings.min_grade then
        minGrade = tonumber(jobSettings.min_grade) or minGrade
    end

    local grade = tonumber(job.grade) or 0
    if grade < minGrade then
        return false, _U('grade_too_low', grade, minGrade)
    end

    return true
end

--- Baut Standard-Job-Einstellungen aus der Config
---@param jobName string
---@return table
local function BuildDefaultJobSettings(jobName)
    local defaults = Config.DefaultJobPermissions or {}
    return {
        job_name = jobName,
        can_issue = defaults.can_issue ~= nil and defaults.can_issue or 1,
        can_issue_player = defaults.can_issue_player ~= nil and defaults.can_issue_player or 1,
        can_issue_society = defaults.can_issue_society ~= nil and defaults.can_issue_society or 0,
        max_amount = defaults.max_amount or 10000,
        require_proximity = defaults.require_proximity ~= nil and defaults.require_proximity or 1,
        max_distance = defaults.max_distance or 5.0,
        payment_bank = defaults.payment_bank ~= nil and defaults.payment_bank or 1,
        payment_cash = defaults.payment_cash ~= nil and defaults.payment_cash or 1,
        money_destination = defaults.money_destination or 'society',
        society_percent = defaults.society_percent or 70,
        employee_percent = defaults.employee_percent or 30,
        tax_rate = defaults.tax_rate or 19.0,
        _from_config = true
    }
end

--- Holt Job-Einstellungen (DB zuerst, sonst Config-Fallback)
---@param jobName string
---@return table|nil
local function GetJobSettings(jobName)
    if JobSettings[jobName] then
        return JobSettings[jobName]
    end

    if IsJobAllowedByConfig(jobName) then
        return BuildDefaultJobSettings(jobName)
    end

    return nil
end

--- Berechnet Steuerbeträge
---@param netAmount number
---@param taxRate number
---@return number net, number tax, number gross
local function CalculateTax(netAmount, taxRate)
    local taxEnabled = GetGlobalSetting('tax_enabled', true)
    if not taxEnabled then
        return netAmount, 0.0, netAmount
    end

    local taxAmount = math.floor(netAmount * (taxRate / 100) * 100) / 100
    local grossAmount = math.floor((netAmount + taxAmount) * 100) / 100
    return netAmount, taxAmount, grossAmount
end

--- Generiert automatische Rechnungsnummer: RE-2026-000001
---@param prefix string|nil
---@return string
local function GenerateInvoiceNumber(prefix)
    prefix = prefix or GetGlobalSetting('invoice_prefix', 'RE')
    local year = os.date('%Y')

    MySQL.insert.await(
        'INSERT INTO rechnungen_counters (year, last_number) VALUES (?, 1) ON DUPLICATE KEY UPDATE last_number = last_number + 1',
        { tonumber(year) }
    )

    local result = MySQL.scalar.await('SELECT last_number FROM rechnungen_counters WHERE year = ?', { tonumber(year) })
    local number = result or 1

    return string.format('%s-%s-%06d', prefix, year, number)
end

--- Prüft ob eine Society existiert (über esx_addonaccount)
---@param societyName string
---@return boolean
local function SocietyExists(societyName)
    local accountName = 'society_' .. societyName
    local result = MySQL.scalar.await('SELECT 1 FROM addon_account WHERE name = ? LIMIT 1', { accountName })
    return result ~= nil
end

--- Gibt Geld an Society weiter
---@param societyName string
---@param amount number
local function AddMoneyToSociety(societyName, amount)
    local accountName = 'society_' .. societyName
    TriggerEvent('esx_addonaccount:getSharedAccount', accountName, function(account)
        if account then
            account.addMoney(amount)
        else
            DebugPrint('Society-Konto nicht gefunden:', accountName)
        end
    end)
end

--- Sendet Discord-Webhook
---@param title string
---@param description string
---@param color number
local function SendDiscordLog(title, description, color)
    if not GetGlobalSetting('discord_enabled', false) then return end

    local webhook = GetGlobalSetting('discord_webhook', '')
    if webhook == '' or webhook == nil then return end

    local embed = {
        {
            ['title'] = title,
            ['description'] = description,
            ['color'] = color or 3447003,
            ['footer'] = {
                ['text'] = 'ESX Rechnungssystem | ' .. os.date('%d.%m.%Y %H:%M:%S')
            }
        }
    }

    PerformHttpRequest(webhook, function() end, 'POST', json.encode({
        username = 'Rechnungssystem',
        embeds = embed
    }), { ['Content-Type'] = 'application/json' })
end

--- Holt Spielerkoordinaten serverseitig
---@param source number
---@return vector3|nil
local function GetPlayerCoords(source)
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return nil end
    return GetEntityCoords(ped)
end

--- Berechnet Distanz zwischen zwei Spielern
---@param source1 number
---@param source2 number
---@return number
local function GetDistanceBetweenPlayers(source1, source2)
    local coords1 = GetPlayerCoords(source1)
    local coords2 = GetPlayerCoords(source2)
    if not coords1 or not coords2 then return 9999.0 end
    return #(coords1 - coords2)
end

--- Findet Online-Spieler anhand Identifier
---@param identifier string
---@return number|nil source
local function GetOnlinePlayerByIdentifier(identifier)
    local players = ESX.GetExtendedPlayers()
    for _, xPlayer in pairs(players) do
        if xPlayer.identifier == identifier then
            return xPlayer.source
        end
    end
    return nil
end

--- Benachrichtigung an Spieler senden
---@param source number
---@param msg string
---@param ntype string
local function Notify(source, msg, ntype)
    TriggerClientEvent('esx_rechnungen:notify', source, msg, ntype or 'info')
end

--- Aktualisiert überfällige Rechnungen
local function UpdateOverdueInvoices()
    MySQL.update.await(
        "UPDATE rechnungen_invoices SET payment_status = 'overdue' WHERE payment_status = 'open' AND due_date < CURDATE()"
    )
end

--- Erinnerungen vor Fälligkeit senden
local function SendDueReminders()
    local daysList = Config.Overdue and Config.Overdue.reminder_days_before
    if not daysList then return end

    for _, days in ipairs(daysList) do
        local targetDate = os.date('%Y-%m-%d', os.time() + (days * 86400))
        local invoices = MySQL.query.await(
            "SELECT * FROM rechnungen_invoices WHERE payment_status = 'open' AND due_date = ?",
            { targetDate }
        )

        for _, inv in ipairs(invoices or {}) do
            local targetSource = GetOnlinePlayerByIdentifier(inv.recipient_identifier)
            if targetSource then
                Notify(targetSource, _U('reminder_before_due', inv.invoice_number, days, inv.gross_amount), 'warning')
            end
        end
    end
end

-- ============================================================
-- Serverstart: Datenbank + Einstellungen laden
-- ============================================================

MySQL.ready(function()
    CreateThread(function()
        local dbOk = InstallDatabase()
        if not dbOk then
            ConsoleLog('error', 'Script läuft weiter, aber einige Datenbank-Tabellen fehlen möglicherweise!')
        end

        RunMigrations()

        LoadGlobalSettings()
        LoadJobSettings()
        LoadSocietyInfo()
        UpdateOverdueInvoices()
        SendDueReminders()

        ConsoleLog('success', 'Rechnungssystem erfolgreich geladen und einsatzbereit.')
    end)
end)

-- Periodisch überfällige Rechnungen prüfen
CreateThread(function()
    local interval = (Config.Overdue and Config.Overdue.check_interval_minutes or 30) * 60000
    while true do
        Wait(interval)
        UpdateOverdueInvoices()
        SendDueReminders()
    end
end)

-- ============================================================
-- Spieler eingeloggt: Offene Rechnungen anzeigen
-- ============================================================

AddEventHandler('esx:playerLoaded', function(playerId, xPlayer)
    local source = playerId
    if not GetGlobalSetting('show_unpaid_on_login', true) then return end

    CreateThread(function()
        Wait(5000)
        local identifier = xPlayer.identifier
        local unpaid = MySQL.scalar.await(
            "SELECT COUNT(*) FROM rechnungen_invoices WHERE recipient_identifier = ? AND payment_status IN ('open', 'overdue')",
            { identifier }
        )

        if unpaid and unpaid > 0 then
            Notify(source, ('Du hast %d unbezahlte Rechnung(en). Nutze /%s zum Anzeigen.'):format(unpaid, Config.PlayerCommand), 'warning')
        end
    end)
end)

-- ============================================================
-- Admin-Berechtigung prüfen
-- ============================================================

ESX.RegisterServerCallback('esx_rechnungen:isAdmin', function(source, cb)
    cb(IsPlayerAdmin(source))
end)

-- ============================================================
-- Globale Einstellungen abrufen (Admin)
-- ============================================================

ESX.RegisterServerCallback('esx_rechnungen:getGlobalSettings', function(source, cb)
    if not IsPlayerAdmin(source) then
        cb(nil)
        return
    end
    cb(GlobalSettings)
end)

-- ============================================================
-- Globale Einstellungen speichern (Admin)
-- ============================================================

RegisterNetEvent('esx_rechnungen:saveGlobalSettings', function(settings)
    local source = source
    if not IsPlayerAdmin(source) then
        Notify(source, 'Keine Berechtigung für das Adminpanel.', 'error')
        return
    end

    if type(settings) ~= 'table' then return end

    for key, value in pairs(settings) do
        SaveGlobalSetting(key, value)
    end

    LoadGlobalSettings()
    Notify(source, 'Globale Einstellungen gespeichert.', 'success')

    SendDiscordLog('⚙️ Einstellungen geändert', ('Admin **%s** hat globale Einstellungen aktualisiert.'):format(GetPlayerName(source)), 16776960)
end)

-- ============================================================
-- Job-Einstellungen abrufen (Admin)
-- ============================================================

ESX.RegisterServerCallback('esx_rechnungen:getJobSettings', function(source, cb)
    if not IsPlayerAdmin(source) then
        cb(nil)
        return
    end

    local jobs = MySQL.query.await('SELECT name, label FROM jobs ORDER BY label ASC')
    cb({
        jobs = jobs or {},
        settings = JobSettings
    })
end)

-- ============================================================
-- Job-Einstellungen speichern (Admin)
-- ============================================================

RegisterNetEvent('esx_rechnungen:saveJobSettings', function(jobData)
    local source = source
    if not IsPlayerAdmin(source) then
        Notify(source, 'Keine Berechtigung.', 'error')
        return
    end

    if not jobData or not jobData.job_name then return end

    MySQL.insert.await([[
        INSERT INTO rechnungen_job_settings
            (job_name, can_issue, can_issue_player, can_issue_society, max_amount,
             require_proximity, max_distance, payment_bank, payment_cash,
             money_destination, society_percent, employee_percent, tax_rate)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
            can_issue = VALUES(can_issue),
            can_issue_player = VALUES(can_issue_player),
            can_issue_society = VALUES(can_issue_society),
            max_amount = VALUES(max_amount),
            require_proximity = VALUES(require_proximity),
            max_distance = VALUES(max_distance),
            payment_bank = VALUES(payment_bank),
            payment_cash = VALUES(payment_cash),
            money_destination = VALUES(money_destination),
            society_percent = VALUES(society_percent),
            employee_percent = VALUES(employee_percent),
            tax_rate = VALUES(tax_rate)
    ]], {
        jobData.job_name,
        jobData.can_issue and 1 or 0,
        jobData.can_issue_player and 1 or 0,
        jobData.can_issue_society and 1 or 0,
        tonumber(jobData.max_amount) or 10000,
        jobData.require_proximity and 1 or 0,
        tonumber(jobData.max_distance) or 5.0,
        jobData.payment_bank and 1 or 0,
        jobData.payment_cash and 1 or 0,
        jobData.money_destination or 'society',
        tonumber(jobData.society_percent) or 70,
        tonumber(jobData.employee_percent) or 30,
        tonumber(jobData.tax_rate) or 19.0
    })

    LoadJobSettings()
    Notify(source, ('Job-Einstellungen für "%s" gespeichert.'):format(jobData.job_name), 'success')
end)

-- ============================================================
-- Job-Einstellungen löschen (Admin)
-- ============================================================

RegisterNetEvent('esx_rechnungen:deleteJobSettings', function(jobName)
    local source = source
    if not IsPlayerAdmin(source) then return end

    MySQL.update.await('DELETE FROM rechnungen_job_settings WHERE job_name = ?', { jobName })
    JobSettings[jobName] = nil
    Notify(source, ('Job-Einstellungen für "%s" gelöscht.'):format(jobName), 'success')
end)

-- ============================================================
-- Society-Informationen abrufen (Admin)
-- ============================================================

ESX.RegisterServerCallback('esx_rechnungen:getSocietyInfo', function(source, cb)
    if not IsPlayerAdmin(source) then
        cb(nil)
        return
    end
    cb(SocietyInfo)
end)

-- ============================================================
-- Society-Informationen speichern (Admin)
-- ============================================================

RegisterNetEvent('esx_rechnungen:saveSocietyInfo', function(data)
    local source = source
    if not IsPlayerAdmin(source) then
        Notify(source, 'Keine Berechtigung.', 'error')
        return
    end

    if not data or not data.society_name then return end

    MySQL.insert.await([[
        INSERT INTO rechnungen_society_info
            (society_name, company_name, company_address, tax_id, vat_id, invoice_prefix)
        VALUES (?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
            company_name = VALUES(company_name),
            company_address = VALUES(company_address),
            tax_id = VALUES(tax_id),
            vat_id = VALUES(vat_id),
            invoice_prefix = VALUES(invoice_prefix)
    ]], {
        data.society_name,
        data.company_name or '',
        data.company_address or '',
        data.tax_id or '',
        data.vat_id or '',
        data.invoice_prefix or 'RE'
    })

    LoadSocietyInfo()
    Notify(source, ('Firmendaten für "%s" gespeichert.'):format(data.society_name), 'success')
end)

-- ============================================================
-- Society-Informationen löschen (Admin)
-- ============================================================

RegisterNetEvent('esx_rechnungen:deleteSocietyInfo', function(societyName)
    local source = source
    if not IsPlayerAdmin(source) then return end

    MySQL.update.await('DELETE FROM rechnungen_society_info WHERE society_name = ?', { societyName })
    SocietyInfo[societyName] = nil
    Notify(source, ('Firmendaten für "%s" gelöscht.'):format(societyName), 'success')
end)

-- ============================================================
-- Verfügbare Jobs für Rechnungserstellung abrufen
-- ============================================================

ESX.RegisterServerCallback('esx_rechnungen:canCreateInvoice', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then
        cb(false, 'Spieler nicht gefunden.')
        return
    end

    local job = xPlayer.getJob()
    local jobSettings = GetJobSettings(job.name)

    if not CanJobIssueInvoices(jobSettings) then
        local hint = _U('cannot_issue', job.label or job.name)
        if Config.InvoiceJobs == false then
            hint = hint .. _U('cannot_issue_admin')
        else
            hint = hint .. _U('cannot_issue_config')
        end
        cb(false, hint)
        return
    end

    local hasGrade, gradeMsg = HasGradePermission(xPlayer)
    if not hasGrade then
        cb(false, gradeMsg)
        return
    end

    cb(true, {
        job = job,
        settings = jobSettings,
        societyInfo = SocietyInfo[job.name] or nil
    })
end)

-- ============================================================
-- Nahe Spieler für Rechnungserstellung abrufen
-- ============================================================

ESX.RegisterServerCallback('esx_rechnungen:getNearbyPlayers', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then
        cb({})
        return
    end

    local jobSettings = GetJobSettings(xPlayer.getJob().name)
    if not jobSettings then
        cb({})
        return
    end

    local maxDist = jobSettings.max_distance or GetGlobalSetting('default_max_distance', 5.0)
    local nearby = {}
    local players = ESX.GetExtendedPlayers()

    for _, target in pairs(players) do
        if target.source ~= source then
            local dist = GetDistanceBetweenPlayers(source, target.source)
            if not jobSettings.require_proximity or jobSettings.require_proximity == 0 or dist <= maxDist then
                table.insert(nearby, {
                    source = target.source,
                    name = target.getName(),
                    identifier = target.identifier,
                    distance = math.floor(dist * 10) / 10
                })
            end
        end
    end

    cb(nearby)
end)

-- ============================================================
-- Societies für Rechnungserstellung abrufen
-- ============================================================

ESX.RegisterServerCallback('esx_rechnungen:getSocieties', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then
        cb({})
        return
    end

    local jobSettings = GetJobSettings(xPlayer.getJob().name)
    if not jobSettings or not jobSettings.can_issue_society or jobSettings.can_issue_society == 0 then
        cb({})
        return
    end

    local societies = MySQL.query.await('SELECT name, label FROM jobs WHERE name != ? ORDER BY label ASC', { 'unemployed' })
    cb(societies or {})
end)

-- ============================================================
-- Rechnung erstellen (serverseitige Validierung)
-- ============================================================

RegisterNetEvent('esx_rechnungen:createInvoice', function(data)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return end

    -- Validierung: Job-Berechtigung
    local job = xPlayer.getJob()
    local jobSettings = GetJobSettings(job.name)

    if not CanJobIssueInvoices(jobSettings) then
        Notify(source, _U('cannot_issue', job.label or job.name), 'error')
        return
    end

    local hasGrade, gradeMsg = HasGradePermission(xPlayer)
    if not hasGrade then
        Notify(source, gradeMsg, 'error')
        return
    end

    -- Validierung: Empfängertyp
    local recipientType = data.recipient_type or 'player'
    if recipientType == 'player' and (not jobSettings.can_issue_player or jobSettings.can_issue_player == 0) then
        Notify(source, 'Dein Job darf keine Rechnungen an Spieler ausstellen.', 'error')
        return
    end
    if recipientType == 'society' and (not jobSettings.can_issue_society or jobSettings.can_issue_society == 0) then
        Notify(source, 'Dein Job darf keine Rechnungen an Firmen ausstellen.', 'error')
        return
    end

    -- Validierung: Betrag & Positionen
    local netAmount = nil
    local lineItems = data.line_items
    local reason = tostring(data.reason or ''):sub(1, 500)

    if type(lineItems) == 'table' and #lineItems > 0 then
        local maxItems = (Config.Limits and Config.Limits.max_items_per_invoice) or 20
        if #lineItems > maxItems then
            Notify(source, _U('max_items', maxItems), 'error')
            return
        end

        netAmount = 0
        local reasons = {}

        for _, item in ipairs(lineItems) do
            local units = tonumber(item.units) or 1
            local price = tonumber(item.price) or 0
            local desc = tostring(item.description or 'Position'):sub(1, 200)

            if units < 1 or price < 0 then
                Notify(source, 'Ungültige Positionsdaten.', 'error')
                return
            end

            netAmount = netAmount + (units * price)
            table.insert(reasons, desc .. (units > 1 and (' (' .. units .. 'x)') or ''))
        end

        if reason == '' then
            reason = table.concat(reasons, ', '):sub(1, 500)
        end
    else
        netAmount = tonumber(data.net_amount)
    end

    if not netAmount or netAmount <= 0 then
        Notify(source, 'Ungültiger Rechnungsbetrag.', 'error')
        return
    end

    -- Validierung: Maximalbetrag
    local maxAmount = tonumber(jobSettings.max_amount) or (Config.Limits and Config.Limits.max_amount) or 10000
    if netAmount > maxAmount then
        Notify(source, _U('max_amount', maxAmount), 'error')
        return
    end

    -- Validierung: Rechnungsgrund
    if reason == '' then
        Notify(source, 'Bitte gib einen Rechnungsgrund an.', 'error')
        return
    end

    local maxNote = (Config.Limits and Config.Limits.max_note_length) or 2000
    local notes = tostring(data.notes or ''):sub(1, maxNote)
    if #tostring(data.notes or '') > maxNote then
        Notify(source, _U('note_too_long', maxNote), 'error')
        return
    end

    local signature = data.signature
    if Config.Signature and Config.Signature.required and (not signature or signature == '') then
        Notify(source, _U('signature_required'), 'error')
        return
    end
    if type(signature) == 'string' and #signature > 500000 then
        signature = signature:sub(1, 500000)
    end

    -- Validierung: Empfänger
    local recipientIdentifier = nil
    local recipientName = nil

    if recipientType == 'player' then
        local targetId = tonumber(data.target_id)
        local targetIdentifier = tostring(data.target_identifier or ''):gsub('^%s+', ''):gsub('%s+$', '')

        if targetIdentifier ~= '' then
            local xTarget = nil
            for _, p in pairs(ESX.GetExtendedPlayers()) do
                if p.identifier == targetIdentifier then
                    xTarget = p
                    break
                end
            end

            if xTarget and jobSettings.require_proximity and jobSettings.require_proximity == 1 then
                local dist = GetDistanceBetweenPlayers(source, xTarget.source)
                local maxDist = tonumber(jobSettings.max_distance) or 5.0
                if dist > maxDist then
                    Notify(source, ('Der Empfänger ist zu weit entfernt (max. %.1fm).'):format(maxDist), 'error')
                    return
                end
            end

            recipientIdentifier = targetIdentifier
            recipientName = xTarget and xTarget.getName() or GetCharacterName(targetIdentifier)
        elseif targetId then
            local xTarget = ESX.GetPlayerFromId(targetId)
            if not xTarget then
                Notify(source, 'Empfänger nicht gefunden oder nicht online.', 'error')
                return
            end

            if jobSettings.require_proximity and jobSettings.require_proximity == 1 then
                local dist = GetDistanceBetweenPlayers(source, targetId)
                local maxDist = tonumber(jobSettings.max_distance) or 5.0
                if dist > maxDist then
                    Notify(source, ('Der Empfänger ist zu weit entfernt (max. %.1fm).'):format(maxDist), 'error')
                    return
                end
            end

            recipientIdentifier = xTarget.identifier
            recipientName = xTarget.getName()
        else
            Notify(source, 'Ungültiger Empfänger.', 'error')
            return
        end

    elseif recipientType == 'society' then
        local societyName = tostring(data.society_name or '')
        if societyName == '' then
            Notify(source, 'Keine Firma ausgewählt.', 'error')
            return
        end

        -- Validierung: Society existiert
        if not SocietyExists(societyName) then
            Notify(source, 'Die ausgewählte Firma existiert nicht.', 'error')
            return
        end

        recipientIdentifier = 'society:' .. societyName
        local societyData = SocietyInfo[societyName]
        recipientName = societyData and societyData.company_name or societyName
    else
        Notify(source, 'Ungültiger Empfängertyp.', 'error')
        return
    end

    -- Steuerberechnung
    local taxRate = tonumber(data.tax_rate) or tonumber(jobSettings.tax_rate) or GetGlobalSetting('default_tax_rate', 19.0)
    local net, taxAmount, grossAmount = CalculateTax(netAmount, taxRate)

    -- Rechnungsnummer generieren
    local societyData = SocietyInfo[job.name]
    local prefix = societyData and societyData.invoice_prefix or GetGlobalSetting('invoice_prefix', 'RE')
    local invoiceNumber = GenerateInvoiceNumber(prefix)

    -- Fälligkeitsdatum (Preset oder benutzerdefiniert)
    local durationDays
    local dueDate
    local customDue = tostring(data.due_date or '')
    if customDue:match('^%d%d%d%d%-%d%d%-%d%d$') then
        dueDate = customDue
        local y, m, dd = customDue:match('^(%d+)%-(%d+)%-(%d+)$')
        local dueTime = os.time({ year = tonumber(y), month = tonumber(m), day = tonumber(dd), hour = 12 })
        durationDays = math.max(1, math.floor((dueTime - os.time()) / 86400) + 1)
    else
        durationDays = tonumber(data.duration_days) or GetGlobalSetting('payment_deadline_days', 14)
        durationDays = math.max(1, math.min(durationDays, 365))
        dueDate = os.date('%Y-%m-%d', os.time() + (durationDays * 86400))
    end

    -- Aussteller
    local issuerMode = data.issuer_mode == 'company' and 'company' or 'personal'
    local issuerName = xPlayer.getName()
    if issuerMode == 'company' then
        issuerName = (societyData and societyData.company_name) or job.label
    end

    local lineItemsJson = nil
    if type(lineItems) == 'table' and #lineItems > 0 then
        lineItemsJson = json.encode(lineItems)
    end

    -- In Datenbank speichern
    local issuerSociety = job.name

    MySQL.insert.await([[
        INSERT INTO rechnungen_invoices
            (invoice_number, issuer_identifier, issuer_name, issuer_job, issuer_society,
             recipient_type, recipient_identifier, recipient_name, reason,
             net_amount, tax_rate, tax_amount, gross_amount, due_date, reminder_fee,
             notes, line_items, signature, duration_days, issuer_mode)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        invoiceNumber,
        xPlayer.identifier,
        issuerName,
        job.name,
        issuerSociety,
        recipientType,
        recipientIdentifier,
        recipientName,
        reason,
        net,
        taxRate,
        taxAmount,
        grossAmount,
        dueDate,
        GetGlobalSetting('reminder_fee', 25.0),
        notes ~= '' and notes or nil,
        lineItemsJson,
        signature,
        durationDays,
        issuerMode
    })

    Notify(source, ('Rechnung %s erfolgreich erstellt.'):format(invoiceNumber), 'success')

    -- Empfänger benachrichtigen
    if recipientType == 'player' then
        local targetSource = GetOnlinePlayerByIdentifier(recipientIdentifier)
        if targetSource then
            Notify(targetSource, ('Du hast eine neue Rechnung erhalten: %s (%s€)'):format(invoiceNumber, grossAmount), 'info')
        end
    end

    SendDiscordLog('📄 Neue Rechnung', ([[
**Rechnungsnummer:** %s
**Aussteller:** %s (%s)
**Empfänger:** %s
**Grund:** %s
**Brutto:** %s€
    ]]):format(invoiceNumber, xPlayer.getName(), job.label, recipientName, reason, grossAmount), 3066993)
end)

-- ============================================================
-- Eigene Rechnungen abrufen (Spieler)
-- ============================================================

ESX.RegisterServerCallback('esx_rechnungen:getMyInvoices', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then
        cb({})
        return
    end

    local job = xPlayer.getJob()
    local invoices = MySQL.query.await(
        [[SELECT * FROM rechnungen_invoices
          WHERE recipient_identifier = ?
             OR recipient_identifier = ?
          ORDER BY created_at DESC LIMIT 100]],
        { xPlayer.identifier, 'society:' .. job.name }
    )

    -- Society-Info für Aussteller anreichern
    if invoices then
        for _, inv in ipairs(invoices) do
            local socInfo = SocietyInfo[inv.issuer_society]
            if socInfo then
                inv.company_name = socInfo.company_name
                inv.company_address = socInfo.company_address
                inv.tax_id = socInfo.tax_id
                inv.vat_id = socInfo.vat_id
            end
        end
    end

    cb(invoices or {})
end)

-- ============================================================
-- Vom Spieler erstellte Rechnungen
-- ============================================================

ESX.RegisterServerCallback('esx_rechnungen:getCreatedInvoices', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then cb({}) return end

    local invoices = MySQL.query.await(
        'SELECT * FROM rechnungen_invoices WHERE issuer_identifier = ? ORDER BY created_at DESC LIMIT 100',
        { xPlayer.identifier }
    )

    if invoices then
        for _, inv in ipairs(invoices) do
            local socInfo = SocietyInfo[inv.issuer_society]
            if socInfo then
                inv.company_name = socInfo.company_name
                inv.company_address = socInfo.company_address
                inv.tax_id = socInfo.tax_id
                inv.vat_id = socInfo.vat_id
            end
        end
    end

    cb(invoices or {})
end)

-- ============================================================
-- Dashboard-Daten (Übersicht, Stats, Berechtigungen)
-- ============================================================

ESX.RegisterServerCallback('esx_rechnungen:getDashboardData', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then cb(nil) return end

    local job = xPlayer.getJob()
    local identifier = xPlayer.identifier

    local received = MySQL.query.await(
        [[SELECT * FROM rechnungen_invoices
          WHERE recipient_identifier = ? OR recipient_identifier = ?
          ORDER BY created_at DESC LIMIT 100]],
        { identifier, 'society:' .. job.name }
    ) or {}

    local created = MySQL.query.await(
        'SELECT * FROM rechnungen_invoices WHERE issuer_identifier = ? ORDER BY created_at DESC LIMIT 100',
        { identifier }
    ) or {}

    local all = {}
    local seen = {}
    for _, inv in ipairs(received) do
        if not seen[inv.id] then all[#all + 1] = inv seen[inv.id] = true end
    end
    for _, inv in ipairs(created) do
        if not seen[inv.id] then all[#all + 1] = inv seen[inv.id] = true end
    end

    local stats = {
        total = #all,
        open = 0,
        open_amount = 0,
        today_count = 0,
        today_amount = 0,
        paid = 0,
        overdue = 0
    }

    local today = os.date('%Y-%m-%d')
    for _, inv in ipairs(all) do
        local gross = tonumber(inv.gross_amount) or 0
        local createdDay = string.sub(tostring(inv.created_at or ''), 1, 10)
        if createdDay == today then
            stats.today_count = stats.today_count + 1
            stats.today_amount = stats.today_amount + gross
        end
        if inv.payment_status == 'open' then
            stats.open = stats.open + 1
            stats.open_amount = stats.open_amount + gross
        elseif inv.payment_status == 'overdue' then
            stats.overdue = stats.overdue + 1
            stats.open = stats.open + 1
            stats.open_amount = stats.open_amount + gross + (tonumber(inv.reminder_fee) or 0)
        elseif inv.payment_status == 'paid' then
            stats.paid = stats.paid + 1
        end
    end

    local totalAmount = 0
    for _, inv in ipairs(all) do
        totalAmount = totalAmount + (tonumber(inv.gross_amount) or 0)
    end
    stats.total_amount = totalAmount
    stats.avg_invoice = #all > 0 and math.floor(totalAmount / #all) or 0

    stats.chart_created = BuildChartData(created, 14)
    stats.chart_received = BuildChartData(received, 14)
    stats.chart = stats.chart_created

    local chartSum = 0
    for _, v in ipairs(stats.chart_created.values) do
        chartSum = chartSum + v
    end
    stats.avg_day = math.floor(chartSum / 14)

    local recentPayments = {}
    for _, inv in ipairs(all) do
        if inv.payment_status == 'paid' or inv.payment_status == 'cancelled' or inv.payment_status == 'rejected' then
            recentPayments[#recentPayments + 1] = inv
        end
    end
    table.sort(recentPayments, function(a, b)
        local ta = tostring(a.paid_at or a.updated_at or a.created_at or '')
        local tb = tostring(b.paid_at or b.updated_at or b.created_at or '')
        return ta > tb
    end)

    local recent = {}
    for i = 1, math.min(6, #recentPayments) do
        local inv = recentPayments[i]
        recent[#recent + 1] = {
            invoice_number = inv.invoice_number,
            payer_name = inv.recipient_name,
            amount = inv.gross_amount,
            paid_at = inv.paid_at or inv.updated_at,
            created_at = inv.created_at,
            status = inv.payment_status == 'cancelled' and 'cancelled' or (inv.payment_status == 'rejected' and 'rejected' or 'paid')
        }
    end
    stats.recent_payments = recent

    for _, list in ipairs({ received, created }) do
        for _, inv in ipairs(list) do
            local socInfo = SocietyInfo[inv.issuer_society]
            if socInfo then
                inv.company_name = socInfo.company_name
                inv.company_address = socInfo.company_address
                inv.tax_id = socInfo.tax_id
                inv.vat_id = socInfo.vat_id
            end
        end
    end

    local isAdmin = IsPlayerAdmin(source)
    local canCreate = false
    local createData = nil
    local jobSettings = GetJobSettings(job.name)
    local hasGrade = HasGradePermission(xPlayer)
    if CanJobIssueInvoices(jobSettings) and hasGrade then
        canCreate = true
        createData = {
            job = job,
            settings = jobSettings,
            societyInfo = SocietyInfo[job.name],
            templates = GetTemplatesForPlayer(identifier, job.name)
        }
    end

    local hasBusinessAccount = job.name ~= 'unemployed' and job.name ~= nil

    cb({
        playerName = xPlayer.getName(),
        playerIdentifier = identifier,
        jobName = job.name,
        jobLabel = job.label,
        hasBusinessAccount = hasBusinessAccount,
        isAdmin = isAdmin,
        canCreate = canCreate,
        createData = createData,
        received = received,
        created = created,
        contacts = GetContacts(identifier),
        userPrefs = GetUserPrefs(identifier),
        stats = stats,
        ui = Config.UI,
        durations = Config.Durations,
        limits = Config.Limits,
        locale = Locales[Config.Locale] or Locales['de'],
        signature_required = Config.Signature and Config.Signature.required or true,
        rejection_enabled = GetGlobalSetting('rejection_enabled', true)
    })
end)

-- ============================================================
-- Alle Rechnungen abrufen (Admin)
-- ============================================================

ESX.RegisterServerCallback('esx_rechnungen:getAllInvoices', function(source, cb)
    if not IsPlayerAdmin(source) or not GetGlobalSetting('admin_can_view', true) then
        cb(nil)
        return
    end

    local invoices = MySQL.query.await('SELECT * FROM rechnungen_invoices ORDER BY created_at DESC LIMIT 200')

    if invoices then
        for _, inv in ipairs(invoices) do
            local socInfo = SocietyInfo[inv.issuer_society]
            if socInfo then
                inv.company_name = socInfo.company_name
                inv.company_address = socInfo.company_address
                inv.tax_id = socInfo.tax_id
                inv.vat_id = socInfo.vat_id
            end
        end
    end

    cb(invoices or {})
end)

-- ============================================================
-- Rechnung bezahlen (serverseitige Validierung)
-- ============================================================

---@param source number
---@param xPlayer table
---@param invoice table
---@param paymentMethod string
---@return boolean success
---@return string|nil message
local function TryPayInvoice(source, xPlayer, invoice, paymentMethod)
    if invoice.recipient_type == 'player' then
        if invoice.recipient_identifier ~= xPlayer.identifier then
            return false, 'Diese Rechnung gehört nicht dir.'
        end
    elseif invoice.recipient_type == 'society' then
        local societyName = invoice.recipient_identifier:gsub('^society:', '')
        if xPlayer.getJob().name ~= societyName then
            return false, 'Diese Firmenrechnung gehört nicht zu deiner Firma.'
        end
    end

    if invoice.payment_status ~= 'open' and invoice.payment_status ~= 'overdue' then
        return false, 'Diese Rechnung kann nicht mehr bezahlt werden.'
    end

    local jobSettings = GetJobSettings(invoice.issuer_job) or {
        payment_bank = 1, payment_cash = 1, money_destination = 'society',
        society_percent = 70, employee_percent = 30
    }

    paymentMethod = paymentMethod or 'bank'
    if paymentMethod == 'bank' and (not jobSettings.payment_bank or jobSettings.payment_bank == 0) then
        return false, 'Bankzahlung ist für diese Rechnung nicht erlaubt.'
    end
    if paymentMethod == 'cash' and (not jobSettings.payment_cash or jobSettings.payment_cash == 0) then
        return false, 'Barzahlung ist für diese Rechnung nicht erlaubt.'
    end

    local totalAmount = tonumber(invoice.gross_amount)
    if invoice.payment_status == 'overdue' then
        totalAmount = totalAmount + tonumber(invoice.reminder_fee or 0)
    end

    if invoice.recipient_type == 'society' then
        local societyName = invoice.recipient_identifier:gsub('^society:', '')
        local accountName = 'society_' .. societyName
        local societyAccount = nil
        local fetched = false

        TriggerEvent('esx_addonaccount:getSharedAccount', accountName, function(account)
            societyAccount = account
            fetched = true
        end)

        local timeout = 50
        while not fetched and timeout > 0 do
            Wait(10)
            timeout = timeout - 1
        end

        if not societyAccount or societyAccount.money < totalAmount then
            return false, 'Nicht genug Geld auf dem Firmenkonto.'
        end

        societyAccount.removeMoney(totalAmount)
    elseif paymentMethod == 'bank' then
        if xPlayer.getAccount('bank').money < totalAmount then
            return false, 'Nicht genug Geld auf dem Bankkonto.'
        end
        xPlayer.removeAccountMoney('bank', totalAmount, 'Rechnung ' .. invoice.invoice_number)
    else
        if xPlayer.getMoney() < totalAmount then
            return false, 'Nicht genug Bargeld.'
        end
        xPlayer.removeMoney(totalAmount, 'Rechnung ' .. invoice.invoice_number)
    end

    local destination = jobSettings.money_destination or 'society'
    local societyPercent = tonumber(jobSettings.society_percent) or 70

    if destination == 'society' then
        AddMoneyToSociety(invoice.issuer_job, totalAmount)
    elseif destination == 'employee' then
        local issuerSource = GetOnlinePlayerByIdentifier(invoice.issuer_identifier)
        if issuerSource then
            local xIssuer = ESX.GetPlayerFromId(issuerSource)
            if xIssuer then
                if paymentMethod == 'bank' then
                    xIssuer.addAccountMoney('bank', totalAmount)
                else
                    xIssuer.addMoney(totalAmount)
                end
            end
        else
            AddMoneyToSociety(invoice.issuer_job, totalAmount)
        end
    elseif destination == 'split' then
        local societyAmount = math.floor(totalAmount * (societyPercent / 100))
        local employeeAmount = totalAmount - societyAmount
        AddMoneyToSociety(invoice.issuer_job, societyAmount)

        local issuerSource = GetOnlinePlayerByIdentifier(invoice.issuer_identifier)
        if issuerSource then
            local xIssuer = ESX.GetPlayerFromId(issuerSource)
            if xIssuer then
                if paymentMethod == 'bank' then
                    xIssuer.addAccountMoney('bank', employeeAmount)
                else
                    xIssuer.addMoney(employeeAmount)
                end
            end
        end
    end

    MySQL.update.await(
        "UPDATE rechnungen_invoices SET payment_status = 'paid', payment_method = ?, paid_at = NOW() WHERE id = ?",
        { paymentMethod, invoice.id }
    )

    SendDiscordLog('💰 Rechnung bezahlt', ([[
**Rechnungsnummer:** %s
**Bezahlt von:** %s
**Betrag:** %s€
**Methode:** %s
    ]]):format(invoice.invoice_number, xPlayer.getName(), totalAmount, paymentMethod == 'bank' and 'Bank' or 'Bargeld'), 5763719)

    return true, totalAmount
end

RegisterNetEvent('esx_rechnungen:payInvoice', function(invoiceId, paymentMethod)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return end

    invoiceId = tonumber(invoiceId)
    if not invoiceId then return end

    local invoice = MySQL.single.await('SELECT * FROM rechnungen_invoices WHERE id = ?', { invoiceId })
    if not invoice then
        Notify(source, 'Rechnung nicht gefunden.', 'error')
        return
    end

    local ok, result = TryPayInvoice(source, xPlayer, invoice, paymentMethod)
    if not ok then
        Notify(source, result or 'Zahlung fehlgeschlagen.', 'error')
        return
    end

    Notify(source, ('Rechnung %s erfolgreich bezahlt (%s€).'):format(invoice.invoice_number, result), 'success')
end)

-- ============================================================
-- Rechnung bearbeiten (Admin)
-- ============================================================

RegisterNetEvent('esx_rechnungen:editInvoice', function(invoiceId, data)
    local source = source
    if not IsPlayerAdmin(source) or not GetGlobalSetting('admin_can_edit', true) then
        Notify(source, 'Keine Berechtigung.', 'error')
        return
    end

    invoiceId = tonumber(invoiceId)
    if not invoiceId or not data then return end

    local netAmount = tonumber(data.net_amount)
    if not netAmount or netAmount <= 0 then
        Notify(source, 'Ungültiger Betrag.', 'error')
        return
    end

    local taxRate = tonumber(data.tax_rate) or 0
    local net, taxAmount, grossAmount = CalculateTax(netAmount, taxRate)
    local xPlayer = ESX.GetPlayerFromId(source)

    MySQL.update.await([[
        UPDATE rechnungen_invoices SET
            reason = ?, net_amount = ?, tax_rate = ?, tax_amount = ?, gross_amount = ?,
            payment_status = ?, edited_by = ?
        WHERE id = ?
    ]], {
        tostring(data.reason or ''):sub(1, 500),
        net,
        taxRate,
        taxAmount,
        grossAmount,
        data.payment_status or 'open',
        xPlayer and xPlayer.identifier or 'admin',
        invoiceId
    })

    Notify(source, 'Rechnung erfolgreich bearbeitet.', 'success')

    SendDiscordLog('✏️ Rechnung bearbeitet', ('Admin **%s** hat Rechnung ID %d bearbeitet.'):format(GetPlayerName(source), invoiceId), 16776960)
end)

-- ============================================================
-- Rechnung ablehnen (Empfänger)
-- ============================================================

RegisterNetEvent('esx_rechnungen:rejectInvoice', function(invoiceId, reason)
    local source = source
    if not GetGlobalSetting('rejection_enabled', true) then
        Notify(source, _U('no_permission'), 'error')
        return
    end

    invoiceId = tonumber(invoiceId)
    if not invoiceId then return end

    reason = tostring(reason or ''):sub(1, 500)
    if reason == '' then
        Notify(source, 'Bitte gib einen Ablehnungsgrund an.', 'error')
        return
    end

    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return end

    local invoice = MySQL.single.await('SELECT * FROM rechnungen_invoices WHERE id = ?', { invoiceId })
    if not invoice then
        Notify(source, 'Rechnung nicht gefunden.', 'error')
        return
    end

    local job = xPlayer.getJob()
    local isRecipient = invoice.recipient_identifier == xPlayer.identifier
        or invoice.recipient_identifier == ('society:' .. job.name)

    if not isRecipient then
        Notify(source, _U('no_permission'), 'error')
        return
    end

    if invoice.payment_status ~= 'open' and invoice.payment_status ~= 'overdue' then
        Notify(source, 'Diese Rechnung kann nicht mehr abgelehnt werden.', 'error')
        return
    end

    MySQL.update.await(
        "UPDATE rechnungen_invoices SET payment_status = 'rejected', cancelled_by = ?, cancelled_reason = ? WHERE id = ?",
        { xPlayer.identifier, reason, invoiceId }
    )

    Notify(source, _U('invoice_rejected', invoice.invoice_number), 'success')

    local issuerSource = GetOnlinePlayerByIdentifier(invoice.issuer_identifier)
    if issuerSource then
        Notify(issuerSource, _U('invoice_rejected_notify', invoice.invoice_number, xPlayer.getName(), reason), 'warning')
    end

    SendDiscordLog('🚫 Rechnung abgelehnt', ('**%s** hat Rechnung %s abgelehnt. Grund: %s'):format(xPlayer.getName(), invoice.invoice_number, reason), 15158332)
end)

-- ============================================================
-- Rechnung stornieren (Admin)
-- ============================================================

RegisterNetEvent('esx_rechnungen:cancelInvoice', function(invoiceId, reason)
    local source = source
    if not IsPlayerAdmin(source) or not GetGlobalSetting('admin_can_cancel', true) then
        Notify(source, 'Keine Berechtigung.', 'error')
        return
    end

    invoiceId = tonumber(invoiceId)
    if not invoiceId then return end

    local xPlayer = ESX.GetPlayerFromId(source)

    MySQL.update.await(
        "UPDATE rechnungen_invoices SET payment_status = 'cancelled', cancelled_by = ?, cancelled_reason = ? WHERE id = ?",
        { xPlayer and xPlayer.identifier or 'admin', tostring(reason or 'Storniert durch Admin'):sub(1, 500), invoiceId }
    )

    Notify(source, 'Rechnung storniert.', 'success')

    SendDiscordLog('❌ Rechnung storniert', ('Admin **%s** hat Rechnung ID %d storniert. Grund: %s'):format(GetPlayerName(source), invoiceId, reason or '-'), 15158332)
end)

-- ============================================================
-- Rechnung löschen (Admin)
-- ============================================================

RegisterNetEvent('esx_rechnungen:deleteInvoice', function(invoiceId)
    local source = source
    if not IsPlayerAdmin(source) or not GetGlobalSetting('admin_can_delete', true) then
        Notify(source, 'Keine Berechtigung.', 'error')
        return
    end

    invoiceId = tonumber(invoiceId)
    if not invoiceId then return end

    MySQL.update.await('DELETE FROM rechnungen_invoices WHERE id = ?', { invoiceId })
    Notify(source, 'Rechnung gelöscht.', 'success')

    SendDiscordLog('🗑️ Rechnung gelöscht', ('Admin **%s** hat Rechnung ID %d gelöscht.'):format(GetPlayerName(source), invoiceId), 15158332)
end)

-- ============================================================
-- Alle verfügbaren Jobs für Adminpanel laden
-- ============================================================

ESX.RegisterServerCallback('esx_rechnungen:getAllJobs', function(source, cb)
    if not IsPlayerAdmin(source) then
        cb({})
        return
    end

    local jobs = MySQL.query.await('SELECT name, label FROM jobs ORDER BY label ASC')
    cb(jobs or {})
end)

-- ============================================================
-- Alle Societies für Adminpanel laden
-- ============================================================

ESX.RegisterServerCallback('esx_rechnungen:getAllSocieties', function(source, cb)
    if not IsPlayerAdmin(source) then
        cb({})
        return
    end

    local societies = MySQL.query.await("SELECT name, label FROM jobs WHERE name != 'unemployed' ORDER BY label ASC")
    cb(societies or {})
end)

-- ============================================================
-- Bablo-Features: Kontakte, Vorlagen, Einstellungen, Lookup
-- ============================================================

ESX.RegisterServerCallback('esx_rechnungen:lookupIdentifier', function(source, cb, identifier)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then cb(nil) return end

    identifier = tostring(identifier or ''):gsub('^%s+', ''):gsub('%s+$', '')
    if identifier == '' then cb(nil) return end

    for _, p in pairs(ESX.GetExtendedPlayers()) do
        if p.identifier == identifier then
            cb({ identifier = p.identifier, name = p.getName(), online = true, source = p.source })
            return
        end
    end

    local name = GetCharacterName(identifier)
    if name ~= identifier then
        cb({ identifier = identifier, name = name, online = false })
        return
    end

    cb(nil)
end)

RegisterNetEvent('esx_rechnungen:saveContact', function(data)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return end

    local name = tostring(data.contact_name or ''):sub(1, 100)
    local identifier = tostring(data.contact_identifier or ''):gsub('^%s+', ''):gsub('%s+$', '')

    if name == '' or identifier == '' then
        Notify(source, 'Name und Identifier sind erforderlich.', 'error')
        return
    end

    MySQL.insert.await(
        'INSERT INTO rechnungen_contacts (owner_identifier, contact_name, contact_identifier) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE contact_name = VALUES(contact_name)',
        { xPlayer.identifier, name, identifier }
    )
    Notify(source, 'Kontakt gespeichert.', 'success')
end)

RegisterNetEvent('esx_rechnungen:deleteContact', function(contactId)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return end

    contactId = tonumber(contactId)
    if not contactId then return end

    MySQL.update.await(
        'DELETE FROM rechnungen_contacts WHERE id = ? AND owner_identifier = ?',
        { contactId, xPlayer.identifier }
    )
    Notify(source, 'Kontakt gelöscht.', 'success')
end)

RegisterNetEvent('esx_rechnungen:saveTemplate', function(data)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return end

    local job = xPlayer.getJob()
    local jobSettings = GetJobSettings(job.name)
    if not CanJobIssueInvoices(jobSettings) then
        Notify(source, 'Keine Berechtigung für Vorlagen.', 'error')
        return
    end

    local name = tostring(data.name or ''):sub(1, 100)
    if name == '' then
        Notify(source, 'Vorlagenname erforderlich.', 'error')
        return
    end

    local lineItems = data.line_items
    local lineItemsJson = type(lineItems) == 'table' and json.encode(lineItems) or nil
    local isShared = data.is_shared and 1 or 0
    local templateId = tonumber(data.id)

    if templateId then
        MySQL.update.await([[
            UPDATE rechnungen_templates
            SET name = ?, title = ?, notes = ?, line_items = ?, is_shared = ?, job_name = ?
            WHERE id = ? AND owner_identifier = ?
        ]], {
            name, tostring(data.title or ''):sub(1, 200), tostring(data.notes or ''):sub(1, 2000),
            lineItemsJson, isShared, isShared == 1 and job.name or nil,
            templateId, xPlayer.identifier
        })
    else
        MySQL.insert.await([[
            INSERT INTO rechnungen_templates (owner_identifier, job_name, is_shared, name, title, notes, line_items)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        ]], {
            xPlayer.identifier, isShared == 1 and job.name or nil, isShared,
            name, tostring(data.title or ''):sub(1, 200), tostring(data.notes or ''):sub(1, 2000), lineItemsJson
        })
    end

    Notify(source, 'Vorlage gespeichert.', 'success')
end)

RegisterNetEvent('esx_rechnungen:deleteTemplate', function(templateId)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return end

    templateId = tonumber(templateId)
    if not templateId then return end

    MySQL.update.await(
        'DELETE FROM rechnungen_templates WHERE id = ? AND owner_identifier = ?',
        { templateId, xPlayer.identifier }
    )
    Notify(source, 'Vorlage gelöscht.', 'success')
end)

RegisterNetEvent('esx_rechnungen:saveUserPrefs', function(prefs)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return end

    local theme = prefs.theme == 'light' and 'light' or 'dark'
    local viewMode = prefs.view_mode == 'card' and 'card' or 'table'
    local accountMode = prefs.account_mode == 'business' and 'business' or 'personal'

    MySQL.insert.await([[
        INSERT INTO rechnungen_user_prefs (identifier, theme, view_mode, account_mode)
        VALUES (?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE theme = VALUES(theme), view_mode = VALUES(view_mode), account_mode = VALUES(account_mode)
    ]], { xPlayer.identifier, theme, viewMode, accountMode })
end)

RegisterNetEvent('esx_rechnungen:payAllInvoices', function(data)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return end

    local paymentMethod = (data and data.paymentMethod) or 'bank'
    local accountMode = (data and data.account_mode) or 'personal'
    local job = xPlayer.getJob()

    local invoices
    if accountMode == 'business' then
        invoices = MySQL.query.await(
            "SELECT * FROM rechnungen_invoices WHERE recipient_type = 'society' AND recipient_identifier = ? AND payment_status IN ('open', 'overdue') ORDER BY due_date ASC",
            { 'society:' .. job.name }
        ) or {}
    else
        invoices = MySQL.query.await(
            "SELECT * FROM rechnungen_invoices WHERE recipient_type = 'player' AND recipient_identifier = ? AND payment_status IN ('open', 'overdue') ORDER BY due_date ASC",
            { xPlayer.identifier }
        ) or {}
    end

    if #invoices == 0 then
        Notify(source, 'Keine offenen Rechnungen zum Bezahlen.', 'info')
        return
    end

    local paid = 0
    local totalPaid = 0
    for _, invoice in ipairs(invoices) do
        local ok, result = TryPayInvoice(source, xPlayer, invoice, paymentMethod)
        if ok then
            paid = paid + 1
            totalPaid = totalPaid + (tonumber(result) or 0)
        else
            break
        end
    end

    if paid == 0 then
        Notify(source, 'Keine Rechnung konnte bezahlt werden.', 'error')
    else
        Notify(source, ('%d Rechnung(en) bezahlt (%s€ gesamt).'):format(paid, totalPaid), 'success')
    end
end)
