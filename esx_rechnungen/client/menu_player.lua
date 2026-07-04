--[[
    Spieler-Menü: Rechnungen anzeigen und bezahlen (ox_lib)
]]

local currentFilter = 'all'

--- Öffnet das Hauptmenü für Spieler
function OpenPlayerMenu()
  lib.registerContext({
    id = 'rechnungen_main',
    title = 'Rechnungssystem',
    options = {
      {
        title = 'Alle Rechnungen',
        description = 'Komplette Übersicht',
        icon = 'list',
        onSelect = function()
          currentFilter = 'all'
          OpenPlayerInvoiceList()
        end
      },
      {
        title = 'Offene Rechnungen',
        description = 'Noch nicht bezahlt',
        icon = 'clock',
        onSelect = function()
          currentFilter = 'open'
          OpenPlayerInvoiceList()
        end
      },
      {
        title = 'Bezahlte Rechnungen',
        description = 'Abgeschlossene Zahlungen',
        icon = 'circle-check',
        onSelect = function()
          currentFilter = 'paid'
          OpenPlayerInvoiceList()
        end
      },
      {
        title = 'Überfällige Rechnungen',
        description = 'Inkl. möglicher Mahngebühren',
        icon = 'triangle-exclamation',
        onSelect = function()
          currentFilter = 'overdue'
          OpenPlayerInvoiceList()
        end
      }
    }
  })

  lib.showContext('rechnungen_main')
end

--- Zeigt gefilterte Rechnungsliste
function OpenPlayerInvoiceList()
  ESX.TriggerServerCallback('esx_rechnungen:getMyInvoices', function(invoices)
    local options = {}
    local filtered = {}

    for _, inv in ipairs(invoices or {}) do
      if currentFilter == 'all' or inv.payment_status == currentFilter then
        filtered[#filtered + 1] = inv
      end
    end

    if #filtered == 0 then
      options[#options + 1] = {
        title = 'Keine Rechnungen',
        description = 'In dieser Kategorie nichts vorhanden',
        icon = 'inbox',
        readOnly = true
      }
    else
      for _, inv in ipairs(filtered) do
        local gross = tonumber(inv.gross_amount) or 0
        local reminder = (inv.payment_status == 'overdue') and (tonumber(inv.reminder_fee) or 0) or 0
        local total = gross + reminder

        options[#options + 1] = {
          title = inv.invoice_number,
          description = ('%s · %s'):format(inv.reason, Rechnungen.FormatMoney(total)),
          icon = Rechnungen.GetStatusIcon(inv.payment_status),
          arrow = true,
          metadata = {
            { label = 'Status', value = Rechnungen.GetStatusLabel(inv.payment_status) },
            { label = 'Aussteller', value = inv.issuer_name or inv.issuer_job or '-' },
            { label = 'Datum', value = Rechnungen.FormatDate(inv.created_at) },
            { label = 'Brutto', value = Rechnungen.FormatMoney(total) }
          },
          onSelect = function()
            OpenPlayerInvoiceDetail(inv)
          end
        }
      end
    end

    lib.registerContext({
      id = 'rechnungen_list',
      title = 'Meine Rechnungen',
      menu = 'rechnungen_main',
      options = options
    })

    lib.showContext('rechnungen_list')
  end)
end

--- Detailansicht einer Rechnung mit Bezahloption
---@param inv table
function OpenPlayerInvoiceDetail(inv)
  local gross = tonumber(inv.gross_amount) or 0
  local reminder = (inv.payment_status == 'overdue') and (tonumber(inv.reminder_fee) or 0) or 0
  local total = gross + reminder

  local metadata = {
    { label = 'Rechnungsnr.', value = inv.invoice_number },
    { label = 'Datum', value = Rechnungen.FormatDate(inv.created_at) },
    { label = 'Fällig am', value = Rechnungen.FormatDate(inv.due_date) },
    { label = 'Aussteller', value = inv.issuer_name or '-' },
    { label = 'Firma', value = inv.company_name or inv.issuer_job or '-' },
    { label = 'Grund', value = inv.reason },
    { label = 'Netto', value = Rechnungen.FormatMoney(inv.net_amount) },
    { label = 'Steuer', value = ('%s%% (%s)'):format(inv.tax_rate, Rechnungen.FormatMoney(inv.tax_amount)) },
    { label = 'Brutto', value = Rechnungen.FormatMoney(total) },
    { label = 'Status', value = Rechnungen.GetStatusLabel(inv.payment_status) }
  }

  if reminder > 0 then
    metadata[#metadata + 1] = { label = 'Mahngebühr', value = Rechnungen.FormatMoney(reminder) }
  end

  local options = {
    {
      title = 'Rechnungsdetails',
      icon = 'file-invoice',
      readOnly = true,
      metadata = metadata
    }
  }

  if inv.payment_status == 'open' or inv.payment_status == 'overdue' then
    options[#options + 1] = {
      title = 'Per Bank bezahlen',
      description = Rechnungen.FormatMoney(total),
      icon = 'credit-card',
      onSelect = function()
        TriggerServerEvent('esx_rechnungen:payInvoice', inv.id, 'bank')
        SetTimeout(600, OpenPlayerInvoiceList)
      end
    }
    options[#options + 1] = {
      title = 'Bar bezahlen',
      description = Rechnungen.FormatMoney(total),
      icon = 'money-bill',
      onSelect = function()
        TriggerServerEvent('esx_rechnungen:payInvoice', inv.id, 'cash')
        SetTimeout(600, OpenPlayerInvoiceList)
      end
    }
  end

  lib.registerContext({
    id = 'rechnungen_detail',
    title = inv.invoice_number,
    menu = 'rechnungen_list',
    options = options
  })

  lib.showContext('rechnungen_detail')
end
