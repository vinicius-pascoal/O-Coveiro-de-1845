-- Opções do jogador, compartilhadas entre as cenas World e HUD.
-- Ficam guardadas no UserSettings do motor (o mesmo arquivo dos saves) e voltam ao abrir o jogo.

local Settings = {}

Settings.prefix = "coveiro1845_opt_"

Settings.sensitivityLevels = {
    { label = "Baixa", value = 0.08 },
    { label = "Média", value = 0.14 },
    { label = "Alta", value = 0.22 },
    { label = "Muito alta", value = 0.32 },
}

Settings.sensitivityIndex = 2
Settings.invertY = false
Settings.largeText = false
Settings.animateText = true

function Settings.sensitivity()
    return Settings.sensitivityLevels[Settings.sensitivityIndex].value
end

function Settings.sensitivityLabel()
    return Settings.sensitivityLevels[Settings.sensitivityIndex].label
end

function Settings.cycleSensitivity()
    Settings.sensitivityIndex = Settings.sensitivityIndex % #Settings.sensitivityLevels + 1
end

-- Volume: "master" vale para todos os sons; "ambient" para o vento e as rajadas;
-- "effects" para o resto (passos, rangidos, grunhidos, sussurros)
Settings.volumeLevels = {
    { label = "Mudo", value = 0 },
    { label = "25%", value = 0.25 },
    { label = "50%", value = 0.5 },
    { label = "75%", value = 0.75 },
    { label = "100%", value = 1.0 },
}
Settings.volumeIndex = { master = 5, ambient = 5, effects = 5 }
Settings.VOLUME_KINDS = { "master", "ambient", "effects" }

function Settings.volume(kind)
    return Settings.volumeLevels[Settings.volumeIndex[kind]].value
end

function Settings.volumeLabel(kind)
    return Settings.volumeLevels[Settings.volumeIndex[kind]].label
end

function Settings.cycleVolume(kind)
    Settings.volumeIndex[kind] = Settings.volumeIndex[kind] % #Settings.volumeLevels + 1
end

function Settings.toggleInvertY()
    Settings.invertY = not Settings.invertY
end

function Settings.toggleLargeText()
    Settings.largeText = not Settings.largeText
end

function Settings.toggleAnimateText()
    Settings.animateText = not Settings.animateText
end

----------------------------------------------------------------------
-- Persistência
----------------------------------------------------------------------
local DEFAULTS = {
    sensitivityIndex = 2, invertY = false, largeText = false, animateText = true,
    volume = { master = 5, ambient = 5, effects = 5 },
}

local function setInt(k, v) pcall(UserSettings.setIntegerForKey, Settings.prefix .. k, v) end
local function getInt(k, d)
    local ok, v = pcall(UserSettings.getIntegerForKey, Settings.prefix .. k, d)
    if ok and type(v) == "number" then return math.floor(v) end
    return d
end
local function inRange(v, max, d) if v >= 1 and v <= max then return v end return d end

function Settings.save()
    setInt("sensitivity", Settings.sensitivityIndex)
    setInt("invertY", Settings.invertY and 1 or 0)
    setInt("largeText", Settings.largeText and 1 or 0)
    setInt("animateText", Settings.animateText and 1 or 0)
    for _, kind in ipairs(Settings.VOLUME_KINDS) do setInt("vol_" .. kind, Settings.volumeIndex[kind]) end
end

function Settings.load()
    Settings.sensitivityIndex = inRange(getInt("sensitivity", DEFAULTS.sensitivityIndex), #Settings.sensitivityLevels, DEFAULTS.sensitivityIndex)
    Settings.invertY = getInt("invertY", DEFAULTS.invertY and 1 or 0) == 1
    Settings.largeText = getInt("largeText", DEFAULTS.largeText and 1 or 0) == 1
    Settings.animateText = getInt("animateText", DEFAULTS.animateText and 1 or 0) == 1
    for _, kind in ipairs(Settings.VOLUME_KINDS) do
        Settings.volumeIndex[kind] = inRange(getInt("vol_" .. kind, DEFAULTS.volume[kind]), #Settings.volumeLevels, DEFAULTS.volume[kind])
    end
end

function Settings.isDefault()
    if Settings.sensitivityIndex ~= DEFAULTS.sensitivityIndex or Settings.invertY ~= DEFAULTS.invertY
        or Settings.largeText ~= DEFAULTS.largeText or Settings.animateText ~= DEFAULTS.animateText then
        return false
    end
    for _, kind in ipairs(Settings.VOLUME_KINDS) do
        if Settings.volumeIndex[kind] ~= DEFAULTS.volume[kind] then return false end
    end
    return true
end

function Settings.resetDefaults()
    Settings.sensitivityIndex = DEFAULTS.sensitivityIndex
    Settings.invertY = DEFAULTS.invertY
    Settings.largeText = DEFAULTS.largeText
    Settings.animateText = DEFAULTS.animateText
    for _, kind in ipairs(Settings.VOLUME_KINDS) do Settings.volumeIndex[kind] = DEFAULTS.volume[kind] end
    Settings.save()
end

return Settings
