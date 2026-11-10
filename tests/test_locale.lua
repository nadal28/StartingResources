local Locale = require('resource_setup_locale')
local Model = require('resource_setup_model')
local checks = 0
local function check(condition, message)
    assert(condition, message)
    checks = checks + 1
end

for tag, expected in pairs({es = 'es', ['es-ES'] = 'es', ['es-419'] = 'es',
    ES_mx = 'es', en = 'en', ['en-GB'] = 'en', fr = 'en', de = 'en', [''] = 'en'}) do
    check(Locale.language(tag) == expected, 'Incorrect language: ' .. tag)
end
check(Locale.language(nil) == 'en')
check(Locale.language(false) == 'en')
for language, catalog in pairs(Locale.catalogs) do
    for key in pairs(Locale.catalogs.en) do
        check(type(catalog[key]) == 'string' and #catalog[key] > 0, language .. ': missing ' .. key)
    end
    for key in pairs(catalog) do check(Locale.catalogs.en[key] ~= nil, 'Unknown translation key') end
    for _, resource in ipairs(Model.options()) do
        check(#Locale.text(language, resource.key) > 0, 'Resource missing translation')
    end
    for count = 0, 2 do check(Locale.text(language, 'count', count):find(tostring(count), 1, true)) end
end
check(Locale.text('fr', 'title') == 'Starting resources', 'Unsupported language did not fall back')
local translated = Locale.catalogs.es.Iron
Locale.catalogs.es.Iron = nil
check(Locale.text('es', 'Iron') == 'Iron', 'Missing translation did not fall back')
Locale.catalogs.es.Iron = translated
check(not pcall(Locale.text, 'en', 'unknown'), 'Invalid key silently accepted')

local tag, calls = 'es-ES', 0
StaticFindObject = function() error('Unreal language does not select the game text language') end
FindFirstOf = function(class)
    check(class == 'MLGameInstance')
    return {IsValid = function() return true end, Settings = {lang_txt = {ToString = function()
        calls = calls + 1
        return tag
    end}}}
end
check(Locale.current() == 'es')
tag = 'en'; check(Locale.current() == 'en')
tag = 'fr'; check(Locale.current() == 'en')
tag = 'es-MX'; check(Locale.current() == 'es' and calls == 4, 'Language changes were cached')
check(select(2, Locale.current()) == 'es-MX', 'Raw game tag was lost')
FindFirstOf = function() return nil end
check(Locale.current() == 'en', 'Missing game instance prevented fallback')
FindFirstOf = function() return {IsValid = function() return false end} end
check(Locale.current() == 'en', 'Invalid game instance prevented fallback')
FindFirstOf = function() return {IsValid = function() return true end, Settings = {}} end
check(Locale.current() == 'en', 'Missing game settings prevented fallback')
FindFirstOf = function() error('Unavailable engine') end
check(Locale.current() == 'en', 'Engine error prevented fallback')
return checks
