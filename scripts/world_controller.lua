-- GameController / InteractionController / GraveController da cena World.
-- Faz a seleção 3D (raio da câmera contra a AABB de cada objeto clicável),
-- move as luzes de hover e de caso e aplica as mudanças visuais pedidas pelo Flow.

local Flow = require("game.flow")

local WorldController = {
    properties = {}
}

-- Objetos clicáveis: nome da entidade na cena -> o que representam
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

-- Atmosfera por noite (cores sRGB)
local NIGHT_LOOK = {
    [1] = { fog = { 0.08, 0.09, 0.14 }, density = 0.022, moon = { 0.60, 0.70, 1.00 }, moonI = 1.6 },
    [2] = { fog = { 0.07, 0.10, 0.10 }, density = 0.026, moon = { 0.55, 0.78, 0.80 }, moonI = 1.4 },
    [3] = { fog = { 0.11, 0.06, 0.07 }, density = 0.030, moon = { 0.78, 0.60, 0.70 }, moonI = 1.2 },
}

local ENDING_LOOK = {
    preserve = { fog = { 0.05, 0.05, 0.07 }, density = 0.055, moon = { 0.45, 0.50, 0.70 }, moonI = 0.8 },
    reveal   = { fog = { 0.16, 0.13, 0.12 }, density = 0.010, moon = { 1.00, 0.90, 0.80 }, moonI = 2.4 },
}

local function find(scene, name)
    local e = scene:findEntity(name)
    if e == nil or e == 0 then
        Log.warn("WorldController: entity not found: " .. name)
        return nil
    end
    return e
end

function WorldController:init()
    -- scene.camera ainda pode ser a câmera padrão durante o init; usar a câmera da cena pelo nome
    local camEntity = self.scene:findEntity("MainCamera")
    if camEntity == nil or camEntity == 0 then camEntity = self.scene.camera end
    self.camera = Camera(self.scene, camEntity)

    self.hotspots = {}
    for _, h in ipairs(HOTSPOTS) do
        local e = find(self.scene, h.name)
        if e then
            self.hotspots[#self.hotspots + 1] = {
                entity = e, kind = h.kind, grave = h.grave, name = h.name,
                mesh = Mesh(self.scene, e),
            }
        end
    end

    self.hoverLight = Light(self.scene, find(self.scene, "HoverLight"))
    self.caseLight = Light(self.scene, find(self.scene, "CaseLight"))
    self.hoverLightIntensity = self.hoverLight.intensity
    self.caseLightIntensity = self.caseLight.intensity
    self.hoverLight.intensity = 0
    self.caseLight.intensity = 0

    local wispEntity = self.scene:findEntity("Wisp")
    if wispEntity and wispEntity ~= 0 then
        self.wisp = Object(self.scene, wispEntity)
        self.wisp.visible = false
    end

    self.fog = Fog(self.scene, find(self.scene, "Fog"))
    self.moon = Light(self.scene, find(self.scene, "Moon"))
    self.baseFogDensity = self.fog.density
    self.extraFog = 0

    self.candles = {}
    for i = 1, 7 do
        local e = self.scene:findEntity(string.format("Candle%02d", i))
        if e and e ~= 0 then
            self.candles[i] = Object(self.scene, e)
            self.candles[i].visible = false
        end
    end

    self.hovered = nil
    self.time = 0
    Flow.worldController = self

    RegisterEngineEvent(self, "onMouseDown")
    RegisterEngineEvent(self, "onMouseMove")
    RegisterEngineEvent(self, "onUpdate")

    Flow.on("reset", "world", function() self:resetVisuals() end)
    Flow.on("nightStarted", "world", function(n) self:applyLook(NIGHT_LOOK[n] or NIGHT_LOOK[1]) end)
    Flow.on("caseStarted", "world", function(case) self:markCase(case) end)
    Flow.on("caseResolved", "world", function(case) self:onCaseResolved(case) end)
    Flow.on("mistake", "world", function() self:onMistake() end)
    Flow.on("ending", "world", function(kind) self:onEnding(kind) end)
    Flow.on("modalChanged", "world", function(open) if open then self:setHover(nil) end end)

    self:resetVisuals()
