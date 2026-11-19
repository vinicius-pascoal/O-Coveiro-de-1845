-- Opções do jogador, compartilhadas entre as cenas World e HUD.
-- Ficam guardadas no UserSettings do motor (o mesmo arquivo dos saves) e voltam ao abrir o jogo.
-- Volume e sensibilidade são contínuos (ajustados por sliders); o resto liga e desliga.

local Settings = {}

Settings.prefix = "coveiro1845_opt_"

-- Sensibilidade do mouse: nível de 1 a 10; o nível 4 equivale à antiga "Média" (0.14)
Settings.SENSITIVITY_MIN, Settings.SENSITIVITY_MAX = 1, 10
local SENSITIVITY_STEP = 0.035

-- Volume em porcentagem (0–100). "master" vale para todos os sons; "ambient" para o vento
-- e as rajadas; "effects" para o resto (passos, rangidos, grunhidos, sussurros)
Settings.VOLUME_KINDS = { "master", "ambient", "effects" }

local DEFAULTS = {
    sensitivity = 4, invertY = false, largeText = false, animateText = true,
    volume = { master = 100, ambient = 100, effects = 100 },
}

Settings.sensitivityLevel = DEFAULTS.sensitivity
Settings.invertY = DEFAULTS.invertY
Settings.largeText = DEFAULTS.largeText
Settings.animateText = DEFAULTS.animateText
Settings.volumePct = { master = 100, ambient = 100, effects = 100 }

local function clampRound(v, lo, hi, step)
    v = math.floor(v / step + 0.5) * step
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

function Settings.sensitivity()
    return Settings.sensitivityLevel * SENSITIVITY_STEP
end

function Settings.sensitivityLabel()
    return tostring(Settings.sensitivityLevel)
end

function Settings.setSensitivity(level)
    Settings.sensitivityLevel = clampRound(level, Settings.SENSITIVITY_MIN, Settings.SENSITIVITY_MAX, 1)
end

function Settings.volume(kind)
    return Settings.volumePct[kind] / 100
end

function Settings.volumeLabel(kind)
    local pct = Settings.volumePct[kind]
    return pct == 0 and "Mudo" or (pct .. "%")
end

-- Volume em passos de 5%
function Settings.setVolume(kind, pct)
    Settings.volumePct[kind] = clampRound(pct, 0, 100, 5)
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
local function setInt(k, v) pcall(UserSettings.setIntegerForKey, Settings.prefix .. k, v) end
local function getInt(k, d)
    local ok, v = pcall(UserSettings.getIntegerForKey, Settings.prefix .. k, d)
    if ok and type(v) == "number" then return math.floor(v) end
    return d
end

function Settings.save()
    setInt("sens10", Settings.sensitivityLevel)
    setInt("invertY", Settings.invertY and 1 or 0)
    setInt("largeText", Settings.largeText and 1 or 0)
    setInt("animateText", Settings.animateText and 1 or 0)
    for _, kind in ipairs(Settings.VOLUME_KINDS) do setInt("volpct_" .. kind, Settings.volumePct[kind]) end
end

function Settings.load()
    Settings.setSensitivity(getInt("sens10", DEFAULTS.sensitivity))
    Settings.invertY = getInt("invertY", DEFAULTS.invertY and 1 or 0) == 1
    Settings.largeText = getInt("largeText", DEFAULTS.largeText and 1 or 0) == 1
    Settings.animateText = getInt("animateText", DEFAULTS.animateText and 1 or 0) == 1
    for _, kind in ipairs(Settings.VOLUME_KINDS) do
        Settings.setVolume(kind, getInt("volpct_" .. kind, DEFAULTS.volume[kind]))
    end
end

function Settings.isDefault()
    if Settings.sensitivityLevel ~= DEFAULTS.sensitivity or Settings.invertY ~= DEFAULTS.invertY
        or Settings.largeText ~= DEFAULTS.largeText or Settings.animateText ~= DEFAULTS.animateText then
        return false
    end
    for _, kind in ipairs(Settings.VOLUME_KINDS) do
        if Settings.volumePct[kind] ~= DEFAULTS.volume[kind] then return false end
    end
    return true
end

function Settings.resetDefaults()
    Settings.sensitivityLevel = DEFAULTS.sensitivity
    Settings.invertY = DEFAULTS.invertY
    Settings.largeText = DEFAULTS.largeText
    Settings.animateText = DEFAULTS.animateText
    for _, kind in ipairs(Settings.VOLUME_KINDS) do Settings.volumePct[kind] = DEFAULTS.volume[kind] end
    Settings.save()
end

return Settings
