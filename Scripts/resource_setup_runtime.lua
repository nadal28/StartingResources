local Model = require('resource_setup_model')
local Preferences = require('resource_setup_preferences')
local View = require('resource_setup_view')
local Native = require('resource_setup_native')
local Runtime = {}

local setupPath = '/Game/UI/Game_Setup/mainMenu_GameSetup.mainMenu_GameSetup_C'
local menuPath = '/Game/UI/Main_Menu/mainMenu_widget.mainMenu_widget_C'
local function valid(object) return object and object:IsValid() end

function Runtime.install(root, config, log)
    local defaults = Model.fromConfig(config)
    if not config.Enabled then
        log('DISABLED')
        return {unload = function() end}
    end

    local preferencesPath = root .. '/preferences.txt'
    local state, preferencesError = Preferences.load(preferencesPath, defaults)
    if preferencesError then log('PREFERENCES IGNORED: ' .. tostring(preferencesError)) end
    local alive, cleaned = true, false
    local native, view, timer
    local pending, hooks = {}, {}
    local menuHooked = false
    local owner = {state = state, getView = function() return view end}

    function owner.unload()
        if cleaned then return end
        alive, cleaned = false, true
        if timer then pcall(CancelDelayedAction, timer) end
        for _, hook in ipairs(hooks) do pcall(UnregisterHook, table.unpack(hook)) end
        local previous = view
        view, pending = nil, {}
        if previous then
            pcall(ExecuteInGameThread, function() View.remove(previous) end)
        end
        if native then
            local ok, reason = pcall(native.stop)
            if not ok then log('STOP ERROR ' .. tostring(reason)) end
        end
    end

    local function captureSelection()
        if view and valid(view.root) then
            local custom, selected = view.read()
            local mask, count = Model.mask(selected)
            if custom ~= state.custom or mask ~= Model.mask(state.selected) then
                state.custom, state.selected = custom, selected
                view.refresh(custom, selected)
                local saved, reason = Preferences.save(preferencesPath, state)
                if not saved then log('PREFERENCES SAVE ERROR ' .. tostring(reason)) end
            end
            return mask, count
        end
        return Model.mask(state.selected)
    end

    local function arm()
        if not alive then return end
        -- Capture and persist here too: Play can run before the next UI poll.
        local mask, count = captureSelection()
        local instance = FindFirstOf('MLGameInstance')
        if not state.custom or count == 0 or not valid(instance)
            or instance.savefileToLoad:ToString() ~= '' then
            native.disarm()
            return
        end
        native.arm(instance, mask)
    end

    local function guardedArm()
        if not alive then return end
        local ok, reason = pcall(arm)
        if not ok then
            pcall(native.disarm)
            log('ARM ERROR ' .. tostring(reason))
        end
    end
    owner.arm = guardedArm

    local function attachMenuHooks()
        if menuHooked or not valid(StaticFindObject(menuPath .. ':startNewGame')) then return end
        local path = menuPath .. ':startNewGame'
        local pre, post = RegisterHook(path, guardedArm)
        hooks[#hooks + 1] = {path, pre, post}
        path = menuPath .. ':LoadGame'
        if valid(StaticFindObject(path)) then
            pre, post = RegisterHook(path, function()
                if alive then native.disarm() end
            end)
            hooks[#hooks + 1] = {path, pre, post}
        end
        menuHooked = true
    end

    local function attachPanel()
        if view and (not valid(view.setup) or not valid(view.root)) then view = nil end
        if view then return end
        for index = #pending, 1, -1 do
            local setup = pending[index]
            if not valid(setup) then
                table.remove(pending, index)
            elseif valid(setup.WidgetTree) and valid(setup.SettingsScrollBox) then
                view = View.build(setup, state)
                pending = {}
                log('MENU READY; panel at end of game settings')
                return
            end
        end
    end

    local function tick()
        if not alive then return true end
        local ok, reason = pcall(function()
            attachMenuHooks()
            attachPanel()
            captureSelection()
        end)
        if not ok then
            -- Game-thread timers ignore callback return values. Unload must
            -- cancel the handle explicitly, including from this callback.
            owner.unload()
            log('UI ERROR ' .. tostring(reason))
            return true
        end
        return false
    end

    -- Every failure after Native.new must release everything installed so far.
    local ok, reason = pcall(function()
        native = Native.new(root, log)
        owner.native = native
        NotifyOnNewObject(setupPath, function(object)
            if not alive then return true end
            pending[#pending + 1] = object
        end)
        RegisterLoadMapPreHook(function()
            if alive then view, pending = nil, {} end
        end)
        ExecuteInGameThread(function()
            if not alive then return end
            for _, object in ipairs(FindAllOf('mainMenu_GameSetup_C') or {}) do
                pending[#pending + 1] = object
            end
        end)
        timer = LoopInGameThreadWithDelay(150, tick)
    end)
    if not ok then
        owner.unload()
        error(reason, 0)
    end

    log('READY; waiting for New Game setup')
    return owner
end

return Runtime
