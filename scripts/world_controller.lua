-- GameController / PlayerController / InteractionController da cena World.
-- Primeira pessoa: WASD move o Character3D "Player", o mouse gira a câmera filha
-- e a mira no centro da tela seleciona objetos (raio contra a AABB de cada um).
-- Também aplica as mudanças visuais pedidas pelo Flow (luz do caso, velas, névoa).

local Flow = require("game.flow")
local Settings = require("game.settings")
local N = require("game.narrative")

-- Esqueletos dos mortos: duração (s) das animações que tocam uma vez
local ANIM_LEN = {
    Skeletons_Awaken_Floor = 2.3, Skeletons_Death = 2.0, Skeletons_Taunt = 1.03,
    Hit_A = 0.67, Interact = 1.3,
}
local REACTION_ANIM = { taunt = "Skeletons_Taunt", hit = "Hit_A", nod = "Interact" }
local SPIRIT_WAKE_RADIUS = 4.5
local SPIRIT_TURN_SPEED = 4.0   -- quão rápido o morto se vira para o coveiro

-- Cinzel: segurar E (ou o botão do mouse) diante da lápide grava a correção
local CHISEL_TIME = 2.4        -- segundos segurando
local CHISEL_DECAY = 0.6       -- quanto do progresso se perde por segundo ao soltar
local CHISEL_STRIKE = 0.42     -- intervalo entre as batidas do cinzel

-- Benedito, o guia
local GUIDE_SPEED = 1.35        -- metros por segundo andando
local GUIDE_LIE_TIME = 3.0      -- duração de Lie_Down
local GUIDE_SKIP_RADIUS = 5.0   -- noite 3: se o coveiro chegar antes à cova 01, ele já está lá
ANIM_LEN.Lie_Down = 3.0
ANIM_LEN.Waving = 2.13

