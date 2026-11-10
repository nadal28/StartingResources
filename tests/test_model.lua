local Model = require('resource_setup_model')
local Preferences = require('resource_setup_preferences')
local count = 0
local function check(condition, message)
    assert(condition, message)
    count = count + 1
end
local function rejected(fn)
    check(not pcall(fn), 'Invalid selection accepted')
end

local ids = {0}
for _, resource in ipairs(Model.resources) do ids[#ids + 1] = resource.id end
for _, first in ipairs(ids) do
    for _, second in ipairs(ids) do
        local selected, normalized = Model.fromSlots(first, second)
        local mask, size = Model.mask(selected)
        check(size <= 2)
        check(normalized == ((first ~= 0 and first == second) and 0 or second))
        check(Model.mask(Model.decode(mask)) == mask)
        for _, custom in ipairs({true, false}) do
            local state = {custom = custom, selected = selected}
            local decoded = Preferences.decode(Preferences.encode(state))
            check(decoded.custom == custom and Model.mask(decoded.selected) == mask)
        end
        local options = Model.options(first)
        local seen = {}
        for _, option in ipairs(options) do
            check(not seen[option.id], 'Duplicate option')
            check(option.id == 0 or option.id ~= first, 'Excluded resource still selectable')
            seen[option.id] = true
        end
    end
end
for _, mask in ipairs({-1, 1.5, math.huge, 1, 256, 2048, 8192, 14}) do
    rejected(function() Model.decode(mask) end)
end
rejected(function() Model.mask({[8] = true}) end)
rejected(function() Model.fromSlots(8, 0) end)
rejected(function() Model.fromConfig({Enabled = true, CustomByDefault = true, DefaultRichResources = {'Unknown'}}) end)
for _, text in ipairs({'', 'SR2 1 4', 'SR1 2 4', 'SR1 1 8192', 'SR1 1 14', 'SR1 1 99999999999999999999999999'}) do
    rejected(function() Preferences.decode(text) end)
end
local legacy = Preferences.decode('SR1 1 1152\n')
check(legacy.custom and legacy.selected[7] and legacy.selected[10], 'Existing preferences lost')
local fertile = Preferences.decode('SR1 1 4100\n')
check(fertile.selected[2] and fertile.selected[12], 'Fertility lost')
local deer = Preferences.decode('SR1 1 20\n')
check(deer.selected[2] and deer.selected[4], 'Deer preferences lost')
local config = Model.fromConfig({Enabled = true, CustomByDefault = true, DefaultRichResources = {'Deer', 'SmallGame'}})
check(Model.mask(config.selected) == 1040, 'Deer and small game are not distinct choices')
return count
