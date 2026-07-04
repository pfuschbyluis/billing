Locales = Locales or {}
Config = Config or {}

local function GetLocale()
    return Config.Locale or 'de'
end

function _U(key, ...)
    local locale = GetLocale()
    local str = Locales[locale] and Locales[locale][key]
        or (Locales['de'] and Locales['de'][key])
        or key

    if select('#', ...) > 0 then
        return string.format(str, ...)
    end
    return str
end
