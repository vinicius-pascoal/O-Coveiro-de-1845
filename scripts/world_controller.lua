-- GameController / PlayerController / InteractionController da cena World.
-- Primeira pessoa: WASD move o Character3D "Player", o mouse gira a câmera filha
-- e a mira no centro da tela seleciona objetos (raio contra a AABB de cada um).
-- Também aplica as mudanças visuais pedidas pelo Flow (luz do caso, velas, névoa).

local Flow = require("game.flow")
local Settings = require("game.settings")

local WorldController = {
    properties = {
        { name = "walkSpeed", displayName = "Walk Speed", type = "float", default = 3.0 },
        { name = "runSpeed", displayName = "Run Speed", type = "float", default = 5.2 },
        { name = "mouseSensitivity", displayName = "Mouse Sensitivity", type = "float", default = 0.14 },
        { name = "interactDistance", displayName = "Interact Distance", type = "float", default = 3.4 },
    }
}

-- Objetos interativos: nome da entidade na cena -> o que representam
local HOTSPOTS = {
    { name = "Grave01", kind = "grave", grave = 1 },
    { name = "Grave02", kind = "grave", grave = 2 },
    { name = "Grave03", kind = "grave", grave = 3 },
    { name = "Grave04", kind = "grave", grave = 4 },
    { name = "Grave05", kind = "grave", grave = 5 },
    { name = "Grave06", kind = "grave", grave = 6 },
    { name = "Grave07", kind = "grave", grave = 7 },
    { name = "RecordBook", kind = "book" },
    { name = "DeskTable", kind = "book" },
    { name = "Crypt", kind = "crypt" },
}

-- Atmosfera por noite (cores sRGB). zenith/moonDisc/stars/clouds alimentam o shader do céu.
local NIGHT_LOOK = {
    [1] = { fog = { 0.08, 0.09, 0.14 }, density = 0.045, moon = { 0.60, 0.70, 1.00 }, moonI = 1.6,
            zenith = { 0.025, 0.035, 0.075 }, moonDisc = { 0.85, 0.90, 1.00 }, stars = 1.0, clouds = 0.50 },
    [2] = { fog = { 0.07, 0.10, 0.10 }, density = 0.050, moon = { 0.55, 0.78, 0.80 }, moonI = 1.4,
            zenith = { 0.020, 0.045, 0.055 }, moonDisc = { 0.80, 0.95, 0.90 }, stars = 0.8, clouds = 0.62 },
    [3] = { fog = { 0.11, 0.06, 0.07 }, density = 0.058, moon = { 0.78, 0.60, 0.70 }, moonI = 1.2,
            zenith = { 0.045, 0.020, 0.035 }, moonDisc = { 1.00, 0.72, 0.65 }, stars = 0.5, clouds = 0.75 },
}

local ENDING_LOOK = {
    preserve = { fog = { 0.05, 0.05, 0.07 }, density = 0.090, moon = { 0.45, 0.50, 0.70 }, moonI = 0.8,
                 zenith = { 0.012, 0.014, 0.025 }, moonDisc = { 0.50, 0.55, 0.65 }, stars = 0.1, clouds = 0.92 },
    reveal   = { fog = { 0.16, 0.13, 0.12 }, density = 0.020, moon = { 1.00, 0.90, 0.80 }, moonI = 2.4,
                 zenith = { 0.060, 0.070, 0.130 }, moonDisc = { 1.00, 0.95, 0.85 }, stars = 1.8, clouds = 0.25 },
}

local function srgbToLinear(c)
    return Vector3(c[1] ^ 2.2, c[2] ^ 2.2, c[3] ^ 2.2)
end

local UP = Vector3(0, 1, 0)
local RIGHT = Vector3(1, 0, 0)

local function find(scene, name)
    local e = scene:findEntity(name)
    if e == nil or e == 0 then
        Log.warn("WorldController: entity not found: " .. name)
        return nil
    end
    return e
