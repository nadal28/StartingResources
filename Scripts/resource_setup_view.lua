local Model=require('resource_setup_model')
local View={}
local function valid(o)return o and o:IsValid()end
local function str(s)return type(s)=='string'and s or s:ToString()end
local icons={
    [1]='ml_map_resource_0003_salt',[2]='ml_map_resource_0000_iron',[3]='ml_map_resource_0002_clay',[5]='ml_map_resource_0006_fish',
    [6]='ml_map_resource_0004_berries',[7]='ml_map_resource_0001_stone',[9]='mushroom-gills',[10]='paw',[12]='wheat',
}
local function label(r)return r.id==5 and'Pesca'or r.label end

function View.build(setup,state)
    local tree,parent=setup.WidgetTree,setup.SettingsScrollBox
    assert(valid(tree)and valid(parent),'No se encuentra la lista de opciones de Nueva partida')
    local library=StaticFindObject('/Script/UMG.Default__WidgetBlueprintLibrary')
    local spinnerClass=LoadAsset('/Game/UI/Game_Setup/W_MenuSpinner.W_MenuSpinner_C')
    local headerClass=LoadAsset('/Game/UI/Game_Setup/W_Menu_HeaderBar.W_Menu_HeaderBar_C')
    assert(valid(library)and valid(spinnerClass)and valid(headerClass),'Controles originales del menú no disponibles')
    local classes={}
    for _,name in ipairs({'VerticalBox','HorizontalBox','TextBlock','SizeBox','Image'})do
        classes[name]=StaticFindObject('/Script/UMG.'..name)
        assert(valid(classes[name]),'Falta la clase de interfaz '..name)
    end
    local function new(kind,name)
        local o=StaticConstructObject(classes[kind],tree,name and FName(name)or 0)
        assert(valid(o),'No se pudo crear '..kind);return o
    end
    local root=new('VerticalBox','StartingResourcesPanel')
    parent:AddChild(root)
    local result
    local ok,reason=pcall(function()
        local source=setup.entry_aggressiveness.Text
        assert(valid(source),'Estilo de texto del menú no disponible')
        local function text(value,small)
            local w=new('TextBlock');w:SetFont(source.Font)
            if small then local f=w.Font;f.Size=math.max(10,f.Size-1);w:SetFont(f)end
            w:SetColorAndOpacity(source.ColorAndOpacity);w:SetText(FText(value))
            w:SetAutoWrapText(true)
            return w
        end
        local function add(w,top,bottom)
            local slot=root:AddChildToVerticalBox(w)
            slot:SetPadding({Left=0,Top=top or 0,Right=0,Bottom=bottom or 0})
            return slot
        end
        local header=library:Create(setup,headerClass,setup:GetOwningPlayer())
        add(header,12,5)
        header.localizedTextBox.TextBlock_16:SetText(FText('Recursos de inicio'))
        header:AdjustHeight(40)
        local function row(caption,tip)
            local size=new('SizeBox');size:SetHeightOverride(36)
            add(size):SetPadding({Left=14,Top=0,Right=14,Bottom=0})
            local line=new('HorizontalBox');size:AddChild(line)
            local image=new('Image');image:SetVisibility(2)
            image:SetColorAndOpacity(setup.entry_aggressiveness.Icon.ColorAndOpacity)
            local imageSize=new('SizeBox');imageSize:SetWidthOverride(32);imageSize:SetHeightOverride(28);imageSize:AddChild(image)
            local imageSlot=line:AddChildToHorizontalBox(imageSize)
            imageSlot:SetPadding({Left=8,Top=0,Right=8,Bottom=0});imageSlot:SetVerticalAlignment(2)
            local title=text(caption)
            local titleSlot=line:AddChildToHorizontalBox(title)
            titleSlot:SetSize({Value=0.48,SizeRule=1});titleSlot:SetVerticalAlignment(2)
            local spinner=library:Create(setup,spinnerClass,setup:GetOwningPlayer())
            local slot=line:AddChildToHorizontalBox(spinner)
            slot:SetSize({Value=0.52,SizeRule=1});slot:SetPadding({Left=6,Top=0,Right=8,Bottom=0});slot:SetVerticalAlignment(2)
            spinner.bAllowWrapping=true
            spinner.TextColor=setup.entry_aggressiveness.Spinner.TextColor
            spinner.Label:SetColorAndOpacity(setup.entry_aggressiveness.Spinner.Label.ColorAndOpacity)
            size:SetToolTipText(FText(tip))
            return {root=size,spinner=spinner,icon=image}
        end
        local modeRow=row('Distribución','Aleatoria utiliza las reglas del juego. Personalizada permite elegir hasta dos recursos ricos.')
        modeRow.spinner:UpdateOptions({{Label=FText('Aleatoria'),Value='random'},{Label=FText('Personalizada'),Value='custom'}},false)
        modeRow.spinner:SelectValue(state.custom and'custom'or'random')
        local firstRow=row('Ventaja regional 1','Elige un recurso rico o fertilidad alta. Si coincide con la segunda ventaja, tendrás que volver a elegirla.')
        local secondRow=row('Ventaja regional 2','Puedes elegir otro recurso rico o fertilidad alta. Cada opción solo puede elegirse una vez.')
        local hint=text('',true);add(hint,4,6):SetPadding({Left=62,Top=4,Right=12,Bottom=6})
        local choices={}
        for _,r in ipairs(Model.resources)do if state.selected[r.id]then choices[#choices+1]=r.id end end
        local function options(exclude)
            local list={{Label=FText('Sin elegir'),Value='0'}}
            for _,r in ipairs(Model.resources)do
                if r.id~=exclude then list[#list+1]={Label=FText(label(r)),Value=tostring(r.id)}end
            end
            return list
        end
        firstRow.spinner:UpdateOptions(options(nil),false)
        firstRow.spinner:SelectValue(tostring(choices[1]or 0))
        secondRow.spinner:UpdateOptions(options(choices[1]),false)
        secondRow.spinner:SelectValue(tostring(choices[2]or 0))
        local excludeSecond=choices[1]
        local function value(row)return tonumber(str(row.spinner:GetCurrentOption().Value))or 0 end
        local function icon(row,id)
            if row.iconID==id then return end
            row.iconID=id
            local name=icons[id]
            if name then
                local texture=LoadAsset('/Game/ManorLords/UI/Icons/Flat/'..name..'.'..name)
                assert(valid(texture),'No se encuentra el icono '..name)
                row.icon:SetBrushFromTexture(texture,false);row.icon:SetVisibility(3)
            else row.icon:SetVisibility(2)end
        end
        -- The small adapter keeps diagnostic scripts independent of the widget type.
        local function adapter(row,isMode)
            local a={widget=row.spinner}
            function a:SetSelectedOption(name)
                if isMode then
                    row.spinner:SelectValue((name=='Elegir recursos ricos'or name=='Personalizada')and'custom'or'random')
                else
                    if name=='Sin elegir'then row.spinner:SelectValue('0');return end
                    for _,r in ipairs(Model.resources)do if name==r.label or name==label(r)then row.spinner:SelectValue(tostring(r.id));return end end
                end
            end
            function a:GetSelectedOption()
                if isMode then return str(row.spinner:GetCurrentOption().Value)=='custom'and'Elegir recursos ricos'or'Aleatorio (juego)'end
                return str(row.spinner:GetCurrentOption().Label)
            end
            function a:GetSelectedIndex()return row.spinner:GetCurrentIndex()end
            function a:SetSelectedIndex(index)row.spinner:SelectIndex(index)end
            function a:GetOptionCount()return row.spinner:GetNumOptions()end
            function a:GetIsEnabled()return row.spinner:GetIsEnabled()end
            return a
        end
        result={root=root,setup=setup,mode=adapter(modeRow,true),first=adapter(firstRow),second=adapter(secondRow),
                firstRow=firstRow,secondRow=secondRow,summary=hint,header=header}
        function result.read()
            local custom=str(modeRow.spinner:GetCurrentOption().Value)=='custom'
            local a,b=value(firstRow),value(secondRow)
            if a~=0 and a==b then secondRow.spinner:SelectValue('0');b=0 end
            if excludeSecond~=a then secondRow.spinner:UpdateOptions(options(a),true);excludeSecond=a end
            local selected={};if a~=0 then selected[a]=true end;if b~=0 then selected[b]=true end
            local visibility=custom and 0 or 1
            if result.visibility~=visibility then
                firstRow.root:SetVisibility(visibility);secondRow.root:SetVisibility(visibility);hint:SetVisibility(visibility)
                result.visibility=visibility
            end
            icon(firstRow,a);icon(secondRow,b)
            return custom,selected
        end
        function result.refresh(custom,selected)
            local _,count=Model.mask(selected)
            hint:SetText(FText(count==0 and'Sin selección: se usará la distribución aleatoria.'or(count..' de 2 ventajas seleccionadas')))
        end
        result.read();result.refresh(state.custom,state.selected)
    end)
    if not ok then root:RemoveFromParent();error(reason)end
    return result
end
function View.remove(view)
    if view and valid(view.root)then view.root:RemoveFromParent()end
end
return View
