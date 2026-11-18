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

local Saves = require("game.saves")

-- Testes e demonstrações usam espaços de save próprios: os saves do jogador ficam intactos
local function useTestSaves()
    Saves.prefix = "coveiro1845_selftest_"
    for n = 1, Saves.SLOTS do Saves.delete(n) end
    pcall(UserSettings.removeKey, Saves.prefix .. "seq")
end

local function startTestGame(hud)
    useTestSaves()
    Saves.startNew(1)
    hud:showPrologue(1)
end

local function clickOverlay(hud, labelPrefix)
    for i = 1, 7 do
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
    -- o que o morto diz fica num balão sobre ele; o painel de baixo traz só as escolhas
    check(hud.bubble and hud.bubble.key == case.id and hud.bubble.timer == nil, "the dead should speak in a bubble: " .. case.id)
    check(hud.text.PanelTitle.text == "Sua resposta", "the bottom panel should hold the player's answer: " .. case.id)
    hud:updateBubble(0)
    local ax = world:speakerAnchor(case.id)
    check(ax ~= nil, "speaker anchor expected: " .. case.id)
    check(hud.modalDim.visible, "talk panel lives under ModalDim and must stay visible: " .. case.id)
    if case.decision then
        check(hud.text.SpeechText.text:find("Ninguém assina", 1, true) ~= nil, "the scribe should refuse (in a speech bubble) before the reading")
    end
    hud:closePanel()
    check(hud.talking == nil and world.talkTarget == nil, "closing should end the talk: " .. case.id)
    check(hud.bubble == nil, "closing the talk should clear the dead's line: " .. case.id)
end

-- Benedito, o guia: o coveiro anda colado nele até a rota da noite acabar
local function followGuide(night)
    local world = Flow.worldController
    local g = world and world.guide
    if not g then return end
    check(g.object.visible and g.mode ~= "hidden", "guide should appear on night " .. night)
    local said = 0
    Flow.on("guideSay", "selftest", function() said = said + 1 end)
    for _ = 1, 3000 do
        if g.mode == "hidden" or g.mode == "done" then break end
        local p = g.object.position
        world:updateGuide(0.05, p.x + 0.6, p.z + 0.6)
    end
    Flow.listeners.guideSay.selftest = nil
    check(g.mode == "hidden", "guide route should end on night " .. night .. " (mode " .. tostring(g.mode) .. ")")
    check(said > 0, "guide should speak on night " .. night)
    if night == 3 then
        check(Flow.state.flags.benedito_rest, "Benedito should lie in the first grave")
        check(world.spirits.c5.state == "dormant", "the c5 spirit should take Benedito's place")
    end
end

local function playCase(hud, case, makeMistake)
    if case.decision and Flow.worldController then
        local sp = Flow.worldController.spirits[case.id]
        check(sp and sp.anim == "Use_Item", "the scribe should be writing by the blank stone")
    end
    wakeSpirit(hud, case)
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
    -- a correção certa não resolve sozinha: precisa ser gravada na pedra com o cinzel
    check(Flow.isChiseling(case) and not Flow.isResolved(case), "fix should wait for the chisel: " .. case.id)
    check(not hud.panelOpen and hud.talking == nil, "choosing the fix should return control: " .. case.id)
    local world = Flow.worldController
    if world then
        local h = world:graveHotspot(case.grave)
        world:startChisel(h, case)
        world:updateChisel(1.0, true)
        check(world.chisel and world.chisel.progress > 0.3 and hud.chiselBar.visible, "chisel should progress: " .. case.id)
        local before = world.chisel.progress
        world:updateChisel(0.2, false)
        check(world.chisel and world.chisel.progress < before, "releasing E should lose progress: " .. case.id)
        world:updateChisel(3.0, true)
        check(world.chisel == nil and not hud.chiselBar.visible, "chisel should finish: " .. case.id)
    else
        Flow.completeChisel(case)
    end
    check(Flow.isResolved(case), "case should be resolved: " .. case.id)
    check(not hud.panelOpen, "resolution is told in the subtitle, not a panel: " .. case.id)
    if world and world.spirits[case.id] then
        local sp = world.spirits[case.id]
        check(sp.state == "resting" and not sp.hotspot.enabled, "spirit should rest after the fix: " .. case.id)
    end
    if case.newInscription then
        check(Flow.inscription(case.grave) == case.newInscription, "inscription should change: " .. case.id)
    end
    -- último registro da noite: a noite só termina depois do tempo de leitura
    if #Flow.openCases() == 0 then
        check(hud.advanceTimer ~= nil and Flow.state.phase == "playing", "night should wait for the reading time")
        hud:flushAdvance()
    end
