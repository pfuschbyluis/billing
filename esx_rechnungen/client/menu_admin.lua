--[[
    Adminpanel (ox_lib Context-Menüs)
]]

local adminInvoices = {}

--- Hauptmenü Admin
function OpenAdminMenu()
  lib.registerContext({
    id = 'rechnung_admin_main',
    title = 'Rechnungs-Adminpanel',
    options = {
      {
        title = 'Rechnungen',
        description = 'Alle Rechnungen verwalten',
        icon = 'file-invoice',
        arrow = true,
        onSelect = OpenAdminInvoiceList
      },
      {
        title = 'Jobs',
        description = 'Berechtigungen & Einstellungen pro Job',
        icon = 'briefcase',
        arrow = true,
        onSelect = OpenAdminJobList
      },
      {
        title = 'Firmen',
        description = 'Steuerdaten & Firmeninformationen',
        icon = 'building',
        arrow = true,
        onSelect = OpenAdminSocietyList
      },
      {
        title = 'Einstellungen',
        description = 'Globale Systemkonfiguration',
        icon = 'gear',
        arrow = true,
        onSelect = OpenAdminSettingsMenu
      }
    }
  })

  lib.showContext('rechnung_admin_main')
end

-- ============================================================
-- Rechnungen (Admin)
-- ============================================================

function OpenAdminInvoiceList()
  ESX.TriggerServerCallback('esx_rechnungen:getAllInvoices', function(invoices)
    adminInvoices = invoices or {}
    local options = {}

    options[#options + 1] = {
      title = 'Aktualisieren',
      icon = 'arrows-rotate',
      onSelect = OpenAdminInvoiceList
    }

    if #adminInvoices == 0 then
      options[#options + 1] = {
        title = 'Keine Rechnungen',
        icon = 'inbox',
        readOnly = true
      }
    else
      for _, inv in ipairs(adminInvoices) do
        options[#options + 1] = {
          title = inv.invoice_number,
          description = ('%s → %s'):format(inv.issuer_name or '-', inv.recipient_name or '-'),
          icon = Rechnungen.GetStatusIcon(inv.payment_status),
          arrow = true,
          metadata = {
            { label = 'Betrag', value = Rechnungen.FormatMoney(inv.gross_amount) },
            { label = 'Status', value = Rechnungen.GetStatusLabel(inv.payment_status) },
            { label = 'Grund', value = inv.reason }
          },
          onSelect = function()
            OpenAdminInvoiceDetail(inv)
          end
        }
      end
    end

    lib.registerContext({
      id = 'rechnung_admin_invoices',
      title = 'Rechnungsverwaltung',
      menu = 'rechnung_admin_main',
      options = options
    })

    lib.showContext('rechnung_admin_invoices')
  end)
end

---@param inv table
function OpenAdminInvoiceDetail(inv)
  local options = {
    {
      title = 'Details',
      icon = 'circle-info',
      readOnly = true,
      metadata = {
        { label = 'Nr.', value = inv.invoice_number },
        { label = 'Aussteller', value = inv.issuer_name or '-' },
        { label = 'Empfänger', value = inv.recipient_name or '-' },
        { label = 'Grund', value = inv.reason },
        { label = 'Netto', value = Rechnungen.FormatMoney(inv.net_amount) },
        { label = 'Brutto', value = Rechnungen.FormatMoney(inv.gross_amount) },
        { label = 'Status', value = Rechnungen.GetStatusLabel(inv.payment_status) },
        { label = 'Datum', value = Rechnungen.FormatDate(inv.created_at) }
      }
    },
    {
      title = 'Bearbeiten',
      icon = 'pen-to-square',
      onSelect = function()
        OpenAdminEditInvoice(inv)
      end
    },
    {
      title = 'Stornieren',
      icon = 'ban',
      onSelect = function()
        OpenAdminCancelInvoice(inv)
      end
    },
    {
      title = 'Löschen',
      icon = 'trash',
      onSelect = function()
        OpenAdminDeleteInvoice(inv)
      end
    }
  }

  lib.registerContext({
    id = 'rechnung_admin_invoice_detail',
    title = inv.invoice_number,
    menu = 'rechnung_admin_invoices',
    options = options
  })

  lib.showContext('rechnung_admin_invoice_detail')
end

