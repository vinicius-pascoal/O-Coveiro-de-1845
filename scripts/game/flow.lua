-- GameState + CaseService + EvidenceService.
-- Módulo compartilhado entre as cenas World e HUD (require devolve a mesma tabela).
-- Não conhece entidades nem UI: emite eventos que os controladores escutam.

local N = require("game.narrative")

local Flow = {}

Flow.IDLE_HINT_SECONDS = 90

----------------------------------------------------------------------
-- Eventos
----------------------------------------------------------------------
Flow.listeners = {}

-- key identifica quem escuta; registrar de novo com a mesma key substitui (útil ao reiniciar o Play)
function Flow.on(event, key, fn)
    Flow.listeners[event] = Flow.listeners[event] or {}
    Flow.listeners[event][key] = fn
end

function Flow.emit(event, ...)
    local list = Flow.listeners[event]
    if not list then return end
    for _, fn in pairs(list) do
        local ok, err = pcall(fn, ...)
        if not ok then
            Log.error("Flow event '" .. event .. "' failed: " .. tostring(err))
        end
    end
end

----------------------------------------------------------------------
-- Estado
----------------------------------------------------------------------
local function freshState()
    local s = {
        phase = "menu",        -- menu | night_intro | playing | night_end | ending
        night = 1,
        caseIndex = 1,
        read = {},             -- evidenceId -> true
        resolved = {},         -- caseId -> true
        mistakes = 0,
        flags = {},
        ending = nil,
        modalOpen = false,
        idle = 0,
        idleHintSent = false,
        notes = {},            -- histórico de descobertas (strings)
        inscriptions = {},     -- graveIndex -> texto atual
    }
    for i, g in pairs(N.graves) do
        s.inscriptions[i] = g.inscription
    end
    return s
end

Flow.state = freshState()

function Flow.reset()
    Flow.state = freshState()
    Flow.emit("reset")
end

----------------------------------------------------------------------
-- Consultas
----------------------------------------------------------------------
function Flow.narrative() return N end

function Flow.currentCase()
    if Flow.state.phase ~= "playing" then return nil end
    return N.cases[Flow.state.caseIndex]
end

function Flow.caseForGrave(graveIndex)
    for _, c in ipairs(N.cases) do
        if c.grave == graveIndex then return c end
    end
    return nil
end

function Flow.isResolved(case)
    return case and Flow.state.resolved[case.id] == true
end

function Flow.graveEvidenceId(graveIndex)
    return "grave:" .. N.graves[graveIndex].number
end

function Flow.inscription(graveIndex)
    return Flow.state.inscriptions[graveIndex] or ""
end

function Flow.isRead(id)
    return Flow.state.read[id] == true
end

function Flow.evidence(id)
    return N.evidence[id]
end

function Flow.evidenceBody(id)
    local ev = N.evidence[id]
    if not ev then return "" end
    local body = ev.body
    if ev.variants then
        for _, v in ipairs(ev.variants) do
            if Flow.state.flags[v.flag] then
                if v.replace then body = v.replace end
                if v.append then body = body .. v.append end
            end
        end
    end
    return body
end