end

function SelfTest.run(hud, endingKind)
    Log.print("SELFTEST: start (" .. endingKind .. ")")
    useTestSaves()
    hud:showMainMenu()
    check(hud.overlayOpen and hud.overlayMode == "menu", "main menu expected")
    check(hud.slotLabels.OverlayBtn4 == "Jogar", "without saves the menu starts with 'Jogar'")
    clickOverlay(hud, "Controles")
    check(not hud.overlayLogo.visible, "the KayKit logo belongs only to the credits")
    clickOverlay(hud, "Voltar")
    clickOverlay(hud, "Créditos")
    check(hud.overlayLogo.visible, "menu credits should show the KayKit logo")
    clickOverlay(hud, "Voltar")
    check(not hud.overlayLogo.visible, "the logo should hide when leaving the credits")
    -- opções: alterna tudo e volta ao estado original
    clickOverlay(hud, "Opções")
    check(hud.overlayMode == "options", "options expected")
    local Settings = require("game.settings")
    local sens0 = Settings.sensitivityIndex
    for _ = 1, #Settings.sensitivityLevels do clickOverlay(hud, "Sensibilidade") end
    check(Settings.sensitivityIndex == sens0, "sensitivity should cycle back")
    -- volume: os dois botões aparecem e voltam ao valor inicial depois de uma volta completa
    check(#hud.keySlots.OverlayBtn == 7, "options should show 7 buttons")
    for _, kind in ipairs({ "master", "ambient" }) do
        local vol0 = Settings.volumeIndex[kind]
        local label = kind == "master" and "Volume geral" or "Volume do ambiente"
        for _ = 1, #Settings.volumeLevels do clickOverlay(hud, label) end
        check(Settings.volumeIndex[kind] == vol0, kind .. " volume should cycle back")
    end
    clickOverlay(hud, "Inverter"); clickOverlay(hud, "Inverter")
    clickOverlay(hud, "Texto grande"); check(Settings.largeText, "large text on")
    clickOverlay(hud, "Texto grande"); check(not Settings.largeText, "large text off")
    hud:onKeyDown(Input.KEY_ESCAPE, false, 0)
    check(hud.overlayMode == "menu", "esc should return to menu")
    -- atalho numérico: 1 = Jogar -> saves; 1 = espaço 1 (vazio) -> prólogo
    hud:onKeyDown(Input.KEY_1, false, 0)
    check(hud.overlayMode == "slots", "key 1 should open the save slots")
    check((hud.slotLabels.OverlayBtn4 or ""):find("vazio", 1, true) ~= nil, "slots should start empty")
    hud:onKeyDown(Input.KEY_1, false, 0)
    check(hud.overlayMode == "prologue" and Saves.current == 1, "an empty slot should start a new game")
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
        if night == 2 then
            -- save: o fim da noite 1 ficou gravado; sai para o menu e continua pelo save
            local info = Saves.info(1)
            check(info and info.night == 2 and info.resolved == 2, "slot 1 should hold night 2 with 2 records")
            local clues, notes, mistakes = #Flow.state.clueOrder, #Flow.state.notes, Flow.state.mistakes
            Flow.reset()
            hud:showMainMenu()
            check((hud.slotLabels.OverlayBtn3 or ""):find("Continuar", 1, true) == 1, "menu should offer 'Continuar'")
            clickOverlay(hud, "Continuar")
            check(hud.overlayMode == "night" and Flow.state.night == 2 and Saves.current == 1, "loading should reopen night 2")
            check(Flow.state.resolved.c1 and Flow.state.resolved.c2, "loaded save should keep the resolved cases")
            check(#Flow.state.clueOrder == clues and #Flow.state.notes == notes and Flow.state.mistakes == mistakes,
                "loaded save should keep clues, notes and mistakes")
            check(Flow.inscription(N.cases[1].grave) == N.cases[1].newInscription, "loaded save should keep the new inscription")
        end
        clickOverlay(hud, "Começar")
        check(Flow.state.phase == "playing", "phase playing expected")
        if night == 2 and Flow.worldController then
            local w = Flow.worldController
            check(w.candles[N.cases[1].grave].visible and w.candles[N.cases[2].grave].visible, "candles of loaded records should be lit")
        end
        if night == 3 and Flow.worldController then
            check(Flow.worldController.spirits.c5.state == "hidden", "Benedito's spirit waits for the guide")
        end
        followGuide(night)
        if night == 1 then
            hud:openPause()
            check(hud.overlayMode == "pause", "pause expected")
            clickOverlay(hud, "Salvar jogo")
            check(hud.overlayMode == "pause" and hud.slotLabels.OverlayBtn4 == "Jogo salvo", "manual save should confirm")
            check(Saves.info(1) and Saves.info(1).night == 1, "manual save should write slot 1")
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
        -- E fecha o painel (mas não no mesmo quadro em que ele abriu)
        hud:openBook()
        hud:onKeyDown(Input.KEY_E, false, 0)
        check(hud.panelOpen, "the E that opened a panel must not close it")
        hud.frame = hud.frame + 1
        hud:onKeyDown(Input.KEY_E, false, 0)
        check(not hud.panelOpen, "E should close the panel")
        -- Tab: caderno lateral sem pausar
        hud:onKeyDown(Input.KEY_TAB, false, 0)
        hud:updateNotebook()
        check(hud.notebookOpen and hud.notebookBg.visible and not Flow.state.modalOpen, "Tab should show the notebook without pausing")
        check(hud.text.NotebookText.text:find("Sepultura", 1, true) ~= nil, "notebook should list the open graves")
        hud:onKeyDown(Input.KEY_TAB, false, 0)
        hud:updateNotebook()
        check(not hud.notebookBg.visible, "Tab again should hide the notebook")
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
    -- despedida de Benedito antes do epílogo
    check(not hud.overlayOpen and hud.pendingEnding == endingKind, "finale should come before the epilogue")
    if Flow.worldController and Flow.worldController.guide then
        local g = Flow.worldController.guide
        check(g.mode == "finale" and g.object.visible, "Benedito should say goodbye")
        check(g.anim == (endingKind == "reveal" and "Waving" or "Skeletons_Idle"), "finale animation for " .. endingKind)
        local scribe = Flow.worldController.spirits.c6
        check(scribe.anim == (endingKind == "reveal" and "Skeletons_Death" or "Skeletons_Taunt"), "scribe reaction for " .. endingKind)
    end
    hud:flushEnding()
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
    check(hud.overlayLogo.visible, "end credits should show the KayKit logo")
    -- sons: a paisagem sonora existe e nenhum arquivo de assets/sons falhou ao carregar
    local audio = Flow.worldController and Flow.worldController.audio
    check(audio ~= nil, "soundscape should be running")
    local soundCount, failedNames = 0, {}
    for file, snd in pairs(audio.sounds) do
        soundCount = soundCount + 1
        local okC, comp = pcall(function() return snd:getSoundComponent() end)
        if okC and comp and comp.loadFailed then failedNames[#failedNames + 1] = file end
    end
    check(#failedNames == 0, "sounds failed to load: " .. table.concat(failedNames, ", "))
    check(audio.windA and audio.windA:getPlayingTime() > 0, "the wind should be playing")
    Log.print("SELFTEST: sounds used = " .. soundCount)
    Log.print("SELFTEST: mistakes = " .. Flow.state.mistakes .. ", notes = " .. #Flow.state.notes)
    -- save concluído: não aparece em "Continuar"; o espaço mostra o final e pode ser apagado
    check(Saves.info(1) and Saves.info(1).ending == endingKind, "slot 1 should record the ending")
    clickOverlay(hud, "Jogar novamente")
    check(hud.overlayMode == "menu" and Flow.state.phase == "menu", "back to menu expected")
    check(hud.slotLabels.OverlayBtn4 == "Jogar", "a finished campaign is not offered as 'Continuar'")
    clickOverlay(hud, "Jogar")
    check((hud.slotLabels.OverlayBtn3 or ""):find("concluído", 1, true) ~= nil, "slot 1 should show as finished")
    clickOverlay(hud, "Apagar um save")
    clickOverlay(hud, "Apagar: Espaço 1")
    check(hud.overlayMode == "confirm", "deleting asks first")
    clickOverlay(hud, "Sim, apagar")
    check(Saves.info(1) == nil and hud.overlayMode == "slots", "slot 1 should be empty after deleting")
    clickOverlay(hud, "Voltar")
    check(hud.overlayMode == "menu", "back to menu expected after the slots")
    Log.print("SELFTEST: PASS (" .. endingKind .. ")")
end

-- Demonstração visual (desenvolvimento): executa passos com pausas para conferir a cena em capturas.
-- Cada passo é { segundos de espera, função }; o log anuncia "DEMO step n" ao executar.
function SelfTest.demoSteps(hud)
    local world = Flow.worldController
    return {
        { 0.5, function()
            startTestGame(hud)
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
            Flow.markRead("grave:07"); Flow.noteClue("c1_lapide"); Flow.noteClue("c1_rosa"); Flow.noteClue("c1_assento")
            hud:onWorldClick({ kind = "spirit", caseId = "c1" })
        end },                                                     -- 6: conversa compacta
        { 1.5, function() hud:pressSlot(1) end },                  -- 7: conclusão errada -> apresentar
        { 1.0, function() hud:pressSlot(1) end },                  -- 8: zombaria (Taunt)
        { 1.5, function() clickPanel(hud, "Tentar outra"); hud:pressSlot(2) end },
        { 1.0, function() clickPanel(hud, "Assento do vigário") end }, -- 10: aceita (Interact) -> correção
        { 1.5, function() clickPanel(hud, "1845") end },           -- 11: correção decidida, controle de volta
        { 1.0, function()                                          -- 12: mira na lápide e segura o cinzel
            local h = world:graveHotspot(7)
            local c = h.mesh:getWorldAABB():getCenter()
            local p = world.camera:getWorldPosition()
            world.yaw = math.deg(math.atan(-(c.x - p.x), -(c.z - p.z)))
            world.pitch = math.deg(math.atan(c.y - p.y, math.sqrt((c.x - p.x) ^ 2 + (c.z - p.z) ^ 2)))
            world:applyLook()
            world.forceChiselHold = true
            world:startChisel(h, Flow.chiselCaseForGrave(7))
        end },
        { 1.2, function() end },                                   -- 13: barra do cinzel pela metade
        { 2.0, function() world.forceChiselHold = false end },     -- 14: gravado: morto desaba, legenda conta
        { 1.0, function() hud:setNotebookOpen(true) end },         -- 15: caderno com Tab, sem pausa
        { 1.5, function() hud:setNotebookOpen(false) end },        -- 16: fim
    }
end

-- Vistas do cenário (atmosfera): olha para o centro e para as bordas do mapa
function SelfTest.demoViewSteps(hud)
    local world = Flow.worldController
    local function place(x, z, yaw, pitch)
        world.character.position = Vector3(x, 0.05, z)
        world.yaw, world.pitch = yaw, pitch or -4
        world:applyLook()
    end
    local night = SelfTest.viewNight or 1
    return {
        { 0.5, function()
            startTestGame(hud)
            hud:finishReveal(); clickOverlay(hud, "Pular")
            Flow.state.night = night
            hud:finishReveal(); clickOverlay(hud, "Começar")
            place(0, 13, 0)
        end },
        { 2.0, function() end },                         -- 2: do portão para dentro
        { 0.3, function() place(0, 13, 180) end },
        { 1.2, function() end },                         -- 4: para fora do portão
        { 0.3, function() place(-9, -10, 90) end },
        { 1.2, function() end },                         -- 6: borda oeste
        { 0.3, function() place(9, 0, -90) end },
        { 1.2, function() end },                         -- 8: borda leste
        { 0.3, function() place(2, -14, 0) end },
        { 1.2, function() end },                         -- 10: fundo (norte)
        { 0.3, function() place(0, 0, 30, 2) end },
        { 1.2, function() end },                         -- 12: centro, olhando o horizonte
    }
end

-- Demonstração do guia: pula para a noite 3, acompanha Benedito pela trilha e mostra a despedida
function SelfTest.demoGuideSteps(hud)
    local world = Flow.worldController
    local function place(x, z, yaw, pitch)
        world.character.position = Vector3(x, 0.05, z)
        world.yaw, world.pitch = yaw, pitch or -6
        world:applyLook()
    end
    return {
        { 0.5, function()
            startTestGame(hud)
            hud:finishReveal(); clickOverlay(hud, "Pular")
            local s = Flow.state
            s.night = 3
            for _, id in ipairs({ "c1", "c2", "c3", "c4" }) do s.resolved[id] = true end
            s.flags.night1_event, s.flags.night2_event = true, true
            hud:finishReveal(); clickOverlay(hud, "Começar")
            place(4.6, -11.0, 0)
        end },
        { 1.5, function() end },                                -- 2: o vulto espera na mesa
        { 2.0, function() place(4.0, -10.5, 20) end },          -- 3: fala e começa a andar
        { 3.0, function() end },                                -- 4: andando pela trilha de velas
        { 2.5, function() place(-4.5, -6.0, 60, -10) end },     -- 5: o coveiro segue até perto da cova 01
        { 6.0, function() end },                                -- 6: Benedito se deita na cova
        { 2.0, function() end },                                -- 7: o morto do caso 5 no lugar dele
        { 1.0, function()
            Flow.state.phase = "ending"
            place(-4.5, -6.0, 60, -6)
            Flow.emit("finale", "reveal")
        end },
        { 1.2, function() end },                                -- 9: aceno de despedida
        { 3.0, function() end },                                -- 10: se desfaz
    }
end

-- Demonstração do final: pula para a lápide lisa, encara o escrivão e escolhe revelar
function SelfTest.demoFinaleSteps(hud)
    local world = Flow.worldController
    return {
        { 0.5, function()
            startTestGame(hud)
            hud:finishReveal(); clickOverlay(hud, "Pular")
            local s = Flow.state
            s.night = 3
            for _, id in ipairs({ "c1", "c2", "c3", "c4", "c5" }) do s.resolved[id] = true end
            s.flags.night1_event, s.flags.night2_event, s.flags.benedito_rest = true, true, true
            for _, id in ipairs({ "grave:06", "book:06", "oficio_camara" }) do s.read[id] = true end
            hud:finishReveal(); clickOverlay(hud, "Começar")
            world.character.position = Vector3(-2.9, 0.05, 10.5)
            world.yaw, world.pitch = 0, -6
            world:applyLook()
        end },
        { 1.5, function() end },                                                    -- 2: escrivão escrevendo
        { 0.5, function() world.character.position = Vector3(-2.9, 0.05, 8.6) end },
        { 2.5, function() end },                                                    -- 4: virou-se para o coveiro
        { 0.5, function() hud:onWorldClick({ kind = "spirit", caseId = "c6" }) end }, -- 5: a decisão diante dele
        { 2.0, function() hud:pressSlot(2) end },                                   -- 6: revelar
        { 1.4, function() end },                                                    -- 7: Benedito acena, escrivão cai
        { 3.0, function() end },                                                    -- 8: epílogo
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