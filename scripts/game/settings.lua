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

function Settings.sensitivity()
    return Settings.sensitivityLevels[Settings.sensitivityIndex].value
end

function Settings.sensitivityLabel()
    return Settings.sensitivityLevels[Settings.sensitivityIndex].label
end

function Settings.cycleSensitivity()
    Settings.sensitivityIndex = Settings.sensitivityIndex % #Settings.sensitivityLevels + 1
end

function Settings.toggleInvertY()
    Settings.invertY = not Settings.invertY
end

function Settings.toggleLargeText()
    Settings.largeText = not Settings.largeText
end

return Settings