end

local function key(k) return Input.isKeyPressed(k) end

function WorldController:init()
    local s = self.scene

    -- Jogador e câmera
    local playerEntity = find(s, "Player")
    self.player = Object(s, playerEntity)
    self.character = Character3D(s, playerEntity)
    self.startPosition = self.player.position
    self.camera = Camera(s, find(s, "MainCamera"))
    self.camera:disableTarget()
    self.yaw, self.pitch = 0, -4
    self:applyLook()

    -- Objetos interativos
    self.hotspots = {}
    for _, h in ipairs(HOTSPOTS) do
        local e = find(s, h.name)
        if e then
            self.hotspots[#self.hotspots + 1] = {
                entity = e, kind = h.kind, grave = h.grave, name = h.name,
                mesh = Mesh(s, e),
            }
        end
    end

    -- Luzes e efeitos
    self.hoverLight = Light(s, find(s, "HoverLight"))
    self.caseLight = Light(s, find(s, "CaseLight"))
    self.hoverLightIntensity = self.hoverLight.intensity
    self.caseLightIntensity = self.caseLight.intensity
    self.hoverLight.intensity = 0
    self.caseLight.intensity = 0

    local wispEntity = s:findEntity("Wisp")
    if wispEntity and wispEntity ~= 0 then
        self.wisp = Object(s, wispEntity)
        self.wisp.visible = false
    end

    self.fog = Fog(s, find(s, "Fog"))
    self.moon = Light(s, find(s, "Moon"))
    local skyEntity = find(s, "Sky")
    if skyEntity then
        self.sky = SkyBox(s, skyEntity)
        -- a lua do céu fica do lado oposto à direção da luz
        local d = self.moon.direction
        local len = math.sqrt(d.x * d.x + d.y * d.y + d.z * d.z)
        self.sky:setShaderUniform("moonDirection", Vector3(-d.x / len, -d.y / len, -d.z / len))
    end
    self.baseFogDensity = self.fog.density
    self.extraFog = 0

    self.candles = {}
    for i = 1, 7 do
        local e = s:findEntity(string.format("Candle%02d", i))
        if e and e ~= 0 then
            self.candles[i] = Object(s, e)
            self.candles[i].visible = false
        end
    end

    self.focused = nil
    self.captured = false
    self.lastMouse = nil
    Flow.worldController = self

    RegisterEngineEvent(self, "onMouseDown")
    RegisterEngineEvent(self, "onMouseMove")
    RegisterEngineEvent(self, "onKeyDown")
    RegisterEngineEvent(self, "onUpdate")
    RegisterEngineEvent(self, "onFixedUpdate")

    Flow.on("reset", "world", function() self:resetVisuals() end)
    Flow.on("nightStarted", "world", function(n) self:applyAtmosphere(NIGHT_LOOK[n] or NIGHT_LOOK[1]) end)
    Flow.on("caseStarted", "world", function(case) self:markCase(case) end)
    Flow.on("caseResolved", "world", function(case) self:onCaseResolved(case) end)
    Flow.on("mistake", "world", function() self:onMistake() end)
    Flow.on("ending", "world", function(kind) self:onEnding(kind) end)

    self:resetVisuals()
end

----------------------------------------------------------------------
-- Estado de controle
----------------------------------------------------------------------
function WorldController:canInteract()
    return Flow.state.phase == "playing" and not Flow.state.modalOpen
end

-- Mouse preso durante a exploração, solto em painéis e menus
function WorldController:syncMouseMode()
    local want = self:canInteract()
    if want ~= self.captured then
        self.captured = want
        self.lastMouse = nil
        Engine.mouseMode = want and MouseMode.CAPTURED or MouseMode.NORMAL
    end
end

----------------------------------------------------------------------
-- Olhar e movimento
----------------------------------------------------------------------
function WorldController:applyLook()
    self.camera.rotation = Quaternion(self.yaw, UP) * Quaternion(self.pitch, RIGHT)
