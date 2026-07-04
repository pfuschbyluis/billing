--[[
    ESX Rechnungssystem - Client
    Custom-NUI Billing-Dashboard (kein ox_lib)
]]

local ESX = exports['es_extended']:getSharedObject()
local isMenuOpen = false
local locationBlips = {}

local function ShowNotify(msg, ntype)
    ntype = ntype or 'info'
    local preset = Config.Notify and Config.Notify.preset or 'esx'

    if preset == 'ox_lib' and GetResourceState('ox_lib') == 'started' then
        exports.ox_lib:notify({ description = msg, type = ntype })
    elseif preset == 'custom' and Config.Notify.custom_export then
        local exportRef = Config.Notify.custom_export
        local colon = exportRef:find(':')
        if colon then
            local res = exportRef:sub(1, colon - 1)
            local fn = exportRef:sub(colon + 1)
            if exports[res] and exports[res][fn] then
                exports[res][fn](msg, ntype)
            end
        end
    elseif ESX.ShowNotification then
        ESX.ShowNotification(msg, ntype)
    end

    SendNUIMessage({ action = 'toast', message = msg, type = ntype })
end

local function CanUseLocation(loc)
    if loc.jobs then
        local job = ESX.GetPlayerData().job
        if not job then return false end
        local allowed = false
        for _, j in ipairs(loc.jobs) do
            if j == job.name then allowed = true break end
        end
        if not allowed then return false end
    end

    if loc.hours then
        local hour = GetClockHours()
        if hour < loc.hours.open or hour >= loc.hours.close then
            return false
        end
    end

    return true
end

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
            width = Config.UI and Config.UI.width or Config.MenuWidth,
            position = Config.UI and Config.UI.position or Config.MenuPosition,
            ui = Config.UI,
            durations = Config.Durations,
            limits = Config.Limits,
            locale = Locales[Config.Locale] or Locales['de']
        }
    })
end

local function CloseMenu()
    if not isMenuOpen then return end

    isMenuOpen = false
    SetNuiFocus(false, false)

    SendNUIMessage({ action = 'close' })
end

--- Öffnet das F7-Dashboard (toggle)
local function OpenDashboard()
    if isMenuOpen then
        CloseMenu()
        return
    end

    ESX.TriggerServerCallback('esx_rechnungen:getDashboardData', function(data)
        if not data then return end
        data.tab = 'dashboard'
        OpenMenu('dashboard', data)
    end)
end

---@param tab string|nil
---@param subTab string|nil
local function OpenDashboardTab(tab, subTab)
    if isMenuOpen then
        CloseMenu()
        return
    end

    ESX.TriggerServerCallback('esx_rechnungen:getDashboardData', function(data)
        if not data then return end
        data.tab = tab or 'dashboard'
        data.subTab = subTab
        OpenMenu('dashboard', data)
    end)
end

-- ============================================================
-- Benachrichtigungen
-- ============================================================

RegisterNetEvent('esx_rechnungen:notify', function(msg, ntype)
    ShowNotify(msg, ntype)
end)

-- ============================================================
-- NUI Callbacks
-- ============================================================

RegisterNUICallback('close', function(_, cb)
    CloseMenu()
    cb('ok')
end)

