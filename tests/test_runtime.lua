local Model = require('resource_setup_model')
local checks = 0
local function check(condition, message)
    assert(condition, message)
    checks = checks + 1
end
local config = {Enabled = true, CustomByDefault = false, DefaultRichResources = {'Iron', 'Berries'}}

local function harness(options)
    local h = {options = options or {}, logs = {}, armed = {}, stops = 0, disarms = 0,
        removed = 0, cancelled = 0, unregistered = 0, registers = 0, custom = false,
        selected = {[2] = true, [6] = true}, writes = 0, nativeCreated = 0}
    local object = {IsValid = function() return true end}
    h.setup = {IsValid = object.IsValid, WidgetTree = object, SettingsScrollBox = object}
    h.instance = {IsValid = object.IsValid, GetAddress = function() return 42 end,
        savefileToLoad = {ToString = function() return h.options.loading and 'save' or '' end}}
    io.open = function(_, mode)
        if mode == 'r' then
            if not h.file then return nil end
            return {read = function() return h.file end, close = function() return true end}
        end
        if h.options.writeFail then return nil, 'Read-only directory' end
        return {write = function(_, ...)
            h.file = table.concat({...}); h.writes = h.writes + 1; return true
        end, close = function() return true end}
    end
    h.file = h.options.preferences
    package.loaded.resource_setup_view = {
        build = function()
            h.view = {root = object, setup = h.setup,
                read = function()
                    if h.options.readFail then error('Widget failed') end
                    return h.custom, h.selected
                end,
                refresh = function() h.refreshed = true end}
            return h.view
        end,
        remove = function() h.removed = h.removed + 1 end,
    }
    package.loaded.resource_setup_native = {new = function()
        h.nativeCreated = h.nativeCreated + 1
        return {
            arm = function(_, mask)
                if h.options.armFail then error('Native arm failed') end
                h.armed[#h.armed + 1] = mask
            end,
            disarm = function() h.disarms = h.disarms + 1 end,
            stop = function() h.stops = h.stops + 1 end,
        }
    end}
    package.loaded.resource_setup_deer = {install = function()
        h.deerInstalled = true
        return {stop = function() h.deerStopped = true end}
    end}
    NotifyOnNewObject = function(_, callback)
        if h.options.notifyFail then error('Notification registration failed') end
        h.notify = callback
    end
    RegisterLoadMapPreHook = function(callback) h.map = callback end
    RegisterHook = function(_, callback)
        h.registers = h.registers + 1
        if h.options.hookFail and h.registers == 2 then error('Second hook failed') end
        h.lastHook = callback
        return h.registers, h.registers + 10
    end
    UnregisterHook = function() h.unregistered = h.unregistered + 1 end
    CancelDelayedAction = function() h.cancelled = h.cancelled + 1 end
    ExecuteInGameThread = function(callback) callback() end
    LoopInGameThreadWithDelay = function(_, callback) h.tick = callback; return 123 end
    FindAllOf = function() return {h.setup} end
    StaticFindObject = function() return object end
    FindFirstOf = function() return h.instance end
    package.loaded.resource_setup_runtime = nil
    local Runtime = require('resource_setup_runtime')
    function h.install(cfg)
        return Runtime.install('/test', cfg or config, function(line) h.logs[#h.logs + 1] = line end)
    end
    return h
end

-- Clicking Play before the poll must persist and arm the latest selection.
local h = harness()
local owner = h.install()
h.tick()
h.custom, h.selected = true, {[2] = true, [12] = true}
owner.arm()
check(h.file == 'SR1 1 4100\n', 'Immediate Play did not save preferences')
check(h.armed[1] == 4100 and h.refreshed)
owner.unload(); owner.unload()
check(h.stops == 1 and h.removed == 1 and h.cancelled == 1 and h.unregistered == 2 and h.deerStopped)
check(h.notify(h.setup) == true and h.tick() == true, 'Unloaded callbacks stayed active')
owner.arm(); check(#h.armed == 1)

-- A failure after native initialization must undo the initialization.
h = harness({notifyFail = true})
check(not pcall(h.install))
check(h.stops == 1, 'Failed initialization left native hooks installed')

-- Partial menu hook registration and UI failures also release their resources.
h = harness({hookFail = true}); owner = h.install()
check(h.tick() == true and h.stops == 1 and h.unregistered == 1)
check(h.cancelled == 1, 'Hook failure left the game-thread timer running')
h = harness(); owner = h.install(); h.tick(); h.options.readFail = true
check(h.tick() == true and h.stops == 1 and h.removed == 1)
check(h.cancelled == 1, 'UI failure left the game-thread timer running')
owner.unload(); check(h.stops == 1)

-- A read-only preferences file must not prevent selecting resources this session.
h = harness({writeFail = true}); owner = h.install(); h.tick()
h.custom, h.selected = true, {[12] = true}; owner.arm()
check(h.armed[1] == 4096 and h.stops == 0)
owner.unload()

h = harness({loading = true}); owner = h.install(); h.tick()
h.custom = true; owner.arm()
check(#h.armed == 0 and h.disarms > 0, 'Loading a save armed generation')
owner.unload()

h = harness({armFail = true}); owner = h.install(); h.tick(); h.custom = true
owner.arm(); check(h.disarms == 1 and #h.armed == 0)
h.options.armFail = false; owner.arm(); check(#h.armed == 1)
h.custom = false; owner.arm(); check(h.disarms == 2)
owner.unload()

h = harness({preferences = 'SR1 1 8192'}); owner = h.install()
check(not owner.state.custom and Model.mask(owner.state.selected) == 68, 'Corrupt settings replaced defaults')
owner.unload()
h = harness({preferences = 'SR1 1 1152\n'}); owner = h.install()
check(owner.state.custom and Model.mask(owner.state.selected) == 1152, 'Existing preferences changed')
owner.unload()

h = harness(); owner = h.install({Enabled = false, CustomByDefault = false})
check(h.nativeCreated == 0 and h.tick == nil, 'Disabled mod installed hooks')
owner.unload()
h = harness(); owner = h.install({Enabled = false, CustomByDefault = false, DefaultRichResources = {'Unknown'}})
check(h.nativeCreated == 0, 'Disabled mod tried to validate unused defaults')
owner.unload()
return checks
