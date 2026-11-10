local Model = require('resource_setup_model')
local Native = {}

function Native.new(root, log)
    local path = root .. '/native/StartingResources-0.1.1.dll'
    local entry = {}
    for _, name in ipairs({'Init', 'Arm', 'Disarm', 'Stop'}) do
        entry[name] = assert(package.loadlib(path, 'SR_' .. name),
            'No se puede cargar el adaptador ' .. name)
    end

    local function status()
        local file = assert(io.open(root .. '/native-status.txt', 'r'))
        local text = file:read('*a')
        file:close()
        return text
    end

    -- Init may install hooks before its status can be read. Roll them back if
    -- anything fails before ownership is handed to the runtime.
    local ok, reason = pcall(function()
        entry.Init()
        local text = status()
        assert(text:match('^READY\n'), 'Adaptador no disponible: ' .. text:match('[^\n]+'))
    end)
    if not ok then
        pcall(entry.Stop)
        error(reason, 0)
    end

    local stopped = false
    local native = {status = status}
    function native.arm(instance, mask)
        assert(not stopped, 'El adaptador ya está detenido')
        Model.decode(mask)
        assert(mask ~= 0, 'No hay ventajas seleccionadas')
        local file = assert(io.open(root .. '/selection.txt', 'w'))
        local written, writeError = file:write('SR1 ', tostring(mask), ' ',
            string.format('%x', instance:GetAddress()), '\n')
        local closed, closeError = file:close()
        assert(written and closed, writeError or closeError)
        entry.Arm()
        local text = status()
        assert(text:match('^ARMED '), 'La selección no se pudo aplicar: ' .. text:match('[^\n]+'))
        log('ARMED mask=' .. mask)
    end
    function native.disarm()
        if not stopped then entry.Disarm() end
    end
    function native.stop()
        if stopped then return end
        entry.Stop()
        stopped = true
    end
    return native
end

return Native
