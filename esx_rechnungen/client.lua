--[[
    ESX Rechnungssystem - Client
    Custom-NUI Menü (eigenes Popover-Menü, kein ox_lib)
]]

local ESX = exports['es_extended']:getSharedObject()
local isMenuOpen = false

-- ============================================================
-- Menü öffnen / schließen
-- ============================================================

---@param mode string
---@param data table|nil
local function OpenMenu(mode, data)
    if isMenuOpen then return end

    isMenuOpen = true
    SetNuiFocus(true, true)

    SendNUIMessage({
        action = 'open',
        mode = mode,
        data = data or {},
        config = {
            width = Config.MenuWidth,
            position = Config.MenuPosition
        }
    })
end

local function CloseMenu()
    if not isMenuOpen then return end

    isMenuOpen = false
    SetNuiFocus(false, false)

    SendNUIMessage({ action = 'close' })
end

-- ============================================================
-- Benachrichtigungen
-- ============================================================

RegisterNetEvent('esx_rechnungen:notify', function(msg, ntype)
    if ESX.ShowNotification then
        ESX.ShowNotification(msg, ntype or 'info')
    end
    SendNUIMessage({
        action = 'toast',
        message = msg,
        type = ntype or 'info'
    })
end)

-- ============================================================
-- NUI Callbacks
-- ============================================================

RegisterNUICallback('close', function(_, cb)
    CloseMenu()
    cb('ok')
end)

RegisterNUICallback('getMyInvoices', function(_, cb)
    ESX.TriggerServerCallback('esx_rechnungen:getMyInvoices', function(invoices)
        cb(invoices or {})
    end)
end)

RegisterNUICallback('payInvoice', function(data, cb)
    TriggerServerEvent('esx_rechnungen:payInvoice', data.invoiceId, data.paymentMethod)
    cb('ok')
end)

RegisterNUICallback('canCreateInvoice', function(_, cb)
    ESX.TriggerServerCallback('esx_rechnungen:canCreateInvoice', function(canCreate, result)
        cb({ canCreate = canCreate, data = result })
    end)
end)

RegisterNUICallback('getNearbyPlayers', function(_, cb)
    ESX.TriggerServerCallback('esx_rechnungen:getNearbyPlayers', function(players)
        cb(players or {})
    end)
end)

RegisterNUICallback('getSocieties', function(_, cb)
    ESX.TriggerServerCallback('esx_rechnungen:getSocieties', function(societies)
        cb(societies or {})
    end)
end)

RegisterNUICallback('createInvoice', function(data, cb)
    TriggerServerEvent('esx_rechnungen:createInvoice', data)
    cb('ok')
end)

RegisterNUICallback('isAdmin', function(_, cb)
    ESX.TriggerServerCallback('esx_rechnungen:isAdmin', function(isAdmin)
        cb(isAdmin)
    end)
end)

RegisterNUICallback('getGlobalSettings', function(_, cb)
    ESX.TriggerServerCallback('esx_rechnungen:getGlobalSettings', function(settings)
        cb(settings or {})
    end)
end)

RegisterNUICallback('saveGlobalSettings', function(data, cb)
    TriggerServerEvent('esx_rechnungen:saveGlobalSettings', data)
    cb('ok')
end)

RegisterNUICallback('getJobSettings', function(_, cb)
    ESX.TriggerServerCallback('esx_rechnungen:getJobSettings', function(result)
        cb(result or { jobs = {}, settings = {} })
    end)
end)

RegisterNUICallback('saveJobSettings', function(data, cb)
    TriggerServerEvent('esx_rechnungen:saveJobSettings', data)
    cb('ok')
end)

RegisterNUICallback('deleteJobSettings', function(data, cb)
    TriggerServerEvent('esx_rechnungen:deleteJobSettings', data.jobName)
    cb('ok')
end)

RegisterNUICallback('getSocietyInfo', function(_, cb)
    ESX.TriggerServerCallback('esx_rechnungen:getSocietyInfo', function(info)
        cb(info or {})
    end)
end)

RegisterNUICallback('saveSocietyInfo', function(data, cb)
    TriggerServerEvent('esx_rechnungen:saveSocietyInfo', data)
    cb('ok')
end)

RegisterNUICallback('deleteSocietyInfo', function(data, cb)
    TriggerServerEvent('esx_rechnungen:deleteSocietyInfo', data.societyName)
    cb('ok')
end)

RegisterNUICallback('getAllInvoices', function(_, cb)
    ESX.TriggerServerCallback('esx_rechnungen:getAllInvoices', function(invoices)
        cb(invoices or {})
    end)
end)

RegisterNUICallback('editInvoice', function(data, cb)
    TriggerServerEvent('esx_rechnungen:editInvoice', data.invoiceId, data)
    cb('ok')
end)

RegisterNUICallback('cancelInvoice', function(data, cb)
    TriggerServerEvent('esx_rechnungen:cancelInvoice', data.invoiceId, data.reason)
    cb('ok')
end)

RegisterNUICallback('deleteInvoice', function(data, cb)
    TriggerServerEvent('esx_rechnungen:deleteInvoice', data.invoiceId)
    cb('ok')
end)

RegisterNUICallback('getAllJobs', function(_, cb)
    ESX.TriggerServerCallback('esx_rechnungen:getAllJobs', function(jobs)
        cb(jobs or {})
    end)
end)

RegisterNUICallback('getAllSocieties', function(_, cb)
    ESX.TriggerServerCallback('esx_rechnungen:getAllSocieties', function(societies)
        cb(societies or {})
    end)
end)

-- ============================================================
-- Steuerung blockieren während Menü offen
-- ============================================================

CreateThread(function()
    while true do
        if isMenuOpen then
            Wait(0)
            DisableControlAction(0, 1, true)
            DisableControlAction(0, 2, true)
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 37, true)
            DisableControlAction(0, 140, true)
            DisableControlAction(0, 141, true)
            DisableControlAction(0, 142, true)
            DisableControlAction(0, 200, true)
            DisableControlAction(0, 245, true)
        else
            Wait(400)
        end
    end
end)

-- ============================================================
-- Commands
-- ============================================================

RegisterCommand(Config.PlayerCommand, function()
    if isMenuOpen then CloseMenu() return end
    OpenMenu('player')
end, false)

RegisterCommand(Config.CreateCommand, function()
    if isMenuOpen then CloseMenu() return end

    ESX.TriggerServerCallback('esx_rechnungen:canCreateInvoice', function(canCreate, result)
        if not canCreate then
            ESX.ShowNotification(result or 'Du darfst keine Rechnungen ausstellen.', 'error')
            return
        end
        OpenMenu('create', result)
    end)
end, false)

RegisterCommand(Config.AdminCommand, function()
    if isMenuOpen then CloseMenu() return end

    ESX.TriggerServerCallback('esx_rechnungen:isAdmin', function(isAdmin)
        if not isAdmin then
            ESX.ShowNotification('Keine Berechtigung für das Adminpanel.', 'error')
            return
        end
        OpenMenu('admin')
    end)
end, false)

-- ============================================================
-- Exports
-- ============================================================

exports('OpenInvoiceMenu', function() OpenMenu('player') end)

exports('OpenAdminPanel', function()
    ESX.TriggerServerCallback('esx_rechnungen:isAdmin', function(isAdmin)
        if isAdmin then OpenMenu('admin') end
    end)
end)

exports('OpenCreateInvoice', function()
    ESX.TriggerServerCallback('esx_rechnungen:canCreateInvoice', function(canCreate, result)
        if canCreate then OpenMenu('create', result) end
    end)
end)
