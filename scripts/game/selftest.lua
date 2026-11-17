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
        if btn.visible and hud.actions[name] and btn.label:sub(1, #labelPrefix) == labelPrefix then
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
    for i = 1, 3 do
        local name = "OverlayBtn" .. i
        local btn = hud.button[name]
        if btn.visible and hud.actions[name] and btn.label:sub(1, #labelPrefix) == labelPrefix then
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
    clickOverlay(hud, "Iniciar")

    for night = 1, 3 do
        check(hud.overlayMode == "night", "night intro expected for night " .. night)
        clickOverlay(hud, "Começar")
        check(Flow.state.phase == "playing", "phase playing expected")
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
    check(hud.overlayMode == "ending", "ending overlay expected")
    clickOverlay(hud, "Continuar")
    clickOverlay(hud, "Créditos")
    check(hud.overlayMode == "credits", "credits expected")
    Log.print("SELFTEST: mistakes = " .. Flow.state.mistakes .. ", notes = " .. #Flow.state.notes)
    clickOverlay(hud, "Jogar novamente")
    check(hud.overlayMode == "menu" and Flow.state.phase == "menu", "back to menu expected")
    Log.print("SELFTEST: PASS (" .. endingKind .. ")")
end

-- Varre a tela e registra o que a seleção 3D encontra
function SelfTest.pickSweep(world)
    local w, h = Engine.canvasWidth, Engine.canvasHeight
    for _, p in ipairs({ { w / 2, h / 2 }, { 0, 0 }, { w, 0 }, { 0, h }, { w, h } }) do
        local r = world.camera:screenToRay(p[1], p[2])
        Log.print(string.format("SELFTEST ray (%.0f,%.0f): origin=%s dir=%s", p[1], p[2], tostring(r.origin), tostring(r.direction)))
    end
    Log.print("SELFTEST camera pos=" .. tostring(world.camera.position) .. " target=" .. tostring(world.camera.target) .. " worldTarget=" .. tostring(world.camera:getWorldTarget()))
    local acc = {}
    for gy = 1, 71 do
        for gx = 1, 127 do
            local x, y = gx * w / 128, gy * h / 72
            local hit = world:pick(x, y)
            if hit then
                local a = acc[hit.name] or { sx = 0, sy = 0, n = 0 }
                a.sx, a.sy, a.n = a.sx + x, a.sy + y, a.n + 1
                acc[hit.name] = a
            end
        end
    end
    local names = {}
    for name, a in pairs(acc) do
        local hs
        for _, hh in ipairs(world.hotspots) do if hh.name == name then hs = hh end end
        local c = hs and hs.mesh:getWorldAABB():getCenter()
        names[#names + 1] = string.format("%s@(%.0f,%.0f) world(%.1f,%.1f,%.1f)", name, a.sx / a.n, a.sy / a.n, c and c.x or 0, c and c.y or 0, c and c.z or 0)
    end
    table.sort(names)
    Log.print("SELFTEST pick sweep (" .. w .. "x" .. h .. "): " .. table.concat(names, "  "))
end

return SelfTest
