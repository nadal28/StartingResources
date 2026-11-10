local Model = {}

-- Native ENodeType values. Fertility is a regional strength, not a deposit.
Model.resources = {
    {id = 1, key = 'Salt', icon = 'ml_map_resource_0003_salt'},
    {id = 2, key = 'Iron', icon = 'ml_map_resource_0000_iron'},
    {id = 3, key = 'Clay', icon = 'ml_map_resource_0002_clay'},
    {id = 5, key = 'Fish', icon = 'ml_map_resource_0006_fish'},
    {id = 6, key = 'Berries', icon = 'ml_map_resource_0004_berries'},
    {id = 7, key = 'Stone', icon = 'ml_map_resource_0001_stone'},
    {id = 9, key = 'Mushrooms', icon = 'mushroom-gills'},
    {id = 10, key = 'SmallGame', icon = 'paw'},
    {id = 12, key = 'Fertility', icon = 'wheat'},
}
Model.maxChoices = 2
Model.byID, Model.byKey = {}, {}
for _, resource in ipairs(Model.resources) do
    Model.byID[resource.id] = resource
    Model.byKey[resource.key] = resource
end

function Model.mask(selected)
    assert(type(selected) == 'table', 'La selección debe ser una tabla')
    local mask, count = 0, 0
    for id, chosen in pairs(selected) do
        if chosen then
            assert(Model.byID[id], 'Ventaja no compatible: ' .. tostring(id))
            mask, count = mask | (1 << id), count + 1
        end
    end
    assert(count <= Model.maxChoices, 'Puedes elegir hasta dos ventajas regionales')
    return mask, count
end

function Model.decode(mask)
    assert(type(mask) == 'number' and math.tointeger(mask) and mask >= 0,
        'Invalid resource selection')
    local selected = {}
    for _, resource in ipairs(Model.resources) do
        if mask & (1 << resource.id) ~= 0 then selected[resource.id] = true end
    end
    local decoded = Model.mask(selected)
    assert(decoded == mask, 'Unsupported resource selection')
    return selected
end

function Model.fromConfig(config)
    assert(type(config.Enabled) == 'boolean', 'Enabled debe ser true o false')
    assert(type(config.CustomByDefault) == 'boolean', 'CustomByDefault debe ser true o false')
    local selected = {}
    if not config.Enabled then return {custom = config.CustomByDefault, selected = selected} end
    for _, key in ipairs(config.DefaultRichResources or {}) do
        local resource = assert(Model.byKey[key], 'Recurso no compatible: ' .. tostring(key))
        selected[resource.id] = true
    end
    Model.mask(selected)
    return {custom = config.CustomByDefault, selected = selected}
end

function Model.ordered(selected)
    Model.mask(selected)
    local choices = {}
    for _, resource in ipairs(Model.resources) do
        if selected[resource.id] then choices[#choices + 1] = resource.id end
    end
    return choices
end

function Model.options(exclude)
    local options = {{id = 0, key = 'None'}}
    for _, resource in ipairs(Model.resources) do
        if resource.id ~= exclude then options[#options + 1] = resource end
    end
    return options
end

function Model.fromSlots(first, second)
    assert(first == 0 or Model.byID[first], 'Primera ventaja no compatible')
    assert(second == 0 or Model.byID[second], 'Segunda ventaja no compatible')
    if first ~= 0 and first == second then second = 0 end
    local selected = {}
    if first ~= 0 then selected[first] = true end
    if second ~= 0 then selected[second] = true end
    return selected, second
end

return Model