---@param inv table
function OpenAdminEditInvoice(inv)
  local input = lib.inputDialog('Rechnung bearbeiten', {
    { type = 'input', label = 'Rechnungsgrund', default = inv.reason, required = true },
    { type = 'number', label = 'Netto-Betrag (€)', default = tonumber(inv.net_amount), required = true, min = 0 },
    { type = 'number', label = 'Steuersatz (%)', default = tonumber(inv.tax_rate), min = 0, max = 100 },
    {
      type = 'select',
      label = 'Status',
      default = inv.payment_status,
      options = {
        { value = 'open', label = 'Offen' },
        { value = 'paid', label = 'Bezahlt' },
        { value = 'overdue', label = 'Überfällig' },
        { value = 'cancelled', label = 'Storniert' }
      }
    }
  })

  if not input then return end

  TriggerServerEvent('esx_rechnungen:editInvoice', inv.id, {
    reason = input[1],
    net_amount = input[2],
    tax_rate = input[3],
    payment_status = input[4]
  })

  SetTimeout(500, OpenAdminInvoiceList)
end

---@param inv table
function OpenAdminCancelInvoice(inv)
  local input = lib.inputDialog('Rechnung stornieren', {
    { type = 'input', label = 'Stornierungsgrund (optional)', default = 'Storniert durch Admin' }
  })

  if input == nil then return end

  local confirm = lib.alertDialog({
    header = 'Stornierung bestätigen',
    content = ('Rechnung **%s** wirklich stornieren?'):format(inv.invoice_number),
    centered = true,
    cancel = true
  })

  if confirm ~= 'confirm' then return end

  TriggerServerEvent('esx_rechnungen:cancelInvoice', inv.id, input[1] or '')
  SetTimeout(500, OpenAdminInvoiceList)
end

---@param inv table
function OpenAdminDeleteInvoice(inv)
  local confirm = lib.alertDialog({
    header = 'Rechnung löschen',
    content = ('Rechnung **%s** unwiderruflich löschen?'):format(inv.invoice_number),
    centered = true,
    cancel = true
  })

  if confirm ~= 'confirm' then return end

  TriggerServerEvent('esx_rechnungen:deleteInvoice', inv.id)
  SetTimeout(500, OpenAdminInvoiceList)
end

-- ============================================================
-- Jobs (Admin)
-- ============================================================

function OpenAdminJobList()
  ESX.TriggerServerCallback('esx_rechnungen:getJobSettings', function(result)
    local jobs = result.jobs or {}
    local settings = result.settings or {}
    local options = {}

    for _, job in ipairs(jobs) do
      local configured = settings[job.name] ~= nil
      options[#options + 1] = {
        title = job.label,
        description = configured and 'Konfiguriert' or 'Noch nicht eingerichtet',
        icon = configured and 'circle-check' or 'briefcase',
        arrow = true,
        onSelect = function()
          OpenAdminJobEdit(job, settings[job.name])
        end
      }
    end

    lib.registerContext({
      id = 'rechnung_admin_jobs',
      title = 'Job-Einstellungen',
      menu = 'rechnung_admin_main',
      options = options
    })

    lib.showContext('rechnung_admin_jobs')
  end)
end

---@param job table
---@param settings table|nil
function OpenAdminJobEdit(job, settings)
  settings = settings or {}

  lib.registerContext({
    id = 'rechnung_admin_job_edit',
    title = job.label,
    menu = 'rechnung_admin_jobs',
    options = {
      {
        title = 'Einstellungen bearbeiten',
        icon = 'pen-to-square',
        onSelect = function()
          OpenAdminJobForm(job, settings)
        end
      },
      {
        title = 'Einstellungen löschen',
        icon = 'trash',
        onSelect = function()
          local confirm = lib.alertDialog({
            header = 'Job-Einstellungen löschen',
            content = ('Einstellungen für **%s** wirklich löschen?'):format(job.label),
            centered = true,
            cancel = true
          })
          if confirm == 'confirm' then
            TriggerServerEvent('esx_rechnungen:deleteJobSettings', job.name)
            SetTimeout(400, OpenAdminJobList)
          end
        end
      }
    }
  })

  lib.showContext('rechnung_admin_job_edit')
end

