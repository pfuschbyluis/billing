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
        "ALTER TABLE rechnungen_invoices ADD COLUMN issuer_mode VARCHAR(20) DEFAULT 'personal'"
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

--- Holt Job-Einstellungen (mit Defaults)
---@param jobName string
---@return table|nil
local function GetJobSettings(jobName)
    return JobSettings[jobName]
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

        ConsoleLog('success', 'Rechnungssystem erfolgreich geladen und einsatzbereit.')
    end)
end)

-- Periodisch überfällige Rechnungen prüfen (alle 30 Minuten)
CreateThread(function()
    while true do
        Wait(1800000)
        UpdateOverdueInvoices()
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

    if not jobSettings or not jobSettings.can_issue or jobSettings.can_issue == 0 then
        cb(false, 'Dein Job darf keine Rechnungen ausstellen.')
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

    if not jobSettings or not jobSettings.can_issue or jobSettings.can_issue == 0 then
        Notify(source, 'Dein Job darf keine Rechnungen ausstellen.', 'error')
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
    local maxAmount = tonumber(jobSettings.max_amount) or 10000
    if netAmount > maxAmount then
        Notify(source, ('Der Betrag überschreitet das Maximum von %d€.'):format(maxAmount), 'error')
        return
    end

    -- Validierung: Rechnungsgrund
    if reason == '' then
        Notify(source, 'Bitte gib einen Rechnungsgrund an.', 'error')
        return
    end

    local notes = tostring(data.notes or ''):sub(1, 2000)
    local signature = data.signature
    if type(signature) == 'string' and #signature > 500000 then
        signature = signature:sub(1, 500000)
    end

    -- Validierung: Empfänger
    local recipientIdentifier = nil
    local recipientName = nil

    if recipientType == 'player' then
        local targetId = tonumber(data.target_id)
        if not targetId then
            Notify(source, 'Ungültiger Empfänger.', 'error')
            return
        end

        local xTarget = ESX.GetPlayerFromId(targetId)
        if not xTarget then
            Notify(source, 'Empfänger nicht gefunden oder nicht online.', 'error')
            return
        end

        -- Validierung: Nähe
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

    -- Fälligkeitsdatum
    local durationDays = tonumber(data.duration_days) or GetGlobalSetting('payment_deadline_days', 14)
    durationDays = math.max(1, math.min(durationDays, 365))
    local dueDate = os.date('%Y-%m-%d', os.time() + (durationDays * 86400))

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
        if inv.payment_status == 'open' or inv.payment_status == 'overdue' then
            stats.open = stats.open + 1
            stats.open_amount = stats.open_amount + gross
            if inv.payment_status == 'overdue' then
                stats.open_amount = stats.open_amount + (tonumber(inv.reminder_fee) or 0)
            end
        elseif inv.payment_status == 'paid' then
            stats.paid = stats.paid + 1
        elseif inv.payment_status == 'overdue' then
            stats.overdue = stats.overdue + 1
        end
    end

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
    if jobSettings and jobSettings.can_issue == 1 then
        canCreate = true
        createData = { job = job, settings = jobSettings, societyInfo = SocietyInfo[job.name], templates = GetDefaultTemplates() }
    end

    cb({
        playerName = xPlayer.getName(),
        isAdmin = isAdmin,
        canCreate = canCreate,
        createData = createData,
        received = received,
        created = created,
        stats = stats
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

RegisterNetEvent('esx_rechnungen:payInvoice', function(invoiceId, paymentMethod)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return end

    invoiceId = tonumber(invoiceId)
    if not invoiceId then return end

    -- Rechnung laden
    local invoice = MySQL.single.await('SELECT * FROM rechnungen_invoices WHERE id = ?', { invoiceId })
    if not invoice then
        Notify(source, 'Rechnung nicht gefunden.', 'error')
        return
    end

    -- Validierung: Empfänger (Spieler oder Society-Mitarbeiter)
    if invoice.recipient_type == 'player' then
        if invoice.recipient_identifier ~= xPlayer.identifier then
            Notify(source, 'Diese Rechnung gehört nicht dir.', 'error')
            return
        end
    elseif invoice.recipient_type == 'society' then
        local societyName = invoice.recipient_identifier:gsub('^society:', '')
        if xPlayer.getJob().name ~= societyName then
            Notify(source, 'Diese Firmenrechnung gehört nicht zu deiner Firma.', 'error')
            return
        end
    end

    -- Validierung: Status
    if invoice.payment_status ~= 'open' and invoice.payment_status ~= 'overdue' then
        Notify(source, 'Diese Rechnung kann nicht mehr bezahlt werden.', 'error')
        return
    end

    -- Job-Einstellungen des Ausstellers laden
    local jobSettings = GetJobSettings(invoice.issuer_job)
    if not jobSettings then
        jobSettings = {
            payment_bank = 1,
            payment_cash = 1,
            money_destination = 'society',
            society_percent = 70,
            employee_percent = 30
        }
    end

    -- Validierung: Zahlungsmethode
    paymentMethod = paymentMethod or 'bank'
    if paymentMethod == 'bank' and (not jobSettings.payment_bank or jobSettings.payment_bank == 0) then
        Notify(source, 'Bankzahlung ist für diese Rechnung nicht erlaubt.', 'error')
        return
    end
    if paymentMethod == 'cash' and (not jobSettings.payment_cash or jobSettings.payment_cash == 0) then
        Notify(source, 'Barzahlung ist für diese Rechnung nicht erlaubt.', 'error')
        return
    end

    -- Gesamtbetrag inkl. Mahngebühr bei Überfälligkeit
    local totalAmount = tonumber(invoice.gross_amount)
    if invoice.payment_status == 'overdue' then
        totalAmount = totalAmount + tonumber(invoice.reminder_fee or 0)
    end

    -- Validierung: Geld (bei Society-Rechnungen vom Firmenkonto)
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
            Notify(source, 'Nicht genug Geld auf dem Firmenkonto.', 'error')
            return
        end

        societyAccount.removeMoney(totalAmount)
    elseif paymentMethod == 'bank' then
        local bankMoney = xPlayer.getAccount('bank').money
        if bankMoney < totalAmount then
            Notify(source, 'Nicht genug Geld auf dem Bankkonto.', 'error')
            return
        end
        xPlayer.removeAccountMoney('bank', totalAmount, 'Rechnung ' .. invoice.invoice_number)
    else
        local cashMoney = xPlayer.getMoney()
        if cashMoney < totalAmount then
            Notify(source, 'Nicht genug Bargeld.', 'error')
            return
        end
        xPlayer.removeMoney(totalAmount, 'Rechnung ' .. invoice.invoice_number)
    end

    -- Geld weiterleiten
    local destination = jobSettings.money_destination or 'society'
    local societyPercent = tonumber(jobSettings.society_percent) or 70
    local employeePercent = tonumber(jobSettings.employee_percent) or 30

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
            -- Aussteller offline -> an Society
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

    -- Status aktualisieren
    MySQL.update.await(
        "UPDATE rechnungen_invoices SET payment_status = 'paid', payment_method = ?, paid_at = NOW() WHERE id = ?",
        { paymentMethod, invoiceId }
    )

    Notify(source, ('Rechnung %s erfolgreich bezahlt (%s€).'):format(invoice.invoice_number, totalAmount), 'success')

    SendDiscordLog('💰 Rechnung bezahlt', ([[
**Rechnungsnummer:** %s
**Bezahlt von:** %s
**Betrag:** %s€
**Methode:** %s
    ]]):format(invoice.invoice_number, xPlayer.getName(), totalAmount, paymentMethod == 'bank' and 'Bank' or 'Bargeld'), 5763719)
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
