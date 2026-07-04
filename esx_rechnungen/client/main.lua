--[[
    ESX Rechnungssystem - Client Hauptdatei
    Commands, Benachrichtigungen und Exports
]]

ESX = exports['es_extended']:getSharedObject()

Rechnungen = Rechnungen or {}

-- ============================================================
-- Hilfsfunktionen
-- ============================================================

--- Formatiert einen Betrag als Euro-String
---@param amount number|string
---@return string
function Rechnungen.FormatMoney(amount)
    local n = tonumber(amount) or 0
    local s = string.format('%.2f', n):gsub('%.', ',')
    local k
    repeat
        s, k = string.gsub(s, '^(-?%d+)(%d%d%d)', '%1.%2')
    until k == 0
    return s .. ' €'
end

--- Formatiert ein Datum (deutsch)
---@param dateStr string|nil
---@return string
function Rechnungen.FormatDate(dateStr)
    if not dateStr or dateStr == '' then return '-' end
    local y, m, d = string.match(tostring(dateStr), '(%d+)-(%d+)-(%d+)')
    if y then return ('%s.%s.%s'):format(d, m, y) end
    return tostring(dateStr)
end

--- Deutscher Status-Text
---@param status string
---@return string
function Rechnungen.GetStatusLabel(status)
    local labels = {
        open = 'Offen',
        paid = 'Bezahlt',
        overdue = 'Überfällig',
        cancelled = 'Storniert'
    }
    return labels[status] or status
end

--- Icon für Zahlungsstatus
---@param status string
---@return string
function Rechnungen.GetStatusIcon(status)
    local icons = {
        open = 'clock',
        paid = 'circle-check',
        overdue = 'triangle-exclamation',
        cancelled = 'ban'
    }
    return icons[status] or 'file-lines'
end

--- Benachrichtigung anzeigen (ox_lib)
---@param msg string
---@param ntype string|nil
function Rechnungen.Notify(msg, ntype)
    lib.notify({
        title = 'Rechnungssystem',
        description = msg,
        type = ntype or 'inform',
        position = 'top-right',
        duration = 5000
    })
end

RegisterNetEvent('esx_rechnungen:notify', function(msg, ntype)
    local types = { info = 'inform', error = 'error', success = 'success', warning = 'warning' }
    Rechnungen.Notify(msg, types[ntype] or ntype)
end)

-- ============================================================
-- Commands
-- ============================================================

RegisterCommand(Config.PlayerCommand, function()
    OpenPlayerMenu()
end, false)

RegisterCommand(Config.CreateCommand, function()
    OpenCreateInvoiceMenu()
end, false)

RegisterCommand(Config.AdminCommand, function()
    ESX.TriggerServerCallback('esx_rechnungen:isAdmin', function(isAdmin)
        if not isAdmin then
            Rechnungen.Notify('Keine Berechtigung für das Adminpanel.', 'error')
            return
        end
        OpenAdminMenu()
    end)
end, false)

-- ============================================================
-- Exports
-- ============================================================

exports('OpenInvoiceMenu', OpenPlayerMenu)
exports('OpenAdminPanel', function()
    ESX.TriggerServerCallback('esx_rechnungen:isAdmin', function(isAdmin)
        if isAdmin then OpenAdminMenu() end
    end)
end)
exports('OpenCreateInvoice', OpenCreateInvoiceMenu)
