local Model = require('resource_setup_model')
local Preferences = {}

-- Keep SR1 compatible with existing installations; it stores an unordered set.
function Preferences.decode(text)
    local custom, mask = text:match('^SR1 ([01]) (%d+)%s*$')
    assert(custom and mask, 'Formato de preferencias no compatible')
    local number = assert(math.tointeger(tonumber(mask)), 'Máscara de preferencias no válida')
    return {custom = custom == '1', selected = Model.decode(number)}
end

function Preferences.encode(state)
    assert(type(state.custom) == 'boolean', 'Modo de selección no válido')
    local mask = Model.mask(state.selected)
    return string.format('SR1 %d %d\n', state.custom and 1 or 0, mask)
end

function Preferences.load(path, fallback)
    local file = io.open(path, 'r')
    if not file then return fallback end
    local text = file:read('*a')
    file:close()
    local ok, state = pcall(Preferences.decode, text)
    if ok then return state end
    return fallback, state
end

function Preferences.save(path, state)
    local text = Preferences.encode(state)
    local file, reason = io.open(path, 'w')
    if not file then return nil, reason end
    local written, writeError = file:write(text)
    local closed, closeError = file:close()
    if not written then return nil, writeError end
    if not closed then return nil, closeError end
    return true
end

return Preferences