RegisterNUICallback('getDashboardData', function(_, cb)
    ESX.TriggerServerCallback('esx_rechnungen:getDashboardData', function(data)
        cb(data or {})
    end)
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

RegisterNUICallback('rejectInvoice', function(data, cb)
    TriggerServerEvent('esx_rechnungen:rejectInvoice', data.invoiceId, data.reason)
    cb('ok')
end)

RegisterNUICallback('deleteInvoice', function(data, cb)
    TriggerServerEvent('esx_rechnungen:deleteInvoice', data.invoiceId)
    cb('ok')
end)

RegisterNUICallback('lookupIdentifier', function(data, cb)
    ESX.TriggerServerCallback('esx_rechnungen:lookupIdentifier', function(result)
        cb(result)
    end, data.identifier)
end)

RegisterNUICallback('saveContact', function(data, cb)
    TriggerServerEvent('esx_rechnungen:saveContact', data)
    cb('ok')
end)

RegisterNUICallback('deleteContact', function(data, cb)
    TriggerServerEvent('esx_rechnungen:deleteContact', data.contactId)
    cb('ok')
end)

RegisterNUICallback('saveTemplate', function(data, cb)
    TriggerServerEvent('esx_rechnungen:saveTemplate', data)
    cb('ok')
end)

RegisterNUICallback('deleteTemplate', function(data, cb)
    TriggerServerEvent('esx_rechnungen:deleteTemplate', data.templateId)
    cb('ok')
end)

RegisterNUICallback('saveUserPrefs', function(data, cb)
    TriggerServerEvent('esx_rechnungen:saveUserPrefs', data)
    cb('ok')
end)

RegisterNUICallback('payAllInvoices', function(data, cb)
    TriggerServerEvent('esx_rechnungen:payAllInvoices', data)
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

--- F7-Dashboard (auch per Command)
RegisterCommand(Config.HubCommand, function()
    OpenDashboard()
end, false)

RegisterKeyMapping(Config.HubCommand, Config.KeybindDescription, 'keyboard', Config.Keybind)

RegisterCommand(Config.PlayerCommand, function()
    OpenDashboardTab('received', 'received')
end, false)

RegisterCommand(Config.CreateCommand, function()
    ESX.TriggerServerCallback('esx_rechnungen:canCreateInvoice', function(canCreate, result)
        if not canCreate then
            ESX.ShowNotification(result or 'Du darfst keine Rechnungen ausstellen.', 'error')
            return
        end
        if isMenuOpen then CloseMenu() return end
        ESX.TriggerServerCallback('esx_rechnungen:getDashboardData', function(data)
            if not data then return end
            data.tab = 'create'
            data.createData = result
            data.canCreate = true
            OpenMenu('dashboard', data)
        end)
    end)
end, false)

RegisterCommand(Config.AdminCommand, function()
    ESX.TriggerServerCallback('esx_rechnungen:isAdmin', function(isAdmin)
        if not isAdmin then
            ESX.ShowNotification('Keine Berechtigung für das Adminpanel.', 'error')
            return
        end
        OpenDashboardTab('admin')
    end)
end, false)

-- ============================================================
-- Rechnungsstationen (Blips & Marker)
-- ============================================================

CreateThread(function()
    for i, loc in ipairs(Config.Locations or {}) do
        if loc.blip and loc.blip.enabled and loc.coords then
            local blip = AddBlipForCoord(loc.coords.x, loc.coords.y, loc.coords.z)
            SetBlipSprite(blip, loc.blip.sprite or 500)
            SetBlipColour(blip, loc.blip.color or 83)
            SetBlipScale(blip, loc.blip.scale or 0.75)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentString(loc.blip.label or 'Rechnungen')
            EndTextCommandSetBlipName(blip)
            locationBlips[#locationBlips + 1] = blip
        end
    end
end)

CreateThread(function()
    while true do
        local sleep = 1000
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)

        for _, loc in ipairs(Config.Locations or {}) do
            if loc.coords then
                local dist = #(coords - loc.coords)
                if dist < 30.0 then
                    sleep = 0
                    if loc.marker and loc.marker.enabled ~= false then
                        local m = loc.marker
                        local c = m.color or { r = 125, g = 82, b = 255, a = 140 }
                        local s = m.scale or vector3(1.0, 1.0, 1.0)
                        DrawMarker(m.type or 27, loc.coords.x, loc.coords.y, loc.coords.z - 0.98,
                            0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                            s.x, s.y, s.z, c.r, c.g, c.b, c.a,
                            false, false, 2, false, nil, nil, false)
                    end

                    if dist <= (loc.radius or 2.5) and CanUseLocation(loc) then
                        ESX.ShowHelpNotification('Drücke ~INPUT_CONTEXT~ für Rechnungen')
                        if IsControlJustReleased(0, 38) then
                            OpenDashboard()
                        end
                    end
                end
            end
        end

        Wait(sleep)
    end
end)

-- ============================================================
-- Exports
-- ============================================================

exports('OpenInvoiceMenu', function() OpenDashboardTab('received', 'received') end)
exports('OpenDashboard', OpenDashboard)
exports('OpenHubMenu', OpenDashboard)

exports('OpenAdminPanel', function()
    ESX.TriggerServerCallback('esx_rechnungen:isAdmin', function(isAdmin)
        if isAdmin then OpenDashboardTab('admin') end
    end)
end)

exports('OpenCreateInvoice', function()
    ESX.TriggerServerCallback('esx_rechnungen:canCreateInvoice', function(canCreate, result)
        if not canCreate then return end
        if isMenuOpen then CloseMenu() return end
        ESX.TriggerServerCallback('esx_rechnungen:getDashboardData', function(data)
            if not data then return end
            data.tab = 'create'
            data.createData = result
            data.canCreate = true
            OpenMenu('dashboard', data)
        end)
    end)
end)
