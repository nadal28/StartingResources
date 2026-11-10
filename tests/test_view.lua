-- Exercise the real view with widgets that reset their selected value on UpdateOptions.
-- This catches accidental loss or reordering of choices when translating a live panel.
local Model = require('resource_setup_model')
local Preferences = require('resource_setup_preferences')
local Locale = require('resource_setup_locale')
local checks, tag = 0, 'es-ES'
local function check(condition, message)
    assert(condition, message)
    checks = checks + 1
end
local function slot()
    return {SetPadding = function() end, SetSize = function() end, SetVerticalAlignment = function() end}
end
local function widget()
    local w = {children = {}, rebuilds = 0, Font = {Size = 14}}
    function w:IsValid() return true end
    function w:AddChild(child) self.children[#self.children + 1] = child; return slot() end
    w.AddChildToVerticalBox, w.AddChildToHorizontalBox = w.AddChild, w.AddChild
    function w:SetFont(value) self.Font = value end
    function w:SetText(value) self.text = value end
    function w:GetText() return self.text end
    function w:SetToolTipText(value) self.tip = value end
    function w:SetVisibility(value) self.visibility = value end
    function w:SetBrushFromTexture(value) self.texture = value end
    function w:RemoveFromParent() self.removed = true end
    function w:UpdateOptions(options, keep)
        local old = self.value
        self.options, self.value = options, options[1].Value
        if keep then
            for _, option in ipairs(options) do if option.Value == old then self.value = old end end
        end
        self.rebuilds = self.rebuilds + 1
    end
    function w:SelectValue(value)
        for _, option in ipairs(self.options) do
            if option.Value == value then self.value = value; return end
        end
        error('Missing spinner value: ' .. value)
    end
    function w:GetCurrentOption()
        for _, option in ipairs(self.options) do if option.Value == self.value then return option end end
        error('Invalid selection')
    end
    for _, name in ipairs({'SetColorAndOpacity', 'SetAutoWrapText', 'SetHeightOverride',
        'SetWidthOverride', 'AdjustHeight'}) do w[name] = function() end end
    return w
end
local library = widget()
function library:Create(_, class)
    local w = widget()
    if class.path:find('W_Menu_HeaderBar', 1, true) then
        w.localizedTextBox = {TextBlock_16 = widget()}
    else w.Label = widget() end
    return w
end
StaticFindObject = function(path)
    if path:find('WidgetBlueprintLibrary', 1, true) then return library end
    return widget()
end
FindFirstOf = function()
    return {IsValid = function() return true end, Settings = {lang_txt = {ToString = function() return tag end}}}
end
LoadAsset = function(path) local w = widget(); w.path = path; return w end
StaticConstructObject = function() return widget() end
FText, FName = function(value) return value end, function(value) return value end
local setup = {WidgetTree = widget(), SettingsScrollBox = widget(),
    entry_aggressiveness = {Text = widget(), Spinner = {Label = widget()}, Icon = {}}}
function setup:GetOwningPlayer() return widget() end
local View = require('resource_setup_view')
local state = {custom = true, selected = {[2] = true, [12] = true}}
local original = Preferences.encode(state)
local v = View.build(setup, state)
local function labels(language)
    check(v.header.localizedTextBox.TextBlock_16.text == Locale.text(language, 'title'))
    for _, row in ipairs({v.modeRow, v.firstRow, v.secondRow}) do
        check(row.title.text == Locale.text(language, row.captionKey))
        check(row.root.tip == Locale.text(language, row.tipKey))
    end
    for _, row in ipairs({v.firstRow, v.secondRow}) do
        for _, option in ipairs(row.spinner.options) do
            local id = tonumber(option.Value)
            check(option.Label == Locale.text(language, id == 0 and 'None' or Model.byID[id].key))
        end
    end
    check(v.modeRow.spinner.options[1].Label == Locale.text(language, 'random'))
    check(v.modeRow.spinner.options[2].Label == Locale.text(language, 'custom'))
end
labels('es')
check(v.summary.text == '2 de 2 ventajas seleccionadas')

-- The order on screen may differ from the canonical order in the preferences mask.
v.first.widget:SelectValue('12'); v.read(); v.second.widget:SelectValue('2')
for _, test in ipairs({{'en-GB', 'en'}, {'de', 'en'}, {'de', 'en'}, {'es-MX', 'es'}, {'fr', 'en'}, {'es', 'es'}}) do
    local previousTag, rebuilds = select(2, Locale.current()), v.first.widget.rebuilds
    tag = test[1]
    -- Native localized headers can refresh even when both game languages use our English fallback.
    if previousTag ~= tag then v.header.localizedTextBox.TextBlock_16.text = 'Native header refresh' end
    local custom, selected = v.read()
    labels(test[2])
    check(custom and Model.mask(selected) == 4100)
    check(v.first.widget.value == '12' and v.second.widget.value == '2', 'Language change reordered slots')
    check(Preferences.encode({custom = custom, selected = selected}) == original, 'Language changed preferences')
    check(v.summary.text == Locale.text(test[2], 'count', 2))
    if previousTag == test[1] then
        check(v.first.widget.rebuilds == rebuilds, 'Unchanged language rebuilt spinner')
    end
end
local builds = v.first.widget.rebuilds
v.second.widget:SelectValue('1'); v.read()
check(v.first.widget.rebuilds == builds and v.first.widget.value == '12', 'Second choice rebuilt first spinner')

-- A pending edit and duplicate handling must survive the same poll as a language change.
v.first.widget:SelectValue('1'); tag = 'en'; local _, selected = v.read()
check(selected[1] and not selected[12] and v.second.widget.value == '0')
check(v.summary.text == '1 of 2 strengths selected')
v.mode.widget:SelectValue('random'); tag = 'es'; v.read()
check(v.mode.widget.value == 'random' and v.firstRow.root.visibility == 1)
check(v.first.widget.value == '1' and v.second.widget.value == '0')
v.first.widget:SelectValue('0'); tag = 'en'; v.read()
check(v.summary.text == Locale.text('en', 'empty'))
v.mode.widget:SelectValue('custom'); v.read()
check(v.firstRow.root.visibility == 0 and v.secondRow.root.visibility == 0)
View.remove(v); check(v.root.removed)

tag = 'ja'; v = View.build(setup, state)
labels('en')
check(v.first.widget.value == '2' and v.second.widget.value == '12', 'Reopening lost saved selection')
View.remove(v)
return checks