end

function WorldController:onMouseMove(x, y, mods)
    if not self.captured then
        self.lastMouse = nil
        return
    end
    if self.lastMouse then
        local dx, dy = x - self.lastMouse[1], y - self.lastMouse[2]
        -- saltos grandes acontecem quando o cursor é capturado/recentralizado
        if math.abs(dx) < 400 and math.abs(dy) < 400 then
            -- a opção do jogador escala a sensibilidade-base do editor (0.14 = Média)
            local sens = self.mouseSensitivity * Settings.sensitivity() / 0.14
            if Settings.invertY then dy = -dy end
            self.yaw = (self.yaw - dx * sens) % 360
            self.pitch = math.max(-80, math.min(80, self.pitch - dy * sens))
            self:applyLook()
        end
    end
    self.lastMouse = { x, y }
end

function WorldController:onFixedUpdate()
    if not self.character then return end
    if not self:canInteract() then
        self.character.moveVelocity = Vector3(0, 0, 0)
        return
    end
    local f, r = 0, 0
    if key(Input.KEY_W) or key(Input.KEY_UP) then f = f + 1 end
    if key(Input.KEY_S) or key(Input.KEY_DOWN) then f = f - 1 end
    if key(Input.KEY_D) or key(Input.KEY_RIGHT) then r = r + 1 end
    if key(Input.KEY_A) or key(Input.KEY_LEFT) then r = r - 1 end

    local speed = (key(Input.KEY_LEFT_SHIFT) or key(Input.KEY_RIGHT_SHIFT)) and self.runSpeed or self.walkSpeed
    local rad = math.rad(self.yaw)
    -- yaw 0 olha para -Z; frente e direita no plano do chão
    local fx, fz = -math.sin(rad), -math.cos(rad)
    local rx, rz = math.cos(rad), -math.sin(rad)
    local vx, vz = fx * f + rx * r, fz * f + rz * r
    local len = math.sqrt(vx * vx + vz * vz)
    if len > 0 then
        vx, vz = vx / len * speed, vz / len * speed
    end
    self.character.moveVelocity = Vector3(vx, 0, vz)
end

----------------------------------------------------------------------
-- Mira e interação
----------------------------------------------------------------------
-- Devolve o objeto sob a mira (centro da tela) e a distância até ele
function WorldController:pickCenter()
    local ray = self.camera:screenToRay(Engine.canvasWidth / 2, Engine.canvasHeight / 2)
    local origin = ray.origin
    local best, bestDist = nil, math.huge
    for _, h in ipairs(self.hotspots) do
        local hit = ray:intersects(h.mesh:getWorldAABB())
        if hit and hit.hit then
            local d = (ray:getPoint(hit.distance) - origin):length()
            if d < bestDist then best, bestDist = h, d end
        end
    end
    return best, bestDist
end

function WorldController:setFocus(h)
    if h == self.focused then return end
    self.focused = h
    if h then
        local aabb = h.mesh:getWorldAABB()
        local c, size = aabb:getCenter(), aabb:getSize()
        self.hoverLight.position = Vector3(c.x, c.y + size.y * 0.5 + 0.7, c.z + 0.6)
        self.hoverLight.intensity = self.hoverLightIntensity
    else
        self.hoverLight.intensity = 0
    end
    Flow.emit("focus", h)
end

function WorldController:interact()
    if not self:canInteract() or not self.focused then return end
    local h = self.focused
    self:setFocus(nil)
    Flow.emit("worldClick", h)
end

function WorldController:onMouseDown(button, x, y, mods)
    if button == Input.MOUSE_BUTTON_LEFT then self:interact() end
end

function WorldController:onKeyDown(k, isRepeat, mods)
    if k == Input.KEY_E and not isRepeat then self:interact() end
end

