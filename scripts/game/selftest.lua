-- Autoteste de desenvolvimento: percorre a campanha inteira pelas mesmas funções
-- que os botões chamam e registra o resultado no log. Ativado pela propriedade
-- "Self Test" do HUDController (desligada no jogo publicado).

local Flow = require("game.flow")
local N = require("game.narrative")

local SelfTest = {}

local function check(cond, msg)
    if not cond then error("SELFTEST FAIL: " .. msg, 2) end
end

local function clickPanel(hud, labelPrefix)
    for i = 1, 4 do
        local name = "PanelBtn" .. i
        local btn = hud.button[name]
        local lbl = hud.slotLabels[name] or btn.label
        if btn.visible and hud.actions[name] and lbl:sub(1, #labelPrefix) == labelPrefix then
            hud:handleButton(name)
            return true
        end
    end
    local labels = {}
    for i = 1, 4 do
        local b = hud.button["PanelBtn" .. i]
        labels[#labels + 1] = (b.visible and b.label or "-") .. (hud.actions["PanelBtn" .. i] and "" or "[x]")
    end
    error("SELFTEST FAIL: panel button not found: '" .. labelPrefix .. "' in {" .. table.concat(labels, " | ") .. "}", 2)
end

local function clickOverlay(hud, labelPrefix)
    for i = 1, 5 do
        local name = "OverlayBtn" .. i
        local btn = hud.button[name]
        local lbl = hud.slotLabels[name] or btn.label
        if btn.visible and hud.actions[name] and lbl:sub(1, #labelPrefix) == labelPrefix then
            hud:handleButton(name)
            return true
        end
    end
    error("SELFTEST FAIL: overlay button not found: " .. labelPrefix, 2)
end

local function playCase(hud, case, makeMistake)
    hud:onWorldClick({ kind = "grave", grave = case.grave })
    check(hud.panelOpen, "grave panel should be open")
    -- confronto bloqueado antes de ler tudo
    for i = 1, 4 do
        local b = hud.button["PanelBtn" .. i]
        if b.visible and b.label:find("fontes lidas", 1, true) then
            check(b.disabled, "confront should be disabled before reading")
        end
    end
    for _, id in ipairs(case.evidence) do
        local ev = N.evidence[id]
        local prefix = ev.kind == "book" and "Consultar o livro" or ("Ler: " .. ev.title)
        clickPanel(hud, prefix)
        check(Flow.isRead(id), "evidence should be read: " .. id)
        clickPanel(hud, "Voltar")
    end
    check(Flow.canConfront(case), "should be able to confront " .. case.id)
    clickPanel(hud, case.decision and "Decidir" or "Confrontar")

    if case.decision then
        return
    end

    if makeMistake then
        for _, h in ipairs(case.hypotheses) do
            if not h.correct then
                clickPanel(hud, h.text:sub(1, 20))
                break
            end
        end
        check(hud.text.PanelTitle.text:find("não sustentam", 1, true) ~= nil, "wrong answer panel expected")
        clickPanel(hud, "Tentar outra")
    end
    for _, h in ipairs(case.hypotheses) do
        if h.correct then
            clickPanel(hud, h.text:sub(1, 20))
            break
        end
    end
    check(Flow.isResolved(case), "case should be resolved: " .. case.id)
    clickPanel(hud, "Continuar")
end

function SelfTest.run(hud, endingKind)
    Log.print("SELFTEST: start (" .. endingKind .. ")")
    check(hud.overlayOpen and hud.overlayMode == "menu", "main menu expected")
    clickOverlay(hud, "Controles")
    clickOverlay(hud, "Voltar")
    -- opções: alterna tudo e volta ao estado original
    clickOverlay(hud, "Opções")
    check(hud.overlayMode == "options", "options expected")
    local Settings = require("game.settings")
    local sens0 = Settings.sensitivityIndex
    for _ = 1, #Settings.sensitivityLevels do clickOverlay(hud, "Sensibilidade") end
    check(Settings.sensitivityIndex == sens0, "sensitivity should cycle back")
    clickOverlay(hud, "Inverter"); clickOverlay(hud, "Inverter")
    clickOverlay(hud, "Texto grande"); check(Settings.largeText, "large text on")
    clickOverlay(hud, "Texto grande"); check(not Settings.largeText, "large text off")
    hud:onKeyDown(Input.KEY_ESCAPE, false, 0)
    check(hud.overlayMode == "menu", "esc should return to menu")
    -- atalho numérico: 1 = Iniciar
    hud:onKeyDown(Input.KEY_1, false, 0)
    check(hud.overlayMode == "prologue", "key 1 should open the prologue")
    -- texto animado: começa vazio e Espaço completa
    if require("game.settings").animateText then
        check(hud.reveal ~= nil, "prologue text should be revealing")
        hud:onKeyDown(Input.KEY_SPACE, false, 0)
        check(hud.reveal == nil and hud.text.OverlayBody.text == N.prologue[1].body, "space should finish the text")
    end
    clickOverlay(hud, "Continuar")
    clickOverlay(hud, "Continuar")
    clickOverlay(hud, "Entrar no cemitério")
    check(hud.overlayMode == "night", "prologue should lead to night 1")
    -- pausa e confirmação (antes de começar a noite não há pausa; testa depois)

    for night = 1, 3 do
        check(hud.overlayMode == "night", "night intro expected for night " .. night)
        clickOverlay(hud, "Começar")
        check(Flow.state.phase == "playing", "phase playing expected")
        if night == 1 then
            hud:openPause()
            check(hud.overlayMode == "pause", "pause expected")
            clickOverlay(hud, "Voltar ao menu")
            check(hud.overlayMode == "confirm", "confirm expected")
            clickOverlay(hud, "Não, voltar")
            check(hud.overlayMode == "pause", "back to pause expected")
            hud:onKeyDown(Input.KEY_ESCAPE, false, 0)
            check(not hud.overlayOpen and Flow.state.phase == "playing", "esc should resume")
        end
        hud:openBook()
        check(hud.panelOpen, "book should open")
        clickPanel(hud, "Anotações")
        clickPanel(hud, "Voltar ao livro")
        hud:closePanel()
        hud:openHelp()
        hud:closePanel()
        -- clicar numa sepultura fora do caso
        hud:onWorldClick({ kind = "grave", grave = 3 })
        check(hud.panelOpen, "non-case grave panel should open")
        hud:closePanel()

        for _, case in ipairs(N.cases) do
            if case.night == night then
                playCase(hud, case, case.id == "c1" or case.id == "c3" or case.id == "c4")
                Log.print("SELFTEST: case " .. case.id .. " ok")
            end
        end
    end

    -- decisão final
    local c6 = N.cases[#N.cases]
    for _, h in ipairs(c6.hypotheses) do
        if h.ending == endingKind then
            clickPanel(hud, h.text:sub(1, 20))
        end
    end
    check(Flow.state.phase == "ending", "ending phase expected")
    -- sussurros: dispara um pelo portão e confere que vai para a fila
    Flow.state.phase = "playing"; Flow.state.modalOpen = false
    Flow.state.whispersSeen = {}
    Flow.checkWhispers(0, 15)
    check(Flow.state.whispersSeen.gate == true, "gate whisper should fire")
    Flow.state.phase = "ending"; Flow.state.modalOpen = true
    check(hud.overlayMode == "ending", "ending overlay expected")
    clickOverlay(hud, "Continuar")
    clickOverlay(hud, "Créditos")
    check(hud.overlayMode == "credits", "credits expected")
    Log.print("SELFTEST: mistakes = " .. Flow.state.mistakes .. ", notes = " .. #Flow.state.notes)
    clickOverlay(hud, "Jogar novamente")
    check(hud.overlayMode == "menu" and Flow.state.phase == "menu", "back to menu expected")
    Log.print("SELFTEST: PASS (" .. endingKind .. ")")
end

-- Mira a câmera em cada objeto interativo e confere se a seleção pelo centro da tela o encontra
function SelfTest.aimTest(world)
    local cam = world.camera
    local p = cam:getWorldPosition()
    Log.print(string.format("SELFTEST player=%s camera=%s onGround=%s fps=%.0f", tostring(world.player.position), tostring(p), tostring(world.character:isOnGround()), Engine.framerate))
    local ok, bad = 0, {}
    local savedYaw, savedPitch = world.yaw, world.pitch
    for _, h in ipairs(world.hotspots) do
        local c = h.mesh:getWorldAABB():getCenter()
        local dx, dy, dz = c.x - p.x, c.y - p.y, c.z - p.z
        world.yaw = math.deg(math.atan(-dx, -dz))
        world.pitch = math.deg(math.atan(dy, math.sqrt(dx * dx + dz * dz)))
        world:applyLook()
        cam:updateTransform()
        cam:updateCamera()
        local hit, dist = world:pickCenter()
        if hit == h or (hit and hit.kind == h.kind and h.kind == "book") then
            ok = ok + 1
        else
            bad[#bad + 1] = string.format("%s->%s", h.name, hit and hit.name or "nil")
        end
    end
    world.yaw, world.pitch = savedYaw, savedPitch
    world:applyLook()
    Log.print(string.format("SELFTEST aim: %d/%d ok %s", ok, #world.hotspots, table.concat(bad, " ")))
end

return SelfTest