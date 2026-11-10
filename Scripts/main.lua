local source = debug.getinfo(1, 'S').source:gsub('^@', ''):gsub('\\', '/')
local root = assert(source:match('^(.*)/[Ss]cripts/[^/]+$'))
local started = false

local function log(message)
    local line = '[StartingResources 0.2.2] ' .. tostring(message)
    print(line .. '\n')
    local file = io.open(root .. '/status.txt', started and 'a' or 'w')
    if file then
        file:write(line, '\n')
        file:close()
        started = true
    end
end

local owner
local ok, reason = pcall(function()
    owner = require('resource_setup_runtime').install(root, require('config'), log)
end)
if not ok then log('STARTUP ERROR ' .. tostring(reason)) end
ModRef.OnUnload = function()
    if owner then owner.unload() end
end

-- Optional local diagnostics; normal installations do not need the harness.
local kismet = StaticFindObject('/Script/Engine.Default__KismetSystemLibrary')
if owner and kismet and kismet:IsValid()
    and kismet:GetCommandLine():ToString():find('-StartingResourcesTest=20261109', 1, true) then
    local harness = loadfile(root .. '/../_resource_setup_research/probe.lua')
    if harness then
        local ready, failure = pcall(function() harness()(root, owner) end)
        if not ready then
            owner.unload()
            log('TEST HARNESS ERROR ' .. tostring(failure))
        end
    else
        log('TEST HARNESS unavailable')
    end
end