---@param job table
---@param settings table
function OpenAdminJobForm(job, settings)
  local input = lib.inputDialog('Job: ' .. job.label, {
    { type = 'checkbox', label = 'Rechnungen schreiben dürfen', checked = settings.can_issue == 1 },
    { type = 'checkbox', label = 'An Spieler ausstellen', checked = settings.can_issue_player == nil or settings.can_issue_player == 1 },
    { type = 'checkbox', label = 'An Firmen ausstellen', checked = settings.can_issue_society == 1 },
    { type = 'number', label = 'Maximaler Rechnungsbetrag (€)', default = tonumber(settings.max_amount) or 10000, min = 1 },
    { type = 'checkbox', label = 'Nur in der Nähe ausstellen', checked = settings.require_proximity == nil or settings.require_proximity == 1 },
    { type = 'number', label = 'Maximale Entfernung (m)', default = tonumber(settings.max_distance) or 5.0, min = 0 },
    { type = 'checkbox', label = 'Bankzahlung erlaubt', checked = settings.payment_bank == nil or settings.payment_bank == 1 },
    { type = 'checkbox', label = 'Barzahlung erlaubt', checked = settings.payment_cash == nil or settings.payment_cash == 1 },
    {
      type = 'select',
      label = 'Geldziel',
      default = settings.money_destination or 'society',
      options = {
        { value = 'society', label = 'An die Society / Firma' },
        { value = 'employee', label = 'An den Mitarbeiter' },
        { value = 'split', label = 'Prozentual aufteilen' }
      }
    },
    { type = 'number', label = 'Society-Anteil (%)', default = tonumber(settings.society_percent) or 70, min = 0, max = 100 },
    { type = 'number', label = 'Mitarbeiter-Anteil (%)', default = tonumber(settings.employee_percent) or 30, min = 0, max = 100 },
    { type = 'number', label = 'Steuersatz (%)', default = tonumber(settings.tax_rate) or 19.0, min = 0, max = 100 }
  })

  if not input then return end

  TriggerServerEvent('esx_rechnungen:saveJobSettings', {
    job_name = job.name,
    can_issue = input[1],
    can_issue_player = input[2],
    can_issue_society = input[3],
    max_amount = input[4],
    require_proximity = input[5],
    max_distance = input[6],
    payment_bank = input[7],
    payment_cash = input[8],
    money_destination = input[9],
    society_percent = input[10],
    employee_percent = input[11],
    tax_rate = input[12]
  })

  SetTimeout(400, OpenAdminJobList)
end

-- ============================================================
-- Firmen (Admin)
-- ============================================================

function OpenAdminSocietyList()
  ESX.TriggerServerCallback('esx_rechnungen:getAllSocieties', function(societies)
    ESX.TriggerServerCallback('esx_rechnungen:getSocietyInfo', function(infoCache)
      local options = {}

      for _, soc in ipairs(societies or {}) do
        local configured = infoCache[soc.name] ~= nil
        options[#options + 1] = {
          title = soc.label,
          description = configured and 'Daten hinterlegt' or 'Noch nicht eingerichtet',
          icon = configured and 'circle-check' or 'building',
          arrow = true,
          onSelect = function()
            OpenAdminSocietyEdit(soc, infoCache[soc.name])
          end
        }
      end

      lib.registerContext({
        id = 'rechnung_admin_societies',
        title = 'Firmendaten',
        menu = 'rechnung_admin_main',
        options = options
      })

      lib.showContext('rechnung_admin_societies')
    end)
  end)
end

---@param soc table
---@param info table|nil
function OpenAdminSocietyEdit(soc, info)
  info = info or {}

  lib.registerContext({
    id = 'rechnung_admin_society_edit',
    title = soc.label,
    menu = 'rechnung_admin_societies',
    options = {
      {
        title = 'Firmendaten bearbeiten',
        icon = 'pen-to-square',
        onSelect = function()
          OpenAdminSocietyForm(soc, info)
        end
      },
      {
        title = 'Firmendaten löschen',
        icon = 'trash',
        onSelect = function()
          local confirm = lib.alertDialog({
            header = 'Firmendaten löschen',
            content = ('Daten für **%s** wirklich löschen?'):format(soc.label),
            centered = true,
            cancel = true
          })
          if confirm == 'confirm' then
            TriggerServerEvent('esx_rechnungen:deleteSocietyInfo', soc.name)
            SetTimeout(400, OpenAdminSocietyList)
          end
        end
      }
    }
  })

  lib.showContext('rechnung_admin_society_edit')
end

---@param soc table
---@param info table
function OpenAdminSocietyForm(soc, info)
  local input = lib.inputDialog('Firma: ' .. soc.label, {
    { type = 'input', label = 'Firmenname', default = info.company_name or '' },
    { type = 'textarea', label = 'Firmenadresse', default = info.company_address or '' },
    { type = 'input', label = 'Steuernummer', default = info.tax_id or '' },
    { type = 'input', label = 'Umsatzsteuer-ID', default = info.vat_id or '' },
    { type = 'input', label = 'Rechnungspräfix', default = info.invoice_prefix or 'RE', max = 10 }
  })

  if not input then return end

  TriggerServerEvent('esx_rechnungen:saveSocietyInfo', {
    society_name = soc.name,
    company_name = input[1],
    company_address = input[2],
    tax_id = input[3],
    vat_id = input[4],
    invoice_prefix = input[5] or 'RE'
  })

  SetTimeout(400, OpenAdminSocietyList)
