local Model=require('resource_setup_model')
local Runtime={}
local setupPath='/Game/UI/Game_Setup/mainMenu_GameSetup.mainMenu_GameSetup_C'
local menuPath='/Game/UI/Main_Menu/mainMenu_widget.mainMenu_widget_C'
local function valid(o)return o and o:IsValid()end
function Runtime.install(root,config,log)
    local View=dofile(root..'/Scripts/resource_setup_view.lua')
    assert(type(config.Enabled)=='boolean','Enabled debe ser true o false')
    assert(type(config.CustomByDefault)=='boolean','CustomByDefault debe ser true o false')
    if not config.Enabled then log('DISABLED');return {unload=function()end}end
    local state={custom=config.CustomByDefault==true,selected={}}
    for _,key in ipairs(config.DefaultRichResources or{})do
        local found=false
        for _,r in ipairs(Model.resources)do if r.key==key then state.selected[r.id]=true;found=true end end
        assert(found,'Recurso no compatible: '..tostring(key))
    end
    Model.mask(state.selected)
    local preferences=root..'/preferences.txt'
    local f=io.open(preferences,'r')
    if f then
        local custom,mask=f:read('*a'):match('^SR1 ([01]) (%d+)%s*$');f:close()
        if custom and mask then
            local ok,selection=pcall(Model.decode,tonumber(mask))
            if ok then state.custom=custom=='1';state.selected=selection end
        end
    end
    local native=require('resource_setup_native').new(root,log)
    local alive,view,pending=true,nil,{}
    local hooks={};local menuHooked=false
    local function save()
        local mask=Model.mask(state.selected)
        local file=assert(io.open(preferences,'w'))
        file:write('SR1 ',state.custom and'1'or'0',' ',mask,'\n');file:close()
    end
    local function arm()
        if not alive then return end
        if view and valid(view.root)then state.custom,state.selected=view.read()end
        local mask,count=Model.mask(state.selected)
        local instance=FindFirstOf('MLGameInstance')
        if not state.custom or count==0 or not valid(instance)or instance.savefileToLoad:ToString()~=''then
            native.disarm();return
        end
        native.arm(instance,mask)
    end
    local function guardedArm()
        local ok,reason=pcall(arm)
        if not ok then native.disarm();log('ERROR '..tostring(reason))end
    end
    local function attachMenuHooks()
        if menuHooked or not valid(StaticFindObject(menuPath..':startNewGame'))then return end
        local pre,post=RegisterHook(menuPath..':startNewGame',guardedArm)
        hooks[#hooks+1]={menuPath..':startNewGame',pre,post}
        local path=menuPath..':LoadGame'
        if valid(StaticFindObject(path))then
            local a,b=RegisterHook(path,function()if alive then native.disarm()end end)
            hooks[#hooks+1]={path,a,b}
        end
        menuHooked=true
    end
    NotifyOnNewObject(setupPath,function(o)if not alive then return true end;pending[#pending+1]=o end)
    RegisterLoadMapPreHook(function()view=nil;pending={}end)
    local function tick()
        if not alive then return true end
        local ok,reason=pcall(function()
            attachMenuHooks()
            if view and(not valid(view.setup)or not valid(view.root))then view=nil end
            if not view then
                for i=#pending,1,-1 do
                    local setup=pending[i]
                    if not valid(setup)then table.remove(pending,i)
                    elseif valid(setup.WidgetTree)and valid(setup.SettingsScrollBox)then
                        view=View.build(setup,state);pending={};log('MENU READY; panel at end of game settings');break
                    end
                end
            end
            if view then
                local custom,selected=view.read()
                if custom~=state.custom or Model.mask(selected)~=Model.mask(state.selected)then
                    state.custom,state.selected=custom,selected
                    view.refresh(custom,selected);save()
                end
            end
        end)
        if not ok then alive=false;native.disarm();log('UI ERROR '..tostring(reason));return true end
        return false
    end
    ExecuteInGameThread(function()
        if not alive then return end
        for _,o in ipairs(FindAllOf('mainMenu_GameSetup_C')or{})do pending[#pending+1]=o end
    end)
    local handle=LoopInGameThreadWithDelay(150,tick)
    local owner={state=state,native=native,arm=guardedArm,getView=function()return view end}
    function owner.unload()
        alive=false;pcall(CancelDelayedAction,handle)
        for _,hook in ipairs(hooks)do pcall(UnregisterHook,table.unpack(hook))end
        local previous=view;view=nil;pending={}
        if previous then pcall(ExecuteInGameThread,function()View.remove(previous)end)end
        native.stop()
    end
    log('READY; waiting for New Game setup')
    return owner
end
return Runtime
