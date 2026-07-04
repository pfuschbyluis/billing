--[[
    ESX Rechnungssystem - Client
    Commands, NUI-Steuerung und Benachrichtigungen
]]

local ESX = exports['es_extended']:getSharedObject()

local isUIOpen = false
local currentMode = nil -- 'player', 'admin', 'create'

-- ============================================================
-- Hilfsfunktionen
-- ============================================================

--- Öffnet die NUI
---@param mode string
---@param data table|nil
local function OpenUI(mode, data)
    if isUIOpen then return end

    isUIOpen = true
    currentMode = mode
    SetNuiFocus(true, true)

    SendNUIMessage({
        action = 'open',
        mode = mode,
        data = data or {}
    })
end

--- Schließt die NUI
local function CloseUI()
    if not isUIOpen then return end

    isUIOpen = false
    currentMode = nil
    SetNuiFocus(false, false)

    SendNUIMessage({
        action = 'close'
    })
end

--- Benachrichtigung anzeigen
RegisterNetEvent('esx_rechnungen:notify', function(msg, ntype)
    if ESX and ESX.ShowNotification then
        ESX.ShowNotification(msg, ntype or 'info')
    else
        -- Fallback
        BeginTextCommandThefeedPost('STRING')
        AddTextComponentSubstringPlayerName(msg)
        EndTextCommandThefeedPostTicker(false, true)
    end
end)

-- ============================================================
-- NUI Callbacks
-- ============================================================

--- NUI schließen
RegisterNUICallback('close', function(_, cb)
    CloseUI()
    cb('ok')
end)

--- Rechnungen des Spielers laden
RegisterNUICallback('getMyInvoices', function(_, cb)
    ESX.TriggerServerCallback('esx_rechnungen:getMyInvoices', function(invoices)
        cb(invoices or {})
    end)
end)

--- Rechnung bezahlen
RegisterNUICallback('payInvoice', function(data, cb)
    TriggerServerEvent('esx_rechnungen:payInvoice', data.invoiceId, data.paymentMethod)
    cb('ok')
end)

--- Prüfen ob Rechnung erstellt werden kann
RegisterNUICallback('canCreateInvoice', function(_, cb)
    ESX.TriggerServerCallback('esx_rechnungen:canCreateInvoice', function(canCreate, result)
        cb({ canCreate = canCreate, data = result })
    end)
end)

--- Nahe Spieler laden
RegisterNUICallback('getNearbyPlayers', function(_, cb)
    ESX.TriggerServerCallback('esx_rechnungen:getNearbyPlayers', function(players)
        cb(players or {})
    end)
end)

--- Societies laden
RegisterNUICallback('getSocieties', function(_, cb)
    ESX.TriggerServerCallback('esx_rechnungen:getSocieties', function(societies)
        cb(societies or {})
    end)
end)

--- Rechnung erstellen
RegisterNUICallback('createInvoice', function(data, cb)
    TriggerServerEvent('esx_rechnungen:createInvoice', data)
    cb('ok')
end)

-- Admin-Callbacks

--- Admin-Status prüfen
RegisterNUICallback('isAdmin', function(_, cb)
    ESX.TriggerServerCallback('esx_rechnungen:isAdmin', function(isAdmin)
        cb(isAdmin)
    end)
end)

--- Globale Einstellungen laden
RegisterNUICallback('getGlobalSettings', function(_, cb)
    ESX.TriggerServerCallback('esx_rechnungen:getGlobalSettings', function(settings)
        cb(settings or {})
    end)
end)

--- Globale Einstellungen speichern
RegisterNUICallback('saveGlobalSettings', function(data, cb)
    TriggerServerEvent('esx_rechnungen:saveGlobalSettings', data)
    cb('ok')
end)

--- Job-Einstellungen laden
RegisterNUICallback('getJobSettings', function(_, cb)
    ESX.TriggerServerCallback('esx_rechnungen:getJobSettings', function(result)
        cb(result or { jobs = {}, settings = {} })
    end)
end)

--- Job-Einstellungen speichern
RegisterNUICallback('saveJobSettings', function(data, cb)
    TriggerServerEvent('esx_rechnungen:saveJobSettings', data)
    cb('ok')
end)

--- Job-Einstellungen löschen
RegisterNUICallback('deleteJobSettings', function(data, cb)
    TriggerServerEvent('esx_rechnungen:deleteJobSettings', data.jobName)
    cb('ok')
end)

--- Society-Info laden
RegisterNUICallback('getSocietyInfo', function(_, cb)
    ESX.TriggerServerCallback('esx_rechnungen:getSocietyInfo', function(info)
        cb(info or {})
    end)
end)