end

-- ============================================================
-- Globale Einstellungen (Admin)
-- ============================================================

function OpenAdminSettingsMenu()
  lib.registerContext({
    id = 'rechnung_admin_settings',
    title = 'Globale Einstellungen',
    menu = 'rechnung_admin_main',
    options = {
      {
        title = 'Discord & Logging',
        icon = 'comment',
        onSelect = OpenAdminSettingsDiscord
      },
      {
        title = 'Steuersystem',
        icon = 'percent',
        onSelect = OpenAdminSettingsTax
      },
      {
        title = 'Rechnungsnummern & Fristen',
        icon = 'hashtag',
        onSelect = OpenAdminSettingsInvoices
      },
      {
        title = 'Admin-Berechtigungen',
        icon = 'shield',
        onSelect = OpenAdminSettingsPermissions
      }
    }
  })

  lib.showContext('rechnung_admin_settings')
end

local function boolSetting(val)
  return val == 'true' or val == true
end

function OpenAdminSettingsDiscord()
  ESX.TriggerServerCallback('esx_rechnungen:getGlobalSettings', function(s)
    if not s then return end

    local input = lib.inputDialog('Discord-Logging', {
      { type = 'checkbox', label = 'Discord-Logs aktiviert', checked = boolSetting(s.discord_enabled) },
      { type = 'input', label = 'Discord-Webhook URL', default = s.discord_webhook or '' }
    })

    if not input then return end

    TriggerServerEvent('esx_rechnungen:saveGlobalSettings', {
      discord_enabled = input[1],
      discord_webhook = input[2] or ''
    })
  end)
end

function OpenAdminSettingsTax()
  ESX.TriggerServerCallback('esx_rechnungen:getGlobalSettings', function(s)
    if not s then return end

    local input = lib.inputDialog('Steuersystem', {
      { type = 'checkbox', label = 'Steuern aktiviert', checked = boolSetting(s.tax_enabled) },
      { type = 'number', label = 'Standard-Steuersatz (%)', default = tonumber(s.default_tax_rate) or 19, min = 0, max = 100 }
    })

    if not input then return end

    TriggerServerEvent('esx_rechnungen:saveGlobalSettings', {
      tax_enabled = input[1],
      default_tax_rate = input[2]
    })
  end)
end

function OpenAdminSettingsInvoices()
  ESX.TriggerServerCallback('esx_rechnungen:getGlobalSettings', function(s)
    if not s then return end

    local input = lib.inputDialog('Rechnungen & Fristen', {
      { type = 'checkbox', label = 'Automatische Rechnungsnummern', checked = boolSetting(s.auto_invoice_numbers) },
      { type = 'input', label = 'Standard-Präfix', default = s.invoice_prefix or 'RE', max = 10 },
      { type = 'number', label = 'Zahlungsfrist (Tage)', default = tonumber(s.payment_deadline_days) or 14, min = 1 },
      { type = 'number', label = 'Mahngebühr (€)', default = tonumber(s.reminder_fee) or 25, min = 0 },
      { type = 'checkbox', label = 'Unbezahlte Rechnungen beim Login anzeigen', checked = boolSetting(s.show_unpaid_on_login) }
    })

    if not input then return end

    TriggerServerEvent('esx_rechnungen:saveGlobalSettings', {
      auto_invoice_numbers = input[1],
      invoice_prefix = input[2],
      payment_deadline_days = input[3],
      reminder_fee = input[4],
      show_unpaid_on_login = input[5]
    })
  end)
end

function OpenAdminSettingsPermissions()
  ESX.TriggerServerCallback('esx_rechnungen:getGlobalSettings', function(s)
    if not s then return end

    local input = lib.inputDialog('Admin-Berechtigungen', {
      { type = 'checkbox', label = 'Rechnungen einsehen', checked = boolSetting(s.admin_can_view) },
      { type = 'checkbox', label = 'Rechnungen bearbeiten', checked = boolSetting(s.admin_can_edit) },
      { type = 'checkbox', label = 'Rechnungen stornieren', checked = boolSetting(s.admin_can_cancel) },
      { type = 'checkbox', label = 'Rechnungen löschen', checked = boolSetting(s.admin_can_delete) }
    })

    if not input then return end

    TriggerServerEvent('esx_rechnungen:saveGlobalSettings', {
      admin_can_view = input[1],
      admin_can_edit = input[2],
      admin_can_cancel = input[3],
      admin_can_delete = input[4]
    })
  end)
end