end

----------------------------------------------------------------------
-- Seleção
----------------------------------------------------------------------
function WorldController:pick(x, y)
    if not self.camera then return nil end
    local ray = self.camera:screenToRay(x, y)
    local best, bestDist = nil, math.huge
    for _, h in ipairs(self.hotspots) do
        local aabb = h.mesh:getWorldAABB()
        local hit = ray:intersects(aabb)
        if hit and hit.hit and hit.distance < bestDist then
            best, bestDist = h, hit.distance
        end
    end
    return best
end

function WorldController:hotspotCenter(h)
    local aabb = h.mesh:getWorldAABB()
    return aabb:getCenter(), aabb:getSize()
end

function WorldController:setHover(h, x, y)
    if h == self.hovered then
        if h then Flow.emit("hover", h, x, y) end
        return
    end
    self.hovered = h
    if h then
        local c, size = self:hotspotCenter(h)
        Object(self.scene, self.hoverLight.entity).position = Vector3(c.x, c.y + size.y * 0.5 + 0.8, c.z + 1.0)
        self.hoverLight.intensity = self.hoverLightIntensity
    else
        self.hoverLight.intensity = 0
    end
    Flow.emit("hover", h, x, y)
end

function WorldController:canInteract()
    return Flow.state.phase == "playing" and not Flow.state.modalOpen
end

function WorldController:onMouseMove(x, y, mods)
    if not self:canInteract() then
        if self.hovered then self:setHover(nil) end
        return
    end
    self:setHover(self:pick(x, y), x, y)
end

function WorldController:onMouseDown(button, x, y, mods)
    if button ~= Input.MOUSE_BUTTON_LEFT then return end
    if not self:canInteract() then return end
    local h = self:pick(x, y)
    if h then
        self:setHover(nil)
        Flow.emit("worldClick", h)
    end
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
    local c, size = self:hotspotCenter(h)
    self.caseBase = Vector3(c.x, c.y + size.y * 0.5 + 1.1, c.z + 0.4)
    Object(self.scene, self.caseLight.entity).position = self.caseBase
    self.caseLight.intensity = self.caseLightIntensity
    if self.wisp then
        self.wisp.position = self.caseBase
        self.wisp.visible = true
    end
end

function WorldController:onCaseResolved(case)
    if self.candles[case.grave] then
        self.candles[case.grave].visible = true
    end
    self.caseLight.intensity = 0
    if self.wisp then self.wisp.visible = false end
    -- Pequeno sobressalto sobrenatural: a lua pisca forte por um instante
    self.flash = 0.6
end

function WorldController:onMistake()
    -- Consequência simbólica: a névoa engrossa um pouco a cada erro
    self.extraFog = math.min(self.extraFog + 0.006, 0.03)
    self.fog.density = self.baseFogDensity + self.extraFog
end

function WorldController:applyLook(look)
    self.fog:setColor(look.fog[1], look.fog[2], look.fog[3])
    self.baseFogDensity = look.density
    self.fog.density = look.density + self.extraFog
    self.moon:setColor(look.moon[1], look.moon[2], look.moon[3])
    self.moonIntensity = look.moonI
    self.moon.intensity = look.moonI
end

function WorldController:onEnding(kind)
    self.caseLight.intensity = 0
    if self.wisp then self.wisp.visible = false end
    self.extraFog = 0
    self:applyLook(ENDING_LOOK[kind] or ENDING_LOOK.preserve)
end

function WorldController:resetVisuals()
    self.extraFog = 0
    self.flash = nil
    for _, c in pairs(self.candles) do c.visible = false end
    self.caseLight.intensity = 0
    self.hoverLight.intensity = 0
    if self.wisp then self.wisp.visible = false end
    self.hovered = nil
    self:applyLook(NIGHT_LOOK[1])
end

function WorldController:onUpdate()
    local dt = Engine.deltatime
    self.time = self.time + dt

    -- Lua piscando após uma correção (reage ao estado do jogo, não é animação fixa)
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