local TRAIL_CANDLES = 6
local TRAIL_STEP = 0.45   -- segundos entre uma vela da trilha e a próxima

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
                mesh = Mesh(s, e), enabled = true,
            }
        end
    end
    -- Papéis avulsos: só aparecem (e só respondem à mira) quando guardam um documento de caso aberto
    for place, p in pairs(N.places) do
        local e = find(s, p.entity)
        if e then
            local h = { entity = e, kind = "paper", place = place, name = p.entity,
                        mesh = Mesh(s, e), object = Object(s, e), enabled = false }
            h.object.visible = false
            self.hotspots[#self.hotspots + 1] = h
        end
    end

    -- Os mortos de cada caso (esqueletos animados ao lado das covas)
    self.spirits = {}
    for caseId, data in pairs(N.spirits or {}) do
        local e = find(s, data.entity)
        if e then
            local sp = { caseId = caseId, entity = e, model = Model(s, e), object = Object(s, e), state = "hidden" }
            sp.home = sp.object.position
            sp.yaw = 0
            sp.object.visible = false
            -- a mira usa uma caixa do tamanho de uma pessoa em volta do esqueleto
            local h = { kind = "spirit", caseId = caseId, name = data.entity, enabled = false, spirit = sp }
            h.box = function()
                local p = sp.object.position
                return AABB(Vector3(p.x - 0.45, p.y, p.z - 0.45), Vector3(p.x + 0.45, p.y + 1.7, p.z + 0.45))
            end
            sp.hotspot = h
            self.hotspots[#self.hotspots + 1] = h
            self.spirits[caseId] = sp
        end
    end

    -- Benedito, o vulto que guia as noites
    local guideEntity = s:findEntity(N.benedito.entity)
    if guideEntity and guideEntity ~= 0 then
        self.guide = { model = Model(s, guideEntity), object = Object(s, guideEntity), yaw = 0, mode = "hidden" }
        self.guide.object.visible = false
    end

    -- Trilha de velas da noite 3 (da mesa até a primeira cova)
    self.trail = {}
    for i = 1, TRAIL_CANDLES do
        local e = s:findEntity("TrailCandle" .. i)
        if e and e ~= 0 then
            self.trail[#self.trail + 1] = Object(s, e)
        end
    end

    -- Luzes e efeitos
    self.hoverLight = Light(s, find(s, "HoverLight"))
    self.hoverLightIntensity = self.hoverLight.intensity
    self.hoverLight.intensity = 0

    -- Uma luz fria + fogo-fátuo para cada caso aberto na noite (até dois ao mesmo tempo)
    self.markers = {}
    for i, suffix in ipairs({ "", "2" }) do
        local lightEntity = s:findEntity("CaseLight" .. suffix)
        if lightEntity and lightEntity ~= 0 then
            local m = { light = Light(s, lightEntity) }
            m.intensity = m.light.intensity
            m.light.intensity = 0
            local wispEntity = s:findEntity("Wisp" .. suffix)
            if wispEntity and wispEntity ~= 0 then
                m.wisp = Object(s, wispEntity)
                m.wisp.visible = false
            end
            self.markers[i] = m
        end
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
    Flow.on("nightStarted", "world", function(n)
        self:applyAtmosphere(NIGHT_LOOK[n] or NIGHT_LOOK[1])
        if n == 3 then self:startTrail() end
        self:startGuide(n)
    end)
    Flow.on("finale", "world", function(kind)
        self:scribeFinale(kind)
        self:guideFinale(kind)
    end)
    Flow.on("casesChanged", "world", function()
        self:markCases(Flow.openCases())
        self:refreshPapers()
        self:refreshSpirits()
    end)
    Flow.on("spiritAwake", "world", function(case) self:wakeSpirit(case.id) end)
    Flow.on("spiritReact", "world", function(case, kind) self:spiritReact(case.id, kind) end)
    Flow.on("talk", "world", function(case) self.talkTarget = self.spirits[case.id] end)
    Flow.on("talkEnd", "world", function() self.talkTarget = nil end)
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
        local hit = h.enabled and ray:intersects(h.box and h.box() or h.mesh:getWorldAABB())
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
        local aabb = h.box and h.box() or h.mesh:getWorldAABB()
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
    -- lápide com correção decidida: em vez de abrir o painel, começa o cinzel
    if h.kind == "grave" then
        local case = Flow.chiselCaseForGrave(h.grave)
        if case then
            self:startChisel(h, case)
            return
        end
    end
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

function WorldController:clearMarkers()
    for _, m in ipairs(self.markers) do
        m.light.intensity = 0
        if m.wisp then m.wisp.visible = false end
    end
end

-- Marca com luz fria as sepulturas de todos os casos abertos
function WorldController:markCases(cases)
    self:clearMarkers()
    for i, case in ipairs(cases or {}) do
        local m = self.markers[i]
        local h = m and self:graveHotspot(case.grave)
        if h then
            local aabb = h.mesh:getWorldAABB()
            local c, size = aabb:getCenter(), aabb:getSize()
            local pos = Vector3(c.x, c.y + size.y * 0.5 + 1.1, c.z + 0.4)
            m.light.position = pos
            m.light.intensity = m.intensity
            if m.wisp then
                m.wisp.position = pos
                m.wisp.visible = true
            end
        end
    end
end

-- Mostra os papéis dos lugares que guardam documentos de casos abertos
function WorldController:refreshPapers()
    for _, h in ipairs(self.hotspots) do
        if h.kind == "paper" then
            local active = #Flow.docsAt(h.place) > 0
            h.enabled = active
            h.object.visible = active
        end
    end
end

----------------------------------------------------------------------
-- Os mortos
----------------------------------------------------------------------
local function caseById(id)
    for _, c in ipairs(N.cases) do
        if c.id == id then return c end
    end
end

-- Toca uma animação do esqueleto; then = animação em loop que vem depois de uma que toca uma vez
function WorldController:playSpirit(sp, name, loop, thenName, fade)
    local ok, err = pcall(function()
        local anim = sp.model:findAnimation(name)
        anim.loop = loop and true or false
        sp.model:playAnimation(name, fade or 0.2)
    end)
    if not ok then
        Log.warn("Spirit animation failed (" .. name .. "): " .. tostring(err))
        return
    end
    sp.anim = name
    if thenName then
        sp.timer = ANIM_LEN[name] or 1.0
        sp.thenAnim = thenName
    else
        sp.timer, sp.thenAnim = nil, nil
    end
end

function WorldController:setSpiritState(sp, state)
    if sp.state == state then return end
    sp.state = state
    sp.object.visible = state ~= "hidden"
    sp.hotspot.enabled = (state == "awake")
    local data = N.spirits[sp.caseId] or {}
    if state == "dormant" and data.standing then
        -- o escrivão: de pé, escrevendo, voltado para a lápide lisa
        local h = self:graveHotspot(caseById(sp.caseId).grave)
        if h then
            local c, p = h.mesh:getWorldAABB():getCenter(), sp.object.position
            sp.yaw = math.deg(math.atan(c.x - p.x, c.z - p.z))
            sp.object.rotation = Quaternion(sp.yaw, UP)
        end
        self:playSpirit(sp, "Use_Item", true, nil, 0)
    elseif state == "dormant" then
        self:playSpirit(sp, "Skeletons_Inactive_Floor_Pose", true, nil, 0)
    elseif state == "awake" then
        self:playSpirit(sp, "Skeletons_Idle", true)
    elseif state == "resting" then
        self:playSpirit(sp, "Skeletons_Death_Pose", true, nil, 0)
    end
end

-- Coloca cada morto no estado que o andamento da campanha pede
function WorldController:refreshSpirits()
    for id, sp in pairs(self.spirits) do
        local case = caseById(id)
        -- o morto da cova 01 é o próprio Benedito: só aparece depois que o vulto se deita ali
        local waitsGuide = id == "c5" and not Flow.state.flags.benedito_rest
        if waitsGuide and not Flow.isResolved(case) and not Flow.isAwake(case) then
            self:setSpiritState(sp, "hidden")
        elseif Flow.isResolved(case) then
            -- o escrivão fica como a decisão final o deixou (ver scribeFinale)
            local standing = (N.spirits[id] or {}).standing
            if not standing and sp.state ~= "resting" and sp.anim ~= "Skeletons_Death" then self:setSpiritState(sp, "resting") end
        elseif Flow.isOpen(case) then
            if Flow.isAwake(case) then
                if sp.state == "hidden" or sp.state == "dormant" then self:wakeSpirit(id) end
            elseif sp.state ~= "dormant" then
                self:setSpiritState(sp, "dormant")
            end
        else
            self:setSpiritState(sp, "hidden")
        end
    end
end

-- Levanta do chão; só depois de de pé ele responde à mira
function WorldController:wakeSpirit(id)
    -- confrontar Benedito antes de ele chegar à cova encerra a caminhada do vulto
    if id == "c5" and not Flow.state.flags.benedito_rest then
        Flow.state.flags.benedito_rest = true
        if self.guide then self:hideGuide() end
    end
    local sp = self.spirits[id]
    if not sp or sp.state == "awake" or sp.state == "rising" then return end
    sp.state = "rising"
    sp.object.visible = true
    sp.hotspot.enabled = false
    if (N.spirits[id] or {}).standing then
        self:playSpirit(sp, "Interact", false, "Skeletons_Idle", 0.2)   -- larga a pena e se vira
    else
        self:playSpirit(sp, "Skeletons_Awaken_Floor", false, "Skeletons_Idle", 0)
    end
end

function WorldController:spiritReact(id, kind)
    local sp = self.spirits[id]
    local anim = REACTION_ANIM[kind]
    if sp and anim and (sp.state == "awake" or sp.state == "rising") then
        self:playSpirit(sp, anim, false, "Skeletons_Idle", 0.1)
    end
end

-- Registro corrigido: o morto desaba em paz e fica deitado
function WorldController:restSpirit(id)
    local sp = self.spirits[id]
    if not sp or sp.state == "hidden" then return end
    sp.state = "resting"
    sp.hotspot.enabled = false
    self:playSpirit(sp, "Skeletons_Death", false, "Skeletons_Death_Pose", 0.2)
end

-- Chamado a cada quadro: acorda quem está perto, vira os de pé para o coveiro, encadeia animações
function WorldController:updateSpirits(dt, px, pz, checkWake)
    for id, sp in pairs(self.spirits) do
        if sp.timer then
            sp.timer = sp.timer - dt
            if sp.timer <= 0 then
                local nextAnim = sp.thenAnim
                sp.timer, sp.thenAnim = nil, nil
                self:playSpirit(sp, nextAnim, true)
                if sp.state == "rising" then
                    sp.state = "awake"
                    sp.hotspot.enabled = true
                end
            end
        end
        if checkWake and sp.state == "dormant" then
            local h = sp.home
            local dx, dz = px - h.x, pz - h.z
            if dx * dx + dz * dz <= SPIRIT_WAKE_RADIUS * SPIRIT_WAKE_RADIUS then
                Flow.awaken(caseById(id))
            end
        end
        if sp.state == "awake" or sp.state == "rising" then
            local p = sp.object.position
            local target = math.deg(math.atan(px - p.x, pz - p.z))
            local diff = (target - sp.yaw + 540) % 360 - 180
            sp.yaw = sp.yaw + diff * math.min(1, dt * SPIRIT_TURN_SPEED)
            sp.object.rotation = Quaternion(sp.yaw, UP)
        end
    end

    -- Conversa: a câmera se volta para o rosto do morto
    local t = self.talkTarget
    if t then
        local cam = self.camera:getWorldPosition()
        local p = t.object.position
        -- mira abaixo do rosto: o morto fica na metade de cima da tela, acima do painel da conversa
        local dx, dy, dz = p.x - cam.x, p.y + (t.aimY or -0.15) - cam.y, p.z - cam.z
        local wantYaw = math.deg(math.atan(-dx, -dz))
        local wantPitch = math.deg(math.atan(dy, math.sqrt(dx * dx + dz * dz)))
        local k = math.min(1, dt * 5)
        self.yaw = self.yaw + ((wantYaw - self.yaw + 540) % 360 - 180) * k
        self.pitch = self.pitch + (wantPitch - self.pitch) * k
        self:applyLook()
    end
end

----------------------------------------------------------------------
-- Benedito, o guia das noites
----------------------------------------------------------------------
function WorldController:playGuide(name, loop, fade)
    local g = self.guide
    if not g or g.anim == name then return end
    local ok, err = pcall(function()
        g.model:findAnimation(name).loop = loop and true or false
        g.model:playAnimation(name, fade or 0.25)
    end)
    if ok then g.anim = name else Log.warn("Guide animation failed (" .. name .. "): " .. tostring(err)) end
end

function WorldController:guideSay(node)
    if node.say then Flow.emit("guideSay", node.say[1], node.say[2]) end
end

function WorldController:hideGuide()
    local g = self.guide
    if not g then return end
    g.object.visible = false
    g.mode = "hidden"
    g.anim = nil
    if self.talkTarget == g then self.talkTarget = nil end
end

function WorldController:startGuide(night)
    local g = self.guide
    if not g then return end
    local route = N.guideRoutes and N.guideRoutes[night]
    if not route or (night == 3 and Flow.state.flags.benedito_rest) then
        self:hideGuide()
        return
    end
    g.route, g.night, g.index = route, night, 1
    local first = route[1]
    g.object.position = Vector3(first.x, 0, first.z)
    g.object.visible = true
    g.anim = nil
    self:guideArrive()
end

-- Chegou ao ponto atual da rota
function WorldController:guideArrive()
    local g = self.guide
    local node = g.route[g.index]
    g.waitTime = 0
    if node.lie then
        g.mode, g.timer = "lying", GUIDE_LIE_TIME
        self:playGuide("Lie_Down", false, 0.2)
        self:guideSay(node)
    elseif node.wait or node.anim then
        g.mode = "wait"
        self:playGuide(node.anim or "Skeletons_Idle", true)
    elseif node.follow then
        g.mode = "follow"
        self:playGuide("Skeletons_Idle", true)
    else
        self:guideNext()
    end
end

function WorldController:guideNext()
    local g = self.guide
    g.index = g.index + 1
    if not g.route[g.index] then
        self:guideVanish()
        return
    end
    g.mode = "walk"
    self:playGuide("Skeletons_Walking", true)
end

function WorldController:guideVanish()
    self:hideGuide()
    self.flash = math.max(self.flash or 0, 0.3)
end

-- Noite 3: Benedito deitou na primeira cova (ou o coveiro chegou antes): o morto do caso 5 toma o lugar
function WorldController:finishGuide()
    if self.guide then self:hideGuide() end
    if not Flow.state.flags.benedito_rest then
        Flow.state.flags.benedito_rest = true
        self:refreshSpirits()
    end
end

function WorldController:faceGuide(tx, tz, dt)
    local g = self.guide
    local p = g.object.position
    local dx, dz = tx - p.x, tz - p.z
    if dx * dx + dz * dz < 0.0001 then return end
    local target = math.deg(math.atan(dx, dz))
    local diff = (target - g.yaw + 540) % 360 - 180
    g.yaw = g.yaw + diff * math.min(1, dt * 6)
    g.object.rotation = Quaternion(g.yaw, UP)
end

function WorldController:updateGuide(dt, px, pz)
    local g = self.guide
    if not g or g.mode == "hidden" or g.mode == "done" then return end
    local p = g.object.position
    local pdx, pdz = px - p.x, pz - p.z
    local playerDist = math.sqrt(pdx * pdx + pdz * pdz)

    if g.mode == "finale" then
        g.timer = g.timer - dt
        if g.finaleLine then
            g.finaleLineDelay = g.finaleLineDelay - dt
            if g.finaleLineDelay <= 0 then
                Flow.emit("guideSay", "Benedito", g.finaleLine)
                g.finaleLine = nil
            end
        end
        if g.finaleKind == "preserve" and g.timer < 2.2 then
            -- dá as costas e vai embora
            if g.anim ~= "Skeletons_Walking" then
                self:playGuide("Skeletons_Walking", true)
                g.object.rotation = Quaternion(g.yaw, UP)
            end
            local rad = math.rad(g.yaw)
            g.object.position = Vector3(p.x + math.sin(rad) * GUIDE_SPEED * dt, 0, p.z + math.cos(rad) * GUIDE_SPEED * dt)
        end
        if g.timer <= 0 then self:guideVanish() end
        return
    end

    -- noite 3: se o coveiro já está na primeira cova, o vulto já está deitado lá
    if g.night == 3 and g.mode ~= "lying" then
        local last = g.route[#g.route]
        local ldx, ldz = px - last.x, pz - last.z
        local gdx, gdz = p.x - last.x, p.z - last.z
        local guideFar = gdx * gdx + gdz * gdz > 36   -- o vulto ainda está a mais de 6 m da cova
        if guideFar and ldx * ldx + ldz * ldz <= GUIDE_SKIP_RADIUS * GUIDE_SKIP_RADIUS then
            self:finishGuide()
            return
        end
    end

    local node = g.route[g.index]
    if g.mode == "walk" then
        local dx, dz = node.x - p.x, node.z - p.z
        local d = math.sqrt(dx * dx + dz * dz)
        local step = GUIDE_SPEED * dt
        if d <= step then
            g.object.position = Vector3(node.x, 0, node.z)
            self:guideArrive()
        else
            g.object.position = Vector3(p.x + dx / d * step, 0, p.z + dz / d * step)
            self:faceGuide(node.x, node.z, dt)
        end
    elseif g.mode == "wait" then
        g.waitTime = g.waitTime + dt
        if node.faceX then self:faceGuide(node.faceX, node.faceZ, dt) else self:faceGuide(px, pz, dt) end
        if g.waitTime >= (node.delay or 1.5) and playerDist <= node.wait.near then
            self:guideSay(node)
            if node.act then
                g.mode, g.timer = "act", ANIM_LEN[node.act] or 1.2
                self:playGuide(node.act, false, 0.15)
            elseif node.vanish then
                self:guideVanish()
            else
                self:guideNext()
            end
        end
    elseif g.mode == "act" then
        self:faceGuide(px, pz, dt)
        g.timer = g.timer - dt
        if g.timer <= 0 then
            if node.vanish then self:guideVanish() else self:guideNext() end
        end
    elseif g.mode == "follow" then
        self:faceGuide(px, pz, dt)
        if playerDist <= node.follow then self:guideNext() end
    elseif g.mode == "lying" then
        g.timer = g.timer - dt
        if g.timer <= 0 then self:finishGuide() end
    end
end

-- Final: o escrivão perde a pena (revelar) ou zomba, satisfeito (preservar)
function WorldController:scribeFinale(kind)
    for id, sp in pairs(self.spirits) do
        local data = N.spirits[id] or {}
        if data.standing and sp.state ~= "hidden" then
            sp.hotspot.enabled = false
            if kind == "reveal" then
                sp.state = "resting"
                self:playSpirit(sp, "Skeletons_Death", false, "Skeletons_Death_Pose", 0.15)
            else
                sp.state = "awake"
                self:playSpirit(sp, "Skeletons_Taunt", false, "Skeletons_Idle", 0.15)
            end
            local line = data.finale and data.finale[kind]
            if line then Flow.emit("guideSay", data.name, line) end
        end
    end
end

-- Final: Benedito aparece diante do coveiro para se despedir
function WorldController:guideFinale(kind)
    local g = self.guide
    if not g then return end
    local cam = self.camera:getWorldPosition()
    local rad = math.rad(self.yaw)
    -- um pouco à direita do olhar, para não esconder o escrivão atrás dele
    local x = cam.x - math.sin(rad) * 2.8 + math.cos(rad) * 1.3
    local z = cam.z - math.cos(rad) * 2.8 - math.sin(rad) * 1.3
    g.object.position = Vector3(x, 0, z)
    g.yaw = math.deg(math.atan(cam.x - x, cam.z - z))
    g.object.rotation = Quaternion(g.yaw, UP)
    g.object.visible = true
    g.anim = nil
    g.mode, g.finaleKind, g.timer = "finale", kind, 4.8
    if kind == "reveal" then
        self:playGuide("Waving", true, 0.1)
    else
        self:playGuide("Skeletons_Idle", true, 0.1)
        g.yaw = g.yaw + 180   -- ao ir embora, anda para longe do coveiro
    end
    g.aimY = 0.9   -- sem painel na despedida: a câmera olha para o rosto dele
    self.talkTarget = g
    -- a fala dele vem depois da do escrivão, para as duas serem lidas
    g.finaleLine = N.beneditoFinale and N.beneditoFinale[kind]
    g.finaleLineDelay = 1.8
end

----------------------------------------------------------------------
-- Cinzel
----------------------------------------------------------------------
function WorldController:startChisel(h, case)
    if self.chisel and self.chisel.hotspot == h then return end
    self:stopChisel()
    local obj = Object(self.scene, h.entity)
    self.chisel = { hotspot = h, case = case, progress = 0, strike = 0, object = obj, home = obj.position }
    Flow.emit("chiselProgress", case, 0)
end

function WorldController:stopChisel()
    local c = self.chisel
    if not c then return end
    c.object.position = c.home
    self.chisel = nil
    Flow.emit("chiselProgress", c.case, nil)
end

-- held = E ou botão do mouse seguro com a lápide na mira
function WorldController:updateChisel(dt, held)
    local c = self.chisel
    if not c then return end
    if held then
        c.progress = c.progress + dt / CHISEL_TIME
        c.strike = c.strike - dt
        if c.strike <= 0 then
            -- cada batida: a pedra estremece e a câmera dá um tranco
            c.strike = CHISEL_STRIKE
            self.shake = math.max(self.shake or 0, 0.12)
        end
        local j = 0.018 * math.min(1, c.strike / CHISEL_STRIKE)
        c.object.position = Vector3(c.home.x + (math.random() - 0.5) * j, c.home.y, c.home.z + (math.random() - 0.5) * j)
    else
        c.progress = c.progress - dt * CHISEL_DECAY
        c.object.position = c.home
        if c.progress <= 0 then
            self:stopChisel()
            return
        end
    end
    if c.progress >= 1 then
        local case = c.case
        self:stopChisel()
        Flow.completeChisel(case)
        return
    end
    Flow.emit("chiselProgress", c.case, c.progress)
end

-- Noite 3: as velas acendem uma a uma, da mesa até a primeira cova
function WorldController:startTrail()
    for _, c in ipairs(self.trail) do c.visible = false end
    self.trailLit = 0
    self.trailTimer = 1.2
end

function WorldController:hideTrail()
    for _, c in ipairs(self.trail) do c.visible = false end
    self.trailTimer = nil
end

function WorldController:onCaseResolved(case)
    if self.candles[case.grave] then
        self.candles[case.grave].visible = true
    end
    self:markCases(Flow.openCases())
    self:refreshPapers()
    self:restSpirit(case.id)
    if case.id == "c5" then self:hideTrail() end
    -- Sobressalto sobrenatural: a lua pisca forte; em alguns casos o chão treme
    local fx = N.resolutionEffects and N.resolutionEffects[case.id] or {}
    self.flash = fx.flash or 0.6
    if fx.shake then self.shake = fx.shake end
end

function WorldController:onMistake()
    -- Consequência simbólica: a névoa engrossa um pouco a cada erro e a lua some por um instante
    self.extraFog = math.min(self.extraFog + 0.008, 0.04)
    self.fog.density = self.baseFogDensity + self.extraFog
    self.dim = 1.2
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
    self:clearMarkers()
    self:hideTrail()
    self:refreshPapers()
    self.extraFog = 0
    self:applyAtmosphere(ENDING_LOOK[kind] or ENDING_LOOK.preserve)
end

function WorldController:resetVisuals()
    self.extraFog = 0
    self.flash = nil
    self.dim = nil
    self.shake = nil
    for _, c in pairs(self.candles) do c.visible = false end
    self:clearMarkers()
    self:hideTrail()
    self:refreshPapers()
    self:stopChisel()
    if self.guide then self:hideGuide() end
    self.talkTarget = nil
    for _, sp in pairs(self.spirits) do
        sp.yaw = 0
        sp.object.rotation = Quaternion(0, UP)
        sp.timer, sp.thenAnim, sp.state = nil, nil, nil
        self:setSpiritState(sp, "hidden")
    end
    self.hoverLight.intensity = 0
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
        -- sussurros ao se aproximar de certos lugares (verificado 4x por segundo)
        self.whisperTimer = (self.whisperTimer or 0) - dt
        if self.whisperTimer <= 0 then
            self.whisperTimer = 0.25
            local p = self.player.position
            Flow.checkWhispers(p.x, p.z)
        end
    elseif self.focused then
        self:setFocus(nil)
    end

    local pp = self.player.position
    self:updateSpirits(dt, pp.x, pp.z, self:canInteract())
    if self.guide and (Flow.state.phase == "playing" or self.guide.mode == "finale") then
        self:updateGuide(dt, pp.x, pp.z)
    end

    -- o cinzel só avança com a lápide certa na mira e E (ou o mouse) seguro
    if self.chisel then
        local onTarget = self:canInteract() and self.focused == self.chisel.hotspot
        local held = self.forceChiselHold or (onTarget and (key(Input.KEY_E) or Input.isMousePressed(Input.MOUSE_BUTTON_LEFT)))
        self:updateChisel(dt, held)
    end

    -- Lua piscando após uma correção, ou sumindo após um erro (reage ao estado do jogo)
    local base = self.moonIntensity or 1.6
    if self.flash then
        self.flash = self.flash - dt
        if self.flash <= 0 then
            self.flash = nil
            self.moon.intensity = base
        else
            self.moon.intensity = base * (1.0 + 2.5 * self.flash)
        end
    elseif self.dim then
        self.dim = self.dim - dt
        if self.dim <= 0 then
            self.dim = nil
            self.moon.intensity = base
        else
            -- apaga rápido e volta devagar
            self.moon.intensity = base * (1.0 - 0.75 * math.min(1, self.dim / 0.6))
        end
    end

    -- Tremor da câmera (o sino, a pedra que range)
    if self.shake then
        self.shake = self.shake - dt
        if self.shake <= 0 then
            self.shake = nil
            self:applyLook()
        else
            local a = 1.6 * math.min(1, self.shake * 2)
            self.camera.rotation = Quaternion(self.yaw + (math.random() - 0.5) * a, UP)
                * Quaternion(self.pitch + (math.random() - 0.5) * a, RIGHT)
        end
    end

    -- Trilha de velas da noite 3
    if self.trailTimer and Flow.state.phase == "playing" then
        self.trailTimer = self.trailTimer - dt
        if self.trailTimer <= 0 then
            self.trailLit = self.trailLit + 1
            local c = self.trail[self.trailLit]
            if c then c.visible = true end
            if self.trailLit >= #self.trail then
                self.trailTimer = nil
            else
                self.trailTimer = TRAIL_STEP
            end
        end
    end
end

return WorldController
