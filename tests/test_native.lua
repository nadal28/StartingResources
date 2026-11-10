local Native = require('resource_setup_native')
local checks = 0
local function check(condition, message) assert(condition, message); checks = checks + 1 end

local function harness(options)
    local h = {options = options or {}, stops = 0, arms = 0}
    package.loadlib = function(_, name)
        if name == 'SR_Init' then
            return function()
                h.status = 'READY\ninstalled=3\n'
                if h.options.initFail then error('Init failed') end
            end
        elseif name == 'SR_Stop' then
            return function() h.stops = h.stops + 1 end
        elseif name == 'SR_Arm' then
            return function() h.arms = h.arms + 1; h.status = 'ARMED for next generation\n' end
        else return function() end end
    end
    io.open = function(path, mode)
        if mode == 'r' then
            if h.options.statusFail then return nil end
            return {read = function() return h.status end, close = function() return true end}
        end
        return {write = function() return true end, close = function() return true end}
    end
    function h.new() return Native.new('/test', function() end) end
    return h
end

local h = harness({statusFail = true})
check(not pcall(h.new) and h.stops == 1, 'Status read failure leaked native hooks')
h = harness({initFail = true})
check(not pcall(h.new) and h.stops == 1, 'Init exception leaked native hooks')
h = harness()
local native = h.new()
local instance = {GetAddress = function() return 123 end}
native.arm(instance, 4100)
check(h.arms == 1)
check(not pcall(native.arm, instance, 8192) and h.arms == 1, 'Invalid mask reached native adapter')
native.stop(); native.stop()
check(h.stops == 1)
check(not pcall(native.arm, instance, 4) and h.arms == 1, 'Stopped adapter could be armed')
return checks