-- Lista de fontes exigidas pelo caso: a lápide + documentos
function Flow.requiredSources(case)
    local list = { Flow.graveEvidenceId(case.grave) }
    for _, id in ipairs(case.evidence) do
        list[#list + 1] = id
    end
    return list
end

function Flow.sourceTitle(id)
    if id:sub(1, 6) == "grave:" then
        return "Lápide da sepultura " .. id:sub(7)
    end
    local ev = N.evidence[id]
    return ev and ev.title or id
end

function Flow.progress(case)
    local list = Flow.requiredSources(case)
    local readCount, missing = 0, {}
    for _, id in ipairs(list) do
        if Flow.state.read[id] then
            readCount = readCount + 1
        else
            missing[#missing + 1] = id
        end
    end
    return readCount, #list, missing
end

function Flow.canConfront(case)
    local readCount, total = Flow.progress(case)
    return readCount >= total
end

----------------------------------------------------------------------
-- Ações
----------------------------------------------------------------------
function Flow.setModal(open)
    Flow.state.modalOpen = open and true or false
end

function Flow.markRead(id)
    if Flow.state.read[id] then return false end
    Flow.state.read[id] = true
    Flow.state.idle = 0
    Flow.state.idleHintSent = false
    Flow.emit("evidenceRead", id)
    return true
end

function Flow.addNote(text)
    table.insert(Flow.state.notes, text)
end

function Flow.startGame()
    Flow.state = freshState()
    Flow.state.phase = "night_intro"
    Flow.state.night = 1
    Flow.emit("reset")
    Flow.emit("nightIntro", 1)
end

function Flow.beginNight()
    local s = Flow.state
    s.phase = "playing"
    for i, c in ipairs(N.cases) do
        if c.night == s.night and not s.resolved[c.id] then
            s.caseIndex = i
            break
        end
    end
    s.idle = 0
    s.idleHintSent = false
    Flow.emit("nightStarted", s.night)
    Flow.emit("caseStarted", N.cases[s.caseIndex])
end

-- Resultado: { kind = "correct" | "wrong" | "ending" | "back", text = ..., case = ... }
function Flow.choose(hypIndex)
    local case = Flow.currentCase()
    if not case then return nil end
    local h = case.hypotheses[hypIndex]
    if not h then return nil end

    if h.back then
        return { kind = "back", case = case }
    end

    if case.decision then
        Flow.state.ending = h.ending
        Flow.state.resolved[case.id] = true
        Flow.state.phase = "ending"
        Flow.addNote(case.summary)
        Flow.emit("ending", h.ending)
        return { kind = "ending", ending = h.ending, case = case }
    end

    if h.correct then
        Flow.state.resolved[case.id] = true
        if case.newInscription then
            Flow.state.inscriptions[case.grave] = case.newInscription
        end
        Flow.addNote(case.summary)
        Flow.emit("caseResolved", case)
        return { kind = "correct", text = case.resolution, case = case }
    end

    Flow.state.mistakes = Flow.state.mistakes + 1
    Flow.emit("mistake", case, Flow.state.mistakes)
    return { kind = "wrong", text = h.feedback, case = case }
end

-- Chamado depois que o jogador lê a resolução de um caso
function Flow.advance()
    local s = Flow.state
    local nextIndex = s.caseIndex + 1
    local nextCase = N.cases[nextIndex]

    if nextCase and nextCase.night == s.night then
        s.caseIndex = nextIndex
        s.idle = 0
        s.idleHintSent = false
        Flow.emit("caseStarted", nextCase)
        return
    end

    -- Fim da noite: aplica o evento de memória e anuncia a próxima
    local ev = N.nightEvents[s.night]
    if ev then
        for _, f in ipairs(ev.flags or {}) do s.flags[f] = true end
        for g, text in pairs(ev.inscriptions or {}) do
            s.inscriptions[g] = text
            Flow.emit("inscriptionChanged", g)
        end
        if ev.note then Flow.addNote(ev.note) end
    end
    local finished = s.night
    s.night = s.night + 1
    s.phase = "night_intro"
    Flow.emit("nightEnded", finished)
    Flow.emit("nightIntro", s.night)
end

-- Tempo ocioso para o sistema de ajuda (chamado pelo HUD a cada frame)
function Flow.tick(dt)
    local s = Flow.state
    if s.phase ~= "playing" or s.modalOpen then return end
    s.idle = s.idle + dt
    if s.idle >= Flow.IDLE_HINT_SECONDS and not s.idleHintSent then
        s.idleHintSent = true
        Flow.emit("idleHint")
    end
end

-- Texto de ajuda contextual (não penaliza)
function Flow.hintText()
    local case = Flow.currentCase()
    if not case then
        return "Não há caso aberto agora."
    end
    local _, _, missing = Flow.progress(case)
    if #missing > 0 then
        local id = missing[1]
        local where
        if id:sub(1, 6) == "grave:" then
            where = "Clique na sepultura " .. N.graves[case.grave].number .. ", marcada pela luz fria, para ler a lápide."
        elseif id:sub(1, 5) == "book:" then
            where = "Abra o botão Livro (ou clique no livro sobre a mesa) para ler a entrada do registro."
        else
            where = "Abra a sepultura " .. N.graves[case.grave].number .. " e leia o documento \"" .. Flow.sourceTitle(id) .. "\"."
        end
        return "Fonte ainda não consultada: " .. Flow.sourceTitle(id) .. ".\n" .. where
    end
    return "Você já leu todas as fontes. Abra a sepultura " .. N.graves[case.grave].number .. " e use \"Confrontar registros\".\n\n" .. case.hint
end

return Flow
