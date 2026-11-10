local Native={}
function Native.new(root,log)
    local path=root..'/native/StartingResources-0.1.1.dll'
    local entry={}
    for _,name in ipairs({'Init','Arm','Disarm','Stop'}) do
        entry[name]=assert(package.loadlib(path,'SR_'..name),'No se puede cargar el adaptador '..name)
    end
    entry.Init()
    local function status()
        local file=assert(io.open(root..'/native-status.txt','r'))
        local text=file:read('*a');file:close();return text
    end
    assert(status():match('^READY\n'),'Adaptador no disponible: '..status():match('[^\n]+'))
    local n={status=status}
    function n.arm(instance,mask)
        local f=assert(io.open(root..'/selection.txt','w'))
        f:write('SR1 ',tostring(mask),' ',string.format('%x',instance:GetAddress()),'\n');f:close()
        entry.Arm()
        local s=status()
        assert(s:match('^ARMED '),'La selección no se pudo aplicar: '..s:match('[^\n]+'))
        log('ARMED mask='..mask)
    end
    function n.disarm() entry.Disarm() end
    function n.stop() entry.Stop() end
    return n
end
return Native