----------------------------------------------------------------------
-- Mudanças visuais
----------------------------------------------------------------------
function WorldController:graveHotspot(graveIndex)
    for _, h in ipairs(self.hotspots) do
        if h.kind == "grave" and h.grave == graveIndex then return h end
    end
    return nil
end

function WorldController:markCase(case)
    local h = case and self:graveHotspot(case.grave)
    if not h then
        self.caseLight.intensity = 0
        if self.wisp then self.wisp.visible = false end
        return
    end
    local aabb = h.mesh:getWorldAABB()
    local c, size = aabb:getCenter(), aabb:getSize()
    local pos = Vector3(c.x, c.y + size.y * 0.5 + 1.1, c.z + 0.4)
    self.caseLight.position = pos
    self.caseLight.intensity = self.caseLightIntensity
    if self.wisp then
        self.wisp.position = pos
        self.wisp.visible = true
    end
end

function WorldController:onCaseResolved(case)
    if self.candles[case.grave] then
        self.candles[case.grave].visible = true
    end
    self.caseLight.intensity = 0
    if self.wisp then self.wisp.visible = false end
    -- Sobressalto sobrenatural: a lua pisca forte por um instante
    self.flash = 0.6
end

function WorldController:onMistake()
    -- Consequência simbólica: a névoa engrossa um pouco a cada erro
    self.extraFog = math.min(self.extraFog + 0.008, 0.04)
    self.fog.density = self.baseFogDensity + self.extraFog
end

function WorldController:applyAtmosphere(look)
    self.fog:setColor(look.fog[1], look.fog[2], look.fog[3])
    self.baseFogDensity = look.density
    self.fog.density = look.density + self.extraFog
    self.moon:setColor(look.moon[1], look.moon[2], look.moon[3])
    self.moonIntensity = look.moonI
    self.moon.intensity = look.moonI
    if self.sky then
        -- o horizonte do céu usa a cor da névoa para o fundo se fundir sem emenda
        self.sky:setShaderUniform("horizonColor", srgbToLinear(look.fog))
        self.sky:setShaderUniform("zenithColor", srgbToLinear(look.zenith))
        self.sky:setShaderUniform("moonColor", srgbToLinear(look.moonDisc))
        self.sky:setShaderUniform("starAmount", look.stars)
        self.sky:setShaderUniform("cloudAmount", look.clouds)
    end
end

function WorldController:onEnding(kind)
    self.caseLight.intensity = 0
    if self.wisp then self.wisp.visible = false end
    self.extraFog = 0
    self:applyAtmosphere(ENDING_LOOK[kind] or ENDING_LOOK.preserve)
end

function WorldController:resetVisuals()
    self.extraFog = 0
    self.flash = nil
    for _, c in pairs(self.candles) do c.visible = false end
    self.caseLight.intensity = 0
    self.hoverLight.intensity = 0
    if self.wisp then self.wisp.visible = false end
    self.focused = nil
    -- jogador volta ao portão olhando para o norte
    if self.character then
        self.character.position = self.startPosition
        self.character.moveVelocity = Vector3(0, 0, 0)
    end
    self.yaw, self.pitch = 0, -4
    self:applyLook()
    self:applyAtmosphere(NIGHT_LOOK[1])
end

function WorldController:onUpdate()
    local dt = Engine.deltatime
    self:syncMouseMode()

    if self:canInteract() then
        local h, dist = self:pickCenter()
        if h and dist > self.interactDistance then h = nil end
        self:setFocus(h)
    elseif self.focused then
        self:setFocus(nil)
    end

    -- Lua piscando após uma correção (reage ao estado do jogo)
    if self.flash then
        self.flash = self.flash - dt
        if self.flash <= 0 then
            self.flash = nil
            self.moon.intensity = self.moonIntensity or 1.6
        else
            self.moon.intensity = (self.moonIntensity or 1.6) * (1.0 + 2.5 * self.flash)
        end
    end
end

return WorldController
