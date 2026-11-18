-- Autoteste de desenvolvimento: percorre a campanha inteira pelas mesmas funções
-- que os botões chamam e registra o resultado no log. Ativado pela propriedade
-- "Self Test" do HUDController (desligada no jogo publicado).

local Flow = require("game.flow")
local N = require("game.narrative")

local SelfTest = {}

local function check(cond, msg)
    if not cond then error("SELFTEST FAIL: " .. msg, 2) end
end

local PANEL_SLOTS = 6

local function clickPanel(hud, labelPrefix)
    for i = 1, PANEL_SLOTS do
        local name = "PanelBtn" .. i
        local btn = hud.button[name]
        local lbl = hud.slotLabels[name] or btn.label
        if btn.visible and hud.actions[name] and lbl:sub(1, #labelPrefix) == labelPrefix then
            hud:handleButton(name)
            return true
        end
    end
    local labels = {}
    for i = 1, PANEL_SLOTS do
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

-- Anota todos os detalhes da fonte aberta no painel
local function noteAll(hud, sourceId)
    for _, c in ipairs(Flow.cluesFor(sourceId)) do
        clickPanel(hud, "Anotar: " .. c.text)
        check(Flow.hasClue(c.id), "clue should be noted: " .. c.id)
    end
end

-- O morto do caso: deitado até o coveiro chegar perto, de pé depois de levantar, conversa pela mira
local function wakeSpirit(hud, case)
    local world = Flow.worldController
    local sp = world and world.spirits[case.id]
    if not sp then return end
    check(sp.state == "dormant" and sp.object.visible, "spirit should lie dormant: " .. case.id)
    check(not sp.hotspot.enabled, "dormant spirit should not be aimable: " .. case.id)
    world:updateSpirits(0, sp.home.x + 1, sp.home.z + 1, true)
    check(Flow.isAwake(case) and sp.state == "rising", "spirit should rise when near: " .. case.id)
    world:updateSpirits(3.0, sp.home.x + 1, sp.home.z + 1, false)
    check(sp.state == "awake" and sp.hotspot.enabled, "spirit should stand and be aimable: " .. case.id)
    -- mirar no morto e apertar E abre a conversa compacta, com a câmera voltada para ele
    hud:closePanel()
    hud:onWorldClick({ kind = "spirit", caseId = case.id })
    check(hud.talking == case and hud.panelCompact and world.talkTarget == sp, "talk mode expected: " .. case.id)
    check(hud.modalDim.visible, "talk panel lives under ModalDim and must stay visible: " .. case.id)
    hud:closePanel()
    check(hud.talking == nil and world.talkTarget == nil, "closing should end the talk: " .. case.id)
end

local function playCase(hud, case, makeMistake)
    if not case.decision then wakeSpirit(hud, case) end
    hud:onWorldClick({ kind = "grave", grave = case.grave })
    check(hud.panelOpen, "grave panel should be open")
    check(Flow.currentCase() == case, "opening the grave should focus " .. case.id)
    if case.decision then
        -- decisão final bloqueada antes de ler tudo
        local found = false
        for i = 1, PANEL_SLOTS do
            local b = hud.button["PanelBtn" .. i]
            if b.visible and b.label:find("fontes lidas", 1, true) then
                found = true
                check(b.disabled, "decision should be disabled before reading")
            end
        end
        check(found, "decision button with progress expected")
    else
        -- confrontar sem anotações: o caderno vazio não deixa provar nada
        clickPanel(hud, "Confrontar")
        for _, h in ipairs(case.hypotheses) do
            if h.correct then clickPanel(hud, h.text:sub(1, 20)); break end
        end
        check(hud.text.PanelBody.text:find("ainda não tem nada", 1, true) ~= nil, "empty notebook message expected")
        clickPanel(hud, "Voltar às conclusões")
        clickPanel(hud, "Voltar à sepultura")
        noteAll(hud, Flow.graveEvidenceId(case.grave))
    end
    for _, id in ipairs(case.evidence) do
        local ev = N.evidence[id]
        if ev.place then
            -- o papel está espalhado pelo cemitério: a sepultura só diz onde procurar
            local found = false
            for i = 1, PANEL_SLOTS do
                local b = hud.button["PanelBtn" .. i]
                if b.visible and b.label:find("Procurar: " .. ev.title, 1, true) then
                    found = true
                    check(b.disabled, "search button should be disabled: " .. id)
                end
            end
            check(found, "search button expected for " .. id)
            local world = Flow.worldController
            if world then
                local active = false
                for _, h in ipairs(world.hotspots) do
                    if h.kind == "paper" and h.place == ev.place then active = h.enabled and h.object.visible end
                end
                check(active, "paper should be visible at " .. ev.place)
            end
            hud:closePanel()
            hud:onWorldClick({ kind = "paper", place = ev.place })
            check(Flow.isRead(id), "paper should be read: " .. id)
            hud:finishReveal()
            noteAll(hud, id)
            clickPanel(hud, "Guardar o papel")
            check(not hud.panelOpen, "paper panel should close")
            hud:onWorldClick({ kind = "grave", grave = case.grave })
            clickPanel(hud, "Reler: " .. ev.title)
            clickPanel(hud, "Voltar")
        else
            local prefix = ev.kind == "book" and "Consultar o livro" or ("Ler: " .. ev.title)
            clickPanel(hud, prefix)
            check(Flow.isRead(id), "evidence should be read: " .. id)
            hud:finishReveal()
            noteAll(hud, id)
            clickPanel(hud, "Voltar")
        end
    end
    check(Flow.canConfront(case), "should be able to confront " .. case.id)
    clickPanel(hud, case.decision and "Decidir" or "Confrontar")

    if case.decision then
        return
    end

    local correctText, proofText, weakText
    for _, h in ipairs(case.hypotheses) do
        if h.correct then correctText = h.text end
    end
    for _, c in ipairs(Flow.caseClues(case)) do
        if Flow.isProofClue(case, c.id) then proofText = proofText or c.text else weakText = weakText or c.text end
    end
    check(proofText and weakText, "case needs proof and decoy clues: " .. case.id)

    if makeMistake then
        -- conclusão errada
        for _, h in ipairs(case.hypotheses) do
            if not h.correct then clickPanel(hud, h.text:sub(1, 20)); break end
        end
        clickPanel(hud, weakText)
        check(hud.text.PanelTitle.text:find("não sustentam", 1, true) ~= nil, "wrong answer panel expected")
        clickPanel(hud, "Tentar outra")
        -- conclusão certa com prova fraca
        clickPanel(hud, correctText:sub(1, 20))
        clickPanel(hud, weakText)
        check(hud.text.PanelTitle.text:find("não prova", 1, true) ~= nil, "weak proof panel expected")
        clickPanel(hud, "Apresentar outra")
    else
        clickPanel(hud, correctText:sub(1, 20))
    end
    clickPanel(hud, proofText)
    check(Flow.isProven(case), "case should be proven: " .. case.id)
    check(not Flow.isResolved(case), "case should wait for the fix: " .. case.id)

    if makeMistake then
        -- sai no meio da correção e volta pela sepultura
        clickPanel(hud, "Voltar à sepultura")
        clickPanel(hud, "Corrigir o registro")
        for i, opt in ipairs(case.fix.options) do
            if i ~= case.fix.correct then clickPanel(hud, opt); break end
        end
        check(hud.text.PanelTitle.text:find("hesita", 1, true) ~= nil, "wrong fix panel expected")
        check(#Flow.scars(case.grave) == 1, "wrong fix should scar the stone: " .. case.id)
        clickPanel(hud, "Escrever de novo")
    end
    clickPanel(hud, case.fix.options[case.fix.correct])
    check(Flow.isResolved(case), "case should be resolved: " .. case.id)
    local world = Flow.worldController
    if world and world.spirits[case.id] then
        local sp = world.spirits[case.id]
        check(hud.panelCompact, "resolution should stay in talk mode: " .. case.id)
        check(sp.state == "resting" and not sp.hotspot.enabled, "spirit should rest after the fix: " .. case.id)
    end
    if case.newInscription then
        check(Flow.inscription(case.grave) == case.newInscription, "inscription should change: " .. case.id)
    end
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
        clickPanel(hud, "Caderno")
        clickPanel(hud, "Voltar ao livro")
        hud:closePanel()
        hud:openHelp()
        hud:closePanel()
        -- clicar numa sepultura fora do caso
        hud:onWorldClick({ kind = "grave", grave = 3 })
        check(hud.panelOpen, "non-case grave panel should open")
        hud:closePanel()

        local nightCases = {}
        for _, case in ipairs(N.cases) do
            if case.night == night then nightCases[#nightCases + 1] = case end
        end
        if night == 3 then
            -- a lápide lisa só abre depois da primeira cova
            check(#Flow.openCases() == 1, "only c5 should be open on night 3")
            local world = Flow.worldController
            if world then check(world.trailTimer ~= nil and #world.trail == 6, "candle trail should start on night 3") end
            hud:onWorldClick({ kind = "grave", grave = 6 })
            check(hud.text.PanelBody.text:find("primeira cova", 1, true) ~= nil, "locked grave message expected")
            hud:closePanel()
        else
            -- ordem livre: joga os casos da noite de trás para frente
            check(#Flow.openCases() == 2, "two cases should be open on night " .. night)
            local a, b = nightCases[1], nightCases[2]
            nightCases = { b, a }
        end
        for _, case in ipairs(nightCases) do
            playCase(hud, case, case.id == "c1" or case.id == "c3" or case.id == "c4")
            Log.print("SELFTEST: case " .. case.id .. " ok")
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

-- Demonstração visual (desenvolvimento): executa passos com pausas para conferir a cena em capturas.
-- Cada passo é { segundos de espera, função }; o log anuncia "DEMO step n" ao executar.
function SelfTest.demoSteps(hud)
    local world = Flow.worldController
    return {
        { 0.5, function()
            clickOverlay(hud, "Iniciar")
            hud:finishReveal(); clickOverlay(hud, "Pular")
            hud:finishReveal(); clickOverlay(hud, "Começar")
            world.character.position = Vector3(7.6, 0.05, 9.6)
            world.yaw, world.pitch = 0, -4
            world:applyLook()
        end },
        { 1.5, function() end },                                   -- 2: morto deitado à vista
        { 0.5, function() world.character.position = Vector3(7.6, 0.05, 8.4) end },
        { 1.0, function() end },                                   -- 4: levantando
        { 2.5, function() end },                                   -- 5: de pé, virado para o coveiro
        { 0.5, function()
            Flow.markRead("grave:07"); Flow.noteClue("c1_lapide"); Flow.noteClue("c1_tosse"); Flow.noteClue("c1_carta")
            hud:onWorldClick({ kind = "spirit", caseId = "c1" })
        end },                                                     -- 6: conversa compacta
        { 1.5, function() hud:pressSlot(2) end },                  -- 7: conclusão errada -> apresentar
        { 1.0, function() hud:pressSlot(1) end },                  -- 8: zombaria (Taunt)
        { 1.5, function() clickPanel(hud, "Tentar outra"); hud:pressSlot(1) end },
        { 1.0, function() clickPanel(hud, "Carta de junho") end }, -- 10: aceita (Interact) -> correção
        { 1.5, function() clickPanel(hud, "1845") end },           -- 11: registro corrigido: desaba (Death)
        { 2.5, function() end },                                   -- 12: deitado em paz
    }
end

-- Mira a câmera em cada objeto interativo e confere se a seleção pelo centro da tela o encontra
function SelfTest.aimTest(world)
    local cam = world.camera
    local p = cam:getWorldPosition()
    Log.print(string.format("SELFTEST player=%s camera=%s onGround=%s fps=%.0f", tostring(world.player.position), tostring(p), tostring(world.character:isOnGround()), Engine.framerate))
    local ok, bad = 0, {}
    local savedYaw, savedPitch = world.yaw, world.pitch
    for _, h in ipairs(world.hotspots) do
      if h.enabled then
        local c = (h.box and h.box() or h.mesh:getWorldAABB()):getCenter()
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
    end
    world.yaw, world.pitch = savedYaw, savedPitch
    world:applyLook()
    Log.print(string.format("SELFTEST aim: %d/%d ok %s", ok, #world.hotspots, table.concat(bad, " ")))
end

return SelfTest