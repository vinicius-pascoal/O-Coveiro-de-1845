-- Paisagem sonora da cena World: vento, passos, rangidos e rosnados (assets/sons).
-- Os sons "no espaço" (mortos, Benedito, sussurros) são 2D com volume e pan calculados aqui
-- a partir da posição do coveiro: o AudioSystem só reposiciona fontes 3D quando outra
-- propriedade muda, e assim o vulto que anda continua soando do lugar certo.

local Flow = require("game.flow")
local Settings = require("game.settings")

local DIR = "sons/"

-- Vento contínuo: duas camadas que se cruzam conforme a noite
local WIND_A = "Ambient Wind (4).mp3"
local WIND_B = "Ambient Wind (9).mp3"
local WIND_MIX = {
    menu     = { a = 0.30, b = 0.00 },
    [1]      = { a = 0.42, b = 0.00 },
    [2]      = { a = 0.30, b = 0.22 },
    [3]      = { a = 0.12, b = 0.50 },
    preserve = { a = 0.00, b = 0.55 },
    reveal   = { a = 0.16, b = 0.00 },
}
local GUSTS = { "Ambient Wind (1).mp3", "Ambient Wind (2).mp3", "Ambient Wind (5).mp3",
                "Ambient Wind (6).mp3", "Ambient Wind (7).mp3", "Ambient Wind (8).mp3" }

-- Passos do coveiro: cascalho no caminho central, lama no resto do cemitério
local STEPS = {
    gravel = { file = "Gravel Footsteps (5).mp3", volume = 0.55 },
    mud    = { file = "Mud Footsteps (2).mp3", volume = 0.60 },
}
local GUIDE_STEPS = "Stair Footsteps (3).mp3"      -- Benedito andando
local PHANTOM_STEPS = { "Wooden Foosteps (1).mp3", "Wooden Foosteps (4).mp3", "Wooden Foosteps (6).mp3" }

local CREAKS_SHORT = { "Creaking Door (2).mp3", "Creaking Door (6).mp3", "Creaking Door (7).mp3",
                       "Creaking Door (8).mp3", "Creaking Door (12).mp3" }
local GATE_CREAK = "Creaking Door (4).mp3"
local CRYPT_CREAK = "Creaking Door (11).mp3"
local GROWLS_RISE = { "Monster Growl (2).mp3", "Monster Growl (3).mp3", "Monster Growl (4).mp3",
                      "Monster Growl (9).mp3", "Monster Growl (11).mp3" }
local GROWLS_HIT = { "Monster Growl (6).mp3", "Monster Growl (8).mp3" }
local GROWL_TAUNT = "Monster Growl (7).mp3"
local GROWL_MISTAKE = "Monster Growl (12).mp3"
local GROWL_REST = "Monster Growl (1).mp3"
local GROWL_PRESERVE = "Monster Growl (5).mp3"

-- Caminho de cascalho (Path_01..17 e o começo da estrada, em x = 0)
local PATH_HALF_WIDTH = 1.05
local PATH_Z_MIN, PATH_Z_MAX = -14.6, 21.0

local MOVE_SPEED_MIN = 0.6      -- m/s abaixo disso o coveiro está parado
local STEP_FADE = 8.0           -- quão rápido os passos sobem/descem de volume
local HEAR_DISTANCE = 16.0      -- além disso um som do cemitério não se ouve

local Soundscape = {}
Soundscape.__index = Soundscape

