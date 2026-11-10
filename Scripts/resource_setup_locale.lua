local Locale = {}

Locale.catalogs = {
    en = {
        title = 'Starting resources',
        distribution = 'Distribution',
        random = 'Random',
        custom = 'Custom',
        modeTip = 'Random uses the game rules. Custom lets you choose up to two regional strengths.',
        first = 'Regional strength 1',
        second = 'Regional strength 2',
        firstTip = 'Choose a rich resource or high fertility. If it matches the second choice, that choice will be cleared.',
        secondTip = 'Choose another rich resource or high fertility. Each option can only be selected once.',
        empty = 'No selection: the game will use its random distribution.',
        count = '%d of 2 strengths selected',
        None = 'Random',
        Salt = 'Salt',
        Iron = 'Iron',
        Clay = 'Clay',
        Deer = 'Big game (deer)',
        Fish = 'Fish',
        Berries = 'Berries',
        Stone = 'Stone',
        Mushrooms = 'Mushrooms',
        SmallGame = 'Small game',
        Fertility = 'High fertility',
    },
    es = {
        title = 'Recursos de inicio',
        distribution = 'Distribución',
        random = 'Aleatoria',
        custom = 'Personalizada',
        modeTip = 'Aleatoria utiliza las reglas del juego. Personalizada permite elegir hasta dos ventajas regionales.',
        first = 'Ventaja regional 1',
        second = 'Ventaja regional 2',
        firstTip = 'Elige un recurso rico o fertilidad alta. Si coincide con la segunda ventaja, se vaciará esa segunda elección.',
        secondTip = 'Puedes elegir otro recurso rico o fertilidad alta. Cada opción solo puede elegirse una vez.',
        empty = 'Sin selección: se usará la distribución aleatoria.',
        count = '%d de 2 ventajas seleccionadas',
        None = 'Al azar',
        Salt = 'Sal',
        Iron = 'Hierro',
        Clay = 'Arcilla',
        Deer = 'Caza mayor (ciervos)',
        Fish = 'Pesca',
        Berries = 'Bayas',
        Stone = 'Piedra',
        Mushrooms = 'Setas',
        SmallGame = 'Caza menor',
        Fertility = 'Fertilidad alta',
    },
}

function Locale.language(tag)
    local language = type(tag) == 'string' and tag:lower():match('^([a-z]+)')
    return Locale.catalogs[language] and language or 'en'
end

function Locale.current()
    -- Manor Lords translates its own tables using Settings.lang_txt. Unreal's
    -- GetCurrentLanguage can still report en while the game menus are Spanish.
    local ok, tag = pcall(function()
        local instance = FindFirstOf('MLGameInstance')
        if instance and instance:IsValid() then return instance.Settings.lang_txt:ToString() end
    end)
    tag = ok and type(tag) == 'string' and tag or 'en'
    return Locale.language(tag), tag
end

function Locale.text(language, key, ...)
    local catalog = Locale.catalogs[Locale.language(language)]
    local value = assert(catalog[key] or Locale.catalogs.en[key], 'Missing translation: ' .. key)
    if select('#', ...) == 0 then return value end
    return string.format(value, ...)
end

return Locale
