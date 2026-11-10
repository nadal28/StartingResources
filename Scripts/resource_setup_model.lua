local M={}
M.resources={
    {id=1,key='Salt',label='Sal'}, {id=2,key='Iron',label='Hierro'},
    {id=3,key='Clay',label='Arcilla'}, {id=5,key='Fish',label='Pesca (según el agua)'},
    {id=6,key='Berries',label='Bayas'}, {id=7,key='Stone',label='Piedra'},
    {id=9,key='Mushrooms',label='Setas'}, {id=10,key='SmallGame',label='Caza menor'},
    {id=12,key='Fertility',label='Fertilidad alta'},
}
function M.mask(selected)
    local result,count=0,0
    for _,r in ipairs(M.resources) do
        if selected[r.id] then result=result+(1<<r.id);count=count+1 end
    end
    assert(count<=2,'Puedes elegir hasta dos recursos ricos')
    return result,count
end
function M.decode(mask)
    assert(type(mask)=='number' and mask==math.floor(mask) and mask>=0,'Invalid resource selection')
    local selected={}
    for _,r in ipairs(M.resources) do selected[r.id]=(mask&(1<<r.id))~=0 end
    local decoded,count=M.mask(selected)
    assert(decoded==mask and count<=2,'Unsupported resource selection')
    return selected
end
function M.summary(custom,selected)
    if not custom then return 'Distribución aleatoria del juego' end
    local labels={}
    for _,r in ipairs(M.resources) do if selected[r.id] then labels[#labels+1]=r.label end end
    if #labels==0 then return 'Elige uno o dos recursos ricos' end
    return 'Recursos ricos: '..table.concat(labels,' + ')
end
return M