--- Society-Info speichern
RegisterNUICallback('saveSocietyInfo', function(data, cb)
    TriggerServerEvent('esx_rechnungen:saveSocietyInfo', data)
    cb('ok')
end)

--- Society-Info löschen
RegisterNUICallback('deleteSocietyInfo', function(data, cb)
    TriggerServerEvent('esx_rechnungen:deleteSocietyInfo', data.societyName)
    cb('ok')
end)

--- Alle Rechnungen laden (Admin)
RegisterNUICallback('getAllInvoices', function(_, cb)
    ESX.TriggerServerCallback('esx_rechnungen:getAllInvoices', function(invoices)
        cb(invoices or {})
    end)
end)

--- Rechnung bearbeiten (Admin)
RegisterNUICallback('editInvoice', function(data, cb)
    TriggerServerEvent('esx_rechnungen:editInvoice', data.invoiceId, data)
    cb('ok')
end)

--- Rechnung stornieren (Admin)
RegisterNUICallback('cancelInvoice', function(data, cb)
    TriggerServerEvent('esx_rechnungen:cancelInvoice', data.invoiceId, data.reason)
    cb('ok')
end)

--- Rechnung löschen (Admin)
RegisterNUICallback('deleteInvoice', function(data, cb)
    TriggerServerEvent('esx_rechnungen:deleteInvoice', data.invoiceId)
    cb('ok')
end)

--- Alle Jobs laden
RegisterNUICallback('getAllJobs', function(_, cb)
    ESX.TriggerServerCallback('esx_rechnungen:getAllJobs', function(jobs)
        cb(jobs or {})
    end)
end)

--- Alle Societies laden
RegisterNUICallback('getAllSocieties', function(_, cb)
    ESX.TriggerServerCallback('esx_rechnungen:getAllSocieties', function(societies)
        cb(societies or {})
    end)
end)

-- ============================================================
-- Commands
-- ============================================================

--- Spieler-Rechnungsübersicht
RegisterCommand(Config.PlayerCommand, function()
    if isUIOpen then
        CloseUI()
        return
    end
    OpenUI('player')
end, false)

--- Rechnung erstellen
RegisterCommand(Config.CreateCommand, function()
    if isUIOpen then
        CloseUI()
        return
    end

    ESX.TriggerServerCallback('esx_rechnungen:canCreateInvoice', function(canCreate, result)
        if not canCreate then
            ESX.ShowNotification(result or 'Du darfst keine Rechnungen ausstellen.', 'error')
            return
        end
        OpenUI('create', result)
    end)
end, false)

--- Adminpanel
RegisterCommand(Config.AdminCommand, function()
    if isUIOpen then
        CloseUI()
        return
    end

    ESX.TriggerServerCallback('esx_rechnungen:isAdmin', function(isAdmin)
        if not isAdmin then
            ESX.ShowNotification('Keine Berechtigung für das Adminpanel.', 'error')
            return
        end
        OpenUI('admin')
    end)
end, false)

-- ============================================================
-- ESC-Taste zum Schließen
-- ============================================================

CreateThread(function()
    while true do
        Wait(0)
        if isUIOpen then
            DisableControlAction(0, 1, true)   -- LookLeftRight
            DisableControlAction(0, 2, true)   -- LookUpDown
            DisableControlAction(0, 142, true) -- MeleeAttackAlternate
            DisableControlAction(0, 18, true)  -- Enter
            DisableControlAction(0, 322, true) -- ESC
            DisableControlAction(0, 106, true) -- VehicleMouseControlOverride

            if IsDisabledControlJustReleased(0, 322) then
                CloseUI()
            end
        else
            Wait(500)
        end
    end
end)

-- ============================================================
-- Export für andere Resources
-- ============================================================

--- Öffnet das Spieler-Rechnungsmenü
exports('OpenInvoiceMenu', function()
    OpenUI('player')
end)

--- Öffnet das Adminpanel (prüft Berechtigung serverseitig)
exports('OpenAdminPanel', function()
    ESX.TriggerServerCallback('esx_rechnungen:isAdmin', function(isAdmin)
        if isAdmin then
            OpenUI('admin')
        end
    end)
end)

--- Öffnet Rechnungserstellung
exports('OpenCreateInvoice', function()
    ESX.TriggerServerCallback('esx_rechnungen:canCreateInvoice', function(canCreate, result)
        if canCreate then
            OpenUI('create', result)
        end
    end)
end)
