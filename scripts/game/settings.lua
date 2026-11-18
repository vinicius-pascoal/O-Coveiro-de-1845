-- Opções do jogador, compartilhadas entre as cenas World e HUD.
-- Valem durante a sessão (o GDD deixa salvamento persistente fora do escopo).

local Settings = {}

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

-- Volume: "master" vale para todos os sons; "ambient" só para o vento e as rajadas
Settings.volumeLevels = {
    { label = "Mudo", value = 0 },
    { label = "25%", value = 0.25 },
    { label = "50%", value = 0.5 },
    { label = "75%", value = 0.75 },
    { label = "100%", value = 1.0 },
}
Settings.volumeIndex = { master = 5, ambient = 5 }

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

return Settings
