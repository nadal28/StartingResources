local source = debug.getinfo(1, 'S').source:gsub('^@', ''):gsub('\\', '/')
local root = assert(source:match('^(.*)/[Ss]cripts/[^/]+$'))
local started=false
local function log(message)
    local line='[StartingResources 0.2.0] '..tostring(message)
    print(line..'\n')
    local file=io.open(root..'/status.txt',started and'a'or'w')
    if file then file:write(line,'\n');file:close();started=true end
end
local owner
local ok,reason=pcall(function()
    owner=require('resource_setup_runtime').install(root,require('config'),log)
end)
if not ok then log('STARTUP ERROR '..tostring(reason))end
ModRef.OnUnload=function()if owner then owner.unload()end end
-- The development harness is available only in an explicitly isolated test launch.
local kismet=StaticFindObject('/Script/Engine.Default__KismetSystemLibrary')
if kismet and kismet:IsValid()and kismet:GetCommandLine():ToString():find('-StartingResourcesTest=20261109',1,true)then
    dofile(root..'/../_resource_setup_research/probe.lua')(root,owner)
end
