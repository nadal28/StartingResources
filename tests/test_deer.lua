local checks = 0
local function check(condition) assert(condition); checks = checks + 1 end
local function array(values)
    return {ForEach = function(_, callback)
        for i, value in ipairs(values) do callback(i, {get = function() return value end}) end
    end}
end
local function row(values)
    return setmetatable({}, {__index = function(_, key) return values[key] end,
        __newindex = function(_, key, value)
            values[key] = key == 'averageProduction' and array(value) or value
        end})
end
local venison = {ItemCategory = 0, Subcategory = 0}
local small = {ItemCategory = 2, Subcategory = 6}
local camp = row({averageProduction = array({{Type=330,amt=100},{Type=9,amt=100}})})
local translation
local function text(value) return {ToString = function() return value end} end
local translations = {
    IsValid = function() return true end,
    FindRow = function() return translation end,
    AddRow = function(_, key, values)
        assert(key == 'ItemId_331')
        translation = {}; for k,v in pairs(values) do translation[k] = text(v) end
    end,
    RemoveRow = function(_, key) assert(key == 'ItemId_331'); translation = nil end,
    RowStruct = {ForEachProperty = function(_, callback)
        for _, language in ipairs({'en_US', 'es_ES', 'de_DE'}) do
            callback({GetFName = function() return text(language) end})
        end
    end},
}
LoadAsset = function(path)
    if path:find('DT_Translation_Items', 1, true) then return translations end
    return {IsValid = function() return true end, FindRow = function(_, id)
        if id == '331' then return venison elseif id == '330' then return small else return camp end
    end}
end
local function types()
    local result = {}
    camp.averageProduction:ForEach(function(_, item) local good=item:get();result[good.Type]=good.amt end)
    return result
end
local Deer = require('resource_setup_deer')
local owner = Deer.install()
local ids = types()
check(venison.ItemCategory == 2 and venison.Subcategory == 6)
check(ids[331] == 100 and ids[3] == 100 and ids[330] == 100 and ids[9] == 100)
check(translation.en_US:ToString() == 'Venison' and translation.es_ES:ToString() == 'Carne de venado'
    and translation.de_DE:ToString() == 'Venison')
-- Other mods can extend or edit the table without having their changes undone.
camp.averageProduction = {{Type=330,amt=101},{Type=9,amt=100},{Type=331,amt=100},{Type=3,amt=100},{Type=999,amt=5}}
owner.stop(); owner.stop(); ids = types()
check(venison.ItemCategory == 0 and venison.Subcategory == 0)
check(ids[330] == 101 and ids[999] == 5 and not ids[331] and not ids[3])
check(translation == nil)
camp.averageProduction = {{Type=330,amt=100},{Type=331,amt=75},{Type=3,amt=80}}
owner = Deer.install(); owner.stop(); ids = types()
check(ids[331] == 75 and ids[3] == 80)
owner = Deer.install()
venison.ItemCategory, venison.Subcategory = 8, 9
camp.averageProduction = {{Type=330,amt=100},{Type=331,amt=76},{Type=3,amt=80}}
owner.stop(); ids = types()
check(venison.ItemCategory == 8 and venison.Subcategory == 9 and ids[331] == 76)
-- A partial table-write failure must undo the preceding food classification.
venison.ItemCategory, venison.Subcategory = 0, 0
local original = array({{Type=330,amt=100},{Type=9,amt=100}})
local values, fail = {averageProduction=original}, true
camp = setmetatable({}, {__index=values, __newindex=function(_, key, value)
    if fail then fail=false; error('Simulated table write failure') end
    values[key] = key == 'averageProduction' and array(value) or value
end})
check(not pcall(Deer.install))
ids = types()
check(venison.ItemCategory == 0 and venison.Subcategory == 0 and not ids[331] and not ids[3])
check(translation == nil)
-- A shared translation owned by another mod is never replaced or removed.
translation = {en_US=text('Other venison'), es_ES=text('Otro nombre'), de_DE=text('Wild')}
local shared = translation
owner = Deer.install(); owner.stop()
check(translation == shared and translation.en_US:ToString() == 'Other venison')
translation = nil
owner = Deer.install(); translation.es_ES = text('Otro nombre'); owner.stop()
check(translation.es_ES:ToString() == 'Otro nombre')
-- If insertion throws after adding a row, roll back all our changes.
translation = nil
local addRow = translations.AddRow
translations.AddRow = function(...) addRow(...); error('Simulated insertion failure') end
check(not pcall(Deer.install))
check(translation == nil and venison.ItemCategory == 0 and venison.Subcategory == 0)
LoadAsset = function() return nil end
check(not pcall(Deer.install))
return checks
