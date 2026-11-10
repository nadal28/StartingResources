local Model = require('resource_setup_model')
local View = {}

local function valid(object) return object and object:IsValid() end
local function str(value) return type(value) == 'string' and value or value:ToString() end

local function spinnerOptions(exclude)
    local options = {}
    for _, resource in ipairs(Model.options(exclude)) do
        options[#options + 1] = {Label = FText(resource.label), Value = tostring(resource.id)}
    end
    return options
end

local function selectedValue(row)
    return tonumber(str(row.spinner:GetCurrentOption().Value)) or 0
end

-- Compatibility surface used by the isolated game diagnostics.
local function adapter(row, isMode)
    local control = {widget = row.spinner}
    function control:SetSelectedOption(name)
        if isMode then
            local custom = name == 'Elegir recursos ricos' or name == 'Personalizada'
            row.spinner:SelectValue(custom and 'custom' or 'random')
            return
        end
        if name == 'Sin elegir' then row.spinner:SelectValue('0'); return end
        if name == 'Pesca (según el agua)' then name = 'Pesca' end
        for _, resource in ipairs(Model.resources) do
            if name == resource.label then
                row.spinner:SelectValue(tostring(resource.id))
                return
            end
        end
    end
    function control:GetSelectedOption()
        if isMode then
            return str(row.spinner:GetCurrentOption().Value) == 'custom'
                and 'Elegir recursos ricos' or 'Aleatorio (juego)'
        end
        return str(row.spinner:GetCurrentOption().Label)
    end
    function control:GetSelectedIndex() return row.spinner:GetCurrentIndex() end
    function control:SetSelectedIndex(index) row.spinner:SelectIndex(index) end
    function control:GetOptionCount() return row.spinner:GetNumOptions() end
    function control:GetIsEnabled() return row.spinner:GetIsEnabled() end
    return control
end

function View.build(setup, state)
    local tree, parent = setup.WidgetTree, setup.SettingsScrollBox
    assert(valid(tree) and valid(parent), 'No se encuentra la lista de opciones de Nueva partida')
    local library = StaticFindObject('/Script/UMG.Default__WidgetBlueprintLibrary')
    local spinnerClass = LoadAsset('/Game/UI/Game_Setup/W_MenuSpinner.W_MenuSpinner_C')
    local headerClass = LoadAsset('/Game/UI/Game_Setup/W_Menu_HeaderBar.W_Menu_HeaderBar_C')
    assert(valid(library) and valid(spinnerClass) and valid(headerClass),
        'Controles originales del menú no disponibles')

    local classes = {}
    for _, name in ipairs({'VerticalBox', 'HorizontalBox', 'TextBlock', 'SizeBox', 'Image'}) do
        classes[name] = StaticFindObject('/Script/UMG.' .. name)
        assert(valid(classes[name]), 'Falta la clase de interfaz ' .. name)
    end
    local function new(kind, name)
        local widget = StaticConstructObject(classes[kind], tree, name and FName(name) or 0)
        assert(valid(widget), 'No se pudo crear ' .. kind)
        return widget
    end

    -- Parent native widgets before configuring them so Unreal keeps them alive.
    local root = new('VerticalBox', 'StartingResourcesPanel')
    parent:AddChild(root)
    local result
    local ok, reason = pcall(function()
        local style = setup.entry_aggressiveness
        assert(valid(style.Text), 'Estilo de texto del menú no disponible')

        local function text(value, small)
            local widget = new('TextBlock')
            widget:SetFont(style.Text.Font)
            if small then
                local font = widget.Font
                font.Size = math.max(10, font.Size - 1)
                widget:SetFont(font)
            end
            widget:SetColorAndOpacity(style.Text.ColorAndOpacity)
            widget:SetText(FText(value))
            widget:SetAutoWrapText(true)
            return widget
        end

        local function add(widget, top, bottom)
            local slot = root:AddChildToVerticalBox(widget)
            slot:SetPadding({Left = 0, Top = top or 0, Right = 0, Bottom = bottom or 0})
            return slot
        end

        local header = library:Create(setup, headerClass, setup:GetOwningPlayer())
        add(header, 12, 5)
        header.localizedTextBox.TextBlock_16:SetText(FText('Recursos de inicio'))
        header:AdjustHeight(40)

        local function row(caption, tip)
            local size = new('SizeBox')
            size:SetHeightOverride(36)
            add(size):SetPadding({Left = 14, Top = 0, Right = 14, Bottom = 0})
            local line = new('HorizontalBox')
            size:AddChild(line)

            local image = new('Image')
            image:SetVisibility(2)
            image:SetColorAndOpacity(style.Icon.ColorAndOpacity)
            local imageSize = new('SizeBox')
            imageSize:SetWidthOverride(32)
            imageSize:SetHeightOverride(28)
            imageSize:AddChild(image)
            local imageSlot = line:AddChildToHorizontalBox(imageSize)
            imageSlot:SetPadding({Left = 8, Top = 0, Right = 8, Bottom = 0})
            imageSlot:SetVerticalAlignment(2)

            local titleSlot = line:AddChildToHorizontalBox(text(caption))
            titleSlot:SetSize({Value = 0.48, SizeRule = 1})
            titleSlot:SetVerticalAlignment(2)

            local spinner = library:Create(setup, spinnerClass, setup:GetOwningPlayer())
            local slot = line:AddChildToHorizontalBox(spinner)
            slot:SetSize({Value = 0.52, SizeRule = 1})
            slot:SetPadding({Left = 6, Top = 0, Right = 8, Bottom = 0})
            slot:SetVerticalAlignment(2)
            spinner.bAllowWrapping = true
            spinner.TextColor = style.Spinner.TextColor
            spinner.Label:SetColorAndOpacity(style.Spinner.Label.ColorAndOpacity)
            size:SetToolTipText(FText(tip))
            return {root = size, spinner = spinner, icon = image}
        end

        local modeRow = row('Distribución',
            'Aleatoria utiliza las reglas del juego. Personalizada permite elegir hasta dos ventajas regionales.')
        modeRow.spinner:UpdateOptions({
            {Label = FText('Aleatoria'), Value = 'random'},
            {Label = FText('Personalizada'), Value = 'custom'},
        }, false)
        modeRow.spinner:SelectValue(state.custom and 'custom' or 'random')

        local firstRow = row('Ventaja regional 1',
            'Elige un recurso rico o fertilidad alta. Si coincide con la segunda ventaja, tendrás que volver a elegirla.')
        local secondRow = row('Ventaja regional 2',
            'Puedes elegir otro recurso rico o fertilidad alta. Cada opción solo puede elegirse una vez.')
        local hint = text('', true)
        add(hint, 4, 6):SetPadding({Left = 62, Top = 4, Right = 12, Bottom = 6})

        local choices = Model.ordered(state.selected)
        firstRow.spinner:UpdateOptions(spinnerOptions(), false)
        firstRow.spinner:SelectValue(tostring(choices[1] or 0))
        secondRow.spinner:UpdateOptions(spinnerOptions(choices[1]), false)
        secondRow.spinner:SelectValue(tostring(choices[2] or 0))
        local excludedSecond = choices[1] or 0

        local function updateIcon(resourceRow, id)
            if resourceRow.iconID == id then return end
            resourceRow.iconID = id
            local resource = Model.byID[id]
            if not resource then
                resourceRow.icon:SetVisibility(2)
                return
            end
            local name = resource.icon
            local texture = LoadAsset('/Game/ManorLords/UI/Icons/Flat/' .. name .. '.' .. name)
            assert(valid(texture), 'No se encuentra el icono ' .. name)
            resourceRow.icon:SetBrushFromTexture(texture, false)
            resourceRow.icon:SetVisibility(3)
        end

        result = {
            root = root, setup = setup, header = header, summary = hint,
            mode = adapter(modeRow, true), first = adapter(firstRow), second = adapter(secondRow),
            firstRow = firstRow, secondRow = secondRow,
        }
        function result.read()
            local custom = str(modeRow.spinner:GetCurrentOption().Value) == 'custom'
            local first, second = selectedValue(firstRow), selectedValue(secondRow)
            local selected, normalizedSecond = Model.fromSlots(first, second)
            if second ~= normalizedSecond then
                secondRow.spinner:SelectValue(tostring(normalizedSecond))
            end
            -- Never rebuild the first spinner when the second changes: the game
            -- otherwise animates an apparent change to the first selection.
            if excludedSecond ~= first then
                secondRow.spinner:UpdateOptions(spinnerOptions(first), true)
                excludedSecond = first
            end
            local visibility = custom and 0 or 1
            if result.visibility ~= visibility then
                firstRow.root:SetVisibility(visibility)
                secondRow.root:SetVisibility(visibility)
                hint:SetVisibility(visibility)
                result.visibility = visibility
            end
            updateIcon(firstRow, first)
            updateIcon(secondRow, normalizedSecond)
            return custom, selected
        end

        function result.refresh(_, selected)
            local _, count = Model.mask(selected)
            local summary = count == 0 and 'Sin selección: se usará la distribución aleatoria.'
                or (count .. ' de 2 ventajas seleccionadas')
            hint:SetText(FText(summary))
        end
        result.read()
        result.refresh(state.custom, state.selected)
    end)
    if not ok then root:RemoveFromParent(); error(reason, 0) end
    return result
end

function View.remove(view)
    if view and valid(view.root) then view.root:RemoveFromParent() end
end

return View
