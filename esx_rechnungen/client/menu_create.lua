--[[
    Rechnung erstellen (ox_lib)
]]

local createData = nil

--- Startet den Rechnungserstellungs-Flow
function OpenCreateInvoiceMenu()
  ESX.TriggerServerCallback('esx_rechnungen:canCreateInvoice', function(canCreate, result)
    if not canCreate then
      Rechnungen.Notify(result or 'Du darfst keine Rechnungen ausstellen.', 'error')
      return
    end

    createData = result
    OpenCreateRecipientMenu()
  end)
end

--- Empfängertyp wählen
function OpenCreateRecipientMenu()
  local settings = createData.settings or {}
  local options = {}

  if settings.can_issue_player == nil or settings.can_issue_player == 1 then
    options[#options + 1] = {
      title = 'An Spieler ausstellen',
      description = 'Rechnung an einen nahen Spieler',
      icon = 'user',
      onSelect = function()
        OpenCreatePlayerSelect()
      end
    }
  end

  if settings.can_issue_society == 1 then
    options[#options + 1] = {
      title = 'An Firma ausstellen',
      description = 'Rechnung an eine Society / Firma',
      icon = 'building',
      onSelect = function()
        OpenCreateSocietySelect()
      end
    }
  end

  if #options == 0 then
    Rechnungen.Notify('Dein Job darf keine Rechnungen ausstellen.', 'error')
    return
  end

  lib.registerContext({
    id = 'rechnung_create_main',
    title = 'Rechnung ausstellen',
    description = createData.job and createData.job.label or '',
    options = options
  })

  lib.showContext('rechnung_create_main')
end

--- Spieler in der Nähe auswählen
function OpenCreatePlayerSelect()
  ESX.TriggerServerCallback('esx_rechnungen:getNearbyPlayers', function(players)
    local options = {}

    if not players or #players == 0 then
      options[#options + 1] = {
        title = 'Keine Spieler in der Nähe',
        icon = 'user-slash',
        readOnly = true
      }
    else
      for _, p in ipairs(players) do
        options[#options + 1] = {
          title = p.name,
          description = ('Entfernung: %.1fm'):format(p.distance),
          icon = 'user',
          onSelect = function()
            OpenCreateInvoiceForm('player', { target_id = p.source })
          end
        }
      end
    end

    lib.registerContext({
      id = 'rechnung_create_player',
      title = 'Spieler auswählen',
      menu = 'rechnung_create_main',
      options = options
    })

    lib.showContext('rechnung_create_player')
  end)
end

--- Firma auswählen
function OpenCreateSocietySelect()
  ESX.TriggerServerCallback('esx_rechnungen:getSocieties', function(societies)
    local options = {}

    for _, s in ipairs(societies or {}) do
      options[#options + 1] = {
        title = s.label,
        description = s.name,
        icon = 'building',
        onSelect = function()
          OpenCreateInvoiceForm('society', { society_name = s.name })
        end
      }
    end

    if #options == 0 then
      options[#options + 1] = {
        title = 'Keine Firmen verfügbar',
        readOnly = true
      }
    end

    lib.registerContext({
      id = 'rechnung_create_society',
      title = 'Firma auswählen',
      menu = 'rechnung_create_main',
      options = options
    })

    lib.showContext('rechnung_create_society')
  end)
end

--- Rechnungsformular (ox_lib inputDialog)
---@param recipientType string
---@param extra table
function OpenCreateInvoiceForm(recipientType, extra)
  local taxRate = createData.settings and createData.settings.tax_rate or 19.0

  local input = lib.inputDialog('Rechnung ausstellen', {
    {
      type = 'input',
      label = 'Rechnungsgrund',
      description = 'z.B. Reparatur, Behandlung, Dienstleistung',
      required = true,
      min = 3,
      max = 500
    },
    {
      type = 'number',
      label = 'Netto-Betrag (€)',
      required = true,
      min = 1,
      default = 100
    },
    {
      type = 'number',
      label = 'Steuersatz (%)',
      default = taxRate,
      min = 0,
      max = 100
    }
  })

  if not input then return end

  local data = {
    recipient_type = recipientType,
    reason = input[1],
    net_amount = input[2],
    tax_rate = input[3]
  }

  if recipientType == 'player' then
    data.target_id = extra.target_id
  else
    data.society_name = extra.society_name
  end

  TriggerServerEvent('esx_rechnungen:createInvoice', data)
end
