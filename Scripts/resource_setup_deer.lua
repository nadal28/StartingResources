-- Re-enable the game's surviving venison/hide recipes and classify venison as
-- meat. Animal AI, hunting, crafting, inventories and saves remain native.
local Deer = {}
local function valid(object) return object and object:IsValid() end

local function goods(array)
    local result = {}
    array:ForEach(function(_, item)
        local good = item:get()
        result[#result + 1] = {Type = good.Type, amt = good.amt}
    end)
    return result
end

function Deer.install()
    local items = LoadAsset('/Game/NotStronghold/Data/DT_Items.DT_Items')
    local buildings = LoadAsset('/Game/NotStronghold/Data/buildingStats.buildingStats')
    local translations = LoadAsset('/Game/Translation/HoodedHorse/DT_Translation_Items.DT_Translation_Items')
    assert(valid(items) and valid(buildings) and valid(translations), 'Deer production tables unavailable')
    local venison, smallGame = items:FindRow('331'), items:FindRow('330')
    local camp = buildings:FindRow('14')
    assert(venison and smallGame and camp, 'Deer production rows unavailable')
    local originalCategory, originalSubcategory = venison.ItemCategory, venison.Subcategory
    local category, subcategory = smallGame.ItemCategory, smallGame.Subcategory
    local outputs, added = goods(camp.averageProduction), {}
    local found = {}
    for _, good in ipairs(outputs) do found[good.Type] = true end
    for _, id in ipairs({331, 3}) do
        if not found[id] then
            outputs[#outputs + 1] = {Type = id, amt = 100}
            added[id] = true
        end
    end
    -- Native widgets translate this key through the game's current language.
    -- Keep an official/other mod's row if it already exists. Unsupported
    -- languages use English instead of exposing the internal ItemId_331 key.
    local label, labelAdded = {}, false
    if not translations:FindRow('ItemId_331') then
        translations.RowStruct:ForEachProperty(function(property)
            local language = property:GetFName():ToString()
            label[language] = language == 'es_ES' and 'Carne de venado' or 'Venison'
        end)
    end
    local stopped = false
    local owner = {}
    function owner.stop()
        if stopped then return end
        stopped = true
        -- Keep any unrelated changes made by another mod after installation.
        local current, retained = goods(camp.averageProduction), {}
        for _, good in ipairs(current) do
            if not (added[good.Type] and good.amt == 100) then retained[#retained + 1] = good end
        end
        if next(added) then camp.averageProduction = retained end
        if venison.ItemCategory == category then venison.ItemCategory = originalCategory end
        if venison.Subcategory == subcategory then venison.Subcategory = originalSubcategory end
        if labelAdded then
            local current = translations:FindRow('ItemId_331')
            local unchanged = current ~= nil
            for language, text in pairs(label) do
                if not current or current[language]:ToString() ~= text then unchanged = false; break end
            end
            if unchanged then translations:RemoveRow('ItemId_331') end
        end
    end
    local ok, reason = pcall(function()
        venison.ItemCategory, venison.Subcategory = category, subcategory
        if next(added) then camp.averageProduction = outputs end
        if next(label) then
            labelAdded = true
            translations:AddRow('ItemId_331', label)
            assert(translations:FindRow('ItemId_331'), 'Venison translation could not be added')
        end
    end)
    if not ok then pcall(owner.stop); error(reason, 0) end
    return owner
end

return Deer