local function pick(list) return list[math.random(#list)] end

function Soundscape.new(scene, world)
    local self = setmetatable({ scene = scene, world = world, sounds = {}, failed = {} }, Soundscape)
    self.windA = self:loop(WIND_A)
    self.windB = self:loop(WIND_B)
    self.windTarget = WIND_MIX.menu
    self.windLevel = { a = 0, b = 0 }
    self.steps = {}
    for surface, def in pairs(STEPS) do
        self.steps[surface] = { sound = self:loop(def.file), base = def.volume, level = 0, playing = false }
    end
    self.guideSteps = { sound = self:loop(GUIDE_STEPS), base = 0.5, level = 0, playing = false }
    self.gustTimer = 6
    self.phantomTimer = 50
    self.stillTime = 0
    self:startLoop(self.windA, 0)
    self:startLoop(self.windB, 0)
    self:listen()
    return self
end

----------------------------------------------------------------------
-- Criação e disparo
----------------------------------------------------------------------
-- Um Sound por arquivo, criado na primeira vez que é pedido
function Soundscape:get(file)
    local snd = self.sounds[file]
    if snd then return snd end
    if self.failed[file] then return nil end
    local ok, result = pcall(function()
        local s = Sound(self.scene)
        s:loadSound(DIR .. file)
        return s
    end)
    if not ok then
        self.failed[file] = true
        Log.warn("Soundscape: could not load " .. file .. ": " .. tostring(result))
        return nil
    end
    self.sounds[file] = result
    return result
end

function Soundscape:loop(file)
    local s = self:get(file)
    if s then
        s.looping = true
        s.protectVoice = true
    end
    return s
end

function Soundscape:startLoop(s, volume)
    if not s then return end
    s.volume = volume
    s:play()
end

-- Volume escolhido nas Opções (ambient = vento e rajadas)
local function mix(ambient)
    local v = Settings.volume("master")
    if ambient then v = v * Settings.volume("ambient") end
    return v
end

-- Toca um som uma vez. opts: volume, pan, speed, ambient
function Soundscape:play(file, opts)
    opts = opts or {}
    local volume = (opts.volume or 0.6) * mix(opts.ambient)
    if volume <= 0 then return end
    local s = self:get(file)
    if not s then return end
    s.volume = volume
    s.pan = opts.pan or 0
    s.speed = opts.speed or 1.0
    s:play()
end

-- Volume e pan de algo que soa em (x, z), ouvido de onde o coveiro está e para onde olha
function Soundscape:placement(x, z)
    local w = self.world
    local p = w.player.position
    local dx, dz = x - p.x, z - p.z
    local d = math.sqrt(dx * dx + dz * dz)
    local gain = math.max(0, 1 - d / HEAR_DISTANCE)
    gain = gain * gain
    local pan = 0
    if d > 0.3 then
        local rad = math.rad(w.yaw or 0)
        local rx, rz = math.cos(rad), -math.sin(rad)
        pan = (dx * rx + dz * rz) / d * 0.85
    end
    return gain, pan
end

function Soundscape:playAt(file, x, z, volume, minGain)
    local gain, pan = self:placement(x, z)
    gain = math.max(gain, minGain or 0)
    if gain < 0.02 then return end
    self:play(file, { volume = volume * gain, pan = pan })
end

----------------------------------------------------------------------
-- Eventos do jogo
----------------------------------------------------------------------
function Soundscape:spiritPos(caseId)
    local sp = self.world.spirits and self.world.spirits[caseId]
    if sp then
        local p = sp.object.position
        return p.x, p.z
    end
end

function Soundscape:listen()
    Flow.on("reset", "audio", function() self.windTarget = WIND_MIX.menu end)
    Flow.on("nightStarted", "audio", function(n)
        self.windTarget = WIND_MIX[n] or WIND_MIX[1]
        -- o portão range atrás do coveiro quando a noite começa
        self:play(GATE_CREAK, { volume = 0.45, pan = 0 })
        self.phantomTimer = 45 + math.random() * 40
    end)
    Flow.on("nightEnded", "audio", function()
        self:play(pick(GUSTS), { volume = 0.5, ambient = true })
    end)
    Flow.on("spiritAwake", "audio", function(case)
        local x, z = self:spiritPos(case.id)
        if x then self:playAt(pick(GROWLS_RISE), x, z, 0.75, 0.35) end
    end)
    Flow.on("spiritReact", "audio", function(case, kind)
        local x, z = self:spiritPos(case.id)
        if not x then return end
        if kind == "taunt" then
            self:playAt(GROWL_TAUNT, x, z, 0.7, 0.4)
        elseif kind == "hit" then
            self:playAt(pick(GROWLS_HIT), x, z, 0.65, 0.4)
        end
    end)
    Flow.on("mistake", "audio", function()
        self:play(GROWL_MISTAKE, { volume = 0.35, speed = 0.85 })
    end)
    Flow.on("caseResolved", "audio", function(case)
        -- o morto solta o último suspiro e se deita
        local x, z = self:spiritPos(case.id)
        if x then self:playAt(GROWL_REST, x, z, 0.45, 0.3) end
    end)
    Flow.on("worldClick", "audio", function(h)
        if h.kind == "crypt" or (h.kind == "paper" and h.place == "crypt") then
            self:play(CRYPT_CREAK, { volume = 0.5 })
        end
    end)
    Flow.on("whisper", "audio", function(w)
        if w.x then self:playAt(pick(CREAKS_SHORT), w.x, w.z, 0.5, 0.25) end
    end)
    Flow.on("finale", "audio", function(kind)
        if kind == "preserve" then self:play(GROWL_PRESERVE, { volume = 0.55, speed = 0.9 }) end
    end)
    Flow.on("ending", "audio", function(kind)
        self.windTarget = WIND_MIX[kind] or WIND_MIX.preserve
    end)
end

----------------------------------------------------------------------
-- A cada quadro
----------------------------------------------------------------------
local function approach(v, target, rate, dt)
    if v < target then return math.min(target, v + rate * dt) end
    return math.max(target, v - rate * dt)
end

-- Sobe/desce o volume de um loop e pausa quando chega a zero (para retomar do mesmo ponto)
function Soundscape:driveLoop(l, target, dt, speed)
    if not l.sound then return end
    l.level = approach(l.level, target, STEP_FADE, dt)
    if l.level > 0.001 then
        l.sound.volume = l.base * l.level * (l.gain or 1) * mix(false)
        if l.pan then l.sound.pan = l.pan end
        if speed then l.sound.speed = speed end
        if not l.playing then
            l.sound:play()
            l.playing = true
        end
    elseif l.playing then
        l.sound:pause()
        l.playing = false
    end
end

function Soundscape:surfaceAt(x, z)
    if math.abs(x) <= PATH_HALF_WIDTH and z >= PATH_Z_MIN and z <= PATH_Z_MAX then return "gravel" end
    return "mud"
end

function Soundscape:update(dt)
    if dt <= 0 then return end
    local w = self.world
    local state = Flow.state

    -- vento
    local t = self.windTarget
    self.windLevel.a = approach(self.windLevel.a, t.a, 0.12, dt)
    self.windLevel.b = approach(self.windLevel.b, t.b, 0.12, dt)
    local windMix = mix(true)
    if self.windA then self.windA.volume = self.windLevel.a * windMix end
    if self.windB then self.windB.volume = self.windLevel.b * windMix end

    -- passos do coveiro: pela velocidade real (parado contra a cerca não faz barulho)
    -- a física anda em passo fixo: suaviza para não piscar entre quadros sem movimento
    local p = w.player.position
    local raw = 0
    if self.lastPos then
        local dx, dz = p.x - self.lastPos.x, p.z - self.lastPos.z
        raw = math.min(20, math.sqrt(dx * dx + dz * dz) / dt)
    end
    self.lastPos = p
    self.speed = (self.speed or 0) + (raw - (self.speed or 0)) * math.min(1, dt * 10)
    local speed = self.speed
    local walking = w:canInteract() and speed > MOVE_SPEED_MIN
    local surface = self:surfaceAt(p.x, p.z)
    local running = speed > (w.walkSpeed + w.runSpeed) * 0.5
    for name, l in pairs(self.steps) do
        self:driveLoop(l, (walking and name == surface) and 1 or 0, dt, running and 1.3 or 1.0)
    end

    -- passos de Benedito enquanto ele caminha
    local g = w.guide
    local gl = self.guideSteps
    if g and g.mode == "walk" and g.object.visible then
        local gp = g.object.position
        gl.gain, gl.pan = self:placement(gp.x, gp.z)
        self:driveLoop(gl, 1, dt)
    else
        self:driveLoop(gl, 0, dt)
    end

    if state.phase ~= "playing" then return end

    -- rajadas de vento de um lado ou de outro
    self.gustTimer = self.gustTimer - dt
    if self.gustTimer <= 0 then
        self.gustTimer = 14 + math.random() * 18
        self:play(pick(GUSTS), { volume = 0.18 + math.random() * 0.17, pan = (math.random() - 0.5) * 1.2, ambient = true })
    end

    -- noites 2 e 3: passos de alguém que não está lá, quando o coveiro fica parado
    if state.modalOpen or walking then
        self.stillTime = 0
    else
        self.stillTime = self.stillTime + dt
    end
    if state.night >= 2 then
        self.phantomTimer = self.phantomTimer - dt
        if self.phantomTimer <= 0 and self.stillTime > 3 then
            self.phantomTimer = 70 + math.random() * 60
            local side = math.random() < 0.5 and -0.8 or 0.8
            self:play(pick(PHANTOM_STEPS), { volume = 0.22, pan = side })
            self.phantomStop = 2.6
        end
    end
    -- os passos fantasmas são trechos curtos de um arquivo longo
    if self.phantomStop then
        self.phantomStop = self.phantomStop - dt
        if self.phantomStop <= 0 then
            self.phantomStop = nil
            for _, f in ipairs(PHANTOM_STEPS) do
                local s = self.sounds[f]
                if s then s:stop() end
            end
        end
    end
end

return Soundscape
