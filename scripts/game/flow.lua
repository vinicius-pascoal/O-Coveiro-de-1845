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
        focus = nil,           -- id do caso que o jogador examinou por último
        announced = {},        -- caseId -> true (caso já anunciado ao abrir)
        caseSeen = {},         -- caseId -> true (pensamento de abertura já dito)
        clues = {},            -- clueId -> true (anotado no caderno)
        clueOrder = {},        -- clueIds na ordem em que foram anotados
        proven = {},           -- caseId -> true (prova aceita; falta corrigir o registro)
        read = {},             -- evidenceId -> true
        resolved = {},         -- caseId -> true
        mistakes = 0,
        flags = {},
        ending = nil,
        modalOpen = false,
        idle = 0,
        idleHintSent = false,
        notes = {},            -- histórico de descobertas (strings)
        whispersSeen = {},     -- whisperId -> true
        inscriptions = {},     -- graveIndex -> texto atual
        scars = {},            -- graveIndex -> correções erradas que ficaram riscadas na pedra
        awakened = {},         -- caseId -> true (o morto do caso já se levantou)
        chisel = {},           -- caseId -> true (correção escolhida; falta gravar na pedra com o cinzel)
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

local function requirementMet(case)
    return not case.requires or Flow.state.resolved[case.requires] == true
end

-- Casos abertos nesta noite, na ordem do roteiro (o jogador escolhe qual resolver)
function Flow.openCases()
    local s, list = Flow.state, {}
    if s.phase ~= "playing" then return list end
    for _, c in ipairs(N.cases) do
        if c.night == s.night and not s.resolved[c.id] and requirementMet(c) then
            list[#list + 1] = c
        end
    end
    return list
end

function Flow.isOpen(case)
    for _, c in ipairs(Flow.openCases()) do
        if c == case then return true end
    end
    return false
end

-- Caso desta noite que ainda espera outro ser resolvido
function Flow.isLocked(case)
    local s = Flow.state
    return case and s.phase == "playing" and case.night == s.night and not s.resolved[case.id] and not requirementMet(case)
end

-- Caso em foco: o último examinado, se ainda aberto; senão o primeiro aberto
function Flow.currentCase()
    local open = Flow.openCases()
    for _, c in ipairs(open) do
        if c.id == Flow.state.focus then return c end
    end
    return open[1]
end

-- O morto do caso (esqueleto) se levanta uma vez por campanha
function Flow.spirit(case)
    return case and N.spirits and N.spirits[case.id]
end

function Flow.isAwake(case)
    return case and Flow.state.awakened[case.id] == true
end

function Flow.awaken(case)
    if not Flow.spirit(case) or Flow.state.awakened[case.id] then return false end
    Flow.state.awakened[case.id] = true
    Flow.emit("spiritAwake", case)
    return true
end

function Flow.setFocus(case)
    if case and Flow.state.focus ~= case.id then
        Flow.state.focus = case.id
        Flow.emit("casesChanged")
    end
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

-- Lugar do cemitério onde o documento está (nil = junto da própria sepultura)
function Flow.placeOf(id)
    local ev = N.evidence[id]
    return ev and ev.place
end

-- Documentos de casos abertos esperando num lugar
function Flow.docsAt(place)
    local list = {}
    for _, c in ipairs(Flow.openCases()) do
        for _, id in ipairs(c.evidence) do
            if N.evidence[id].place == place then list[#list + 1] = id end
        end
    end
    return list
end

function Flow.scars(graveIndex)
    return Flow.state.scars[graveIndex] or {}
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

-- Só a decisão final exige ler tudo; nos outros casos a prova apresentada é o que conta
function Flow.canConfront(case)
    if not case.decision then return true end
    local readCount, total = Flow.progress(case)
    return readCount >= total
end

----------------------------------------------------------------------
-- Caderno: detalhes anotados
----------------------------------------------------------------------
local clueIndex = {}
for source, list in pairs(N.clues or {}) do
    for _, c in ipairs(list) do
        clueIndex[c.id] = { id = c.id, text = c.text, source = source }
    end
end

function Flow.clue(id) return clueIndex[id] end

function Flow.cluesFor(sourceId)
    return (N.clues and N.clues[sourceId]) or {}
end

function Flow.hasClue(id) return Flow.state.clues[id] == true end

function Flow.noteClue(id)
    if Flow.state.clues[id] or not clueIndex[id] then return false end
    Flow.state.clues[id] = true
    table.insert(Flow.state.clueOrder, id)
    Flow.state.idle = 0
    Flow.emit("clueNoted", id)
    return true
end

-- Todas as anotações possíveis do caso, na ordem das fontes
function Flow.caseClues(case)
    local list = {}
    for _, src in ipairs(Flow.requiredSources(case)) do
        for _, c in ipairs(Flow.cluesFor(src)) do list[#list + 1] = clueIndex[c.id] end
    end
    return list
end

function Flow.notedCaseClues(case)
    local list = {}
    for _, c in ipairs(Flow.caseClues(case)) do
        if Flow.state.clues[c.id] then list[#list + 1] = c end
    end
    return list
end

function Flow.isProofClue(case, id)
    for _, a in ipairs(case.proof and case.proof.accept or {}) do
        if a == id then return true end
    end
    return false
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

-- Anuncia os casos que acabaram de abrir (início da noite ou destravados)
local function announceOpenCases()
    local s, fresh = Flow.state, {}
    for _, c in ipairs(Flow.openCases()) do
        if not s.announced[c.id] then
            s.announced[c.id] = true
            fresh[#fresh + 1] = c
        end
    end
    Flow.emit("casesChanged")
    if #fresh > 0 then Flow.emit("casesOpened", fresh) end
end

function Flow.beginNight()
    local s = Flow.state
    s.phase = "playing"
    s.focus = nil
    s.idle = 0
    s.idleHintSent = false
    Flow.emit("nightStarted", s.night)
    announceOpenCases()
end

local function mistake(case)
    Flow.state.mistakes = Flow.state.mistakes + 1
    Flow.emit("mistake", case, Flow.state.mistakes)
end

-- Decisão final (caso sem prova). Resultado: { kind = "ending" | "back", ... }
function Flow.decide(case, hypIndex)
    local h = case and case.hypotheses[hypIndex]
    if not h then return nil end
    if h.back then
        return { kind = "back", case = case }
    end
    Flow.state.ending = h.ending
    Flow.state.resolved[case.id] = true
    Flow.state.phase = "ending"
    Flow.addNote(case.summary)
    Flow.emit("ending", h.ending)
    return { kind = "ending", ending = h.ending, case = case }
end

-- Confronto: hipótese + anotação apresentada como prova.
-- Resultado: { kind = "wrong" (hipótese errada) | "weak" (prova não sustenta) | "proven", text, case }
function Flow.present(case, hypIndex, clueId)
    local h = case and case.hypotheses[hypIndex]
    if not h then return nil end
    if not h.correct then
        mistake(case)
        Flow.emit("spiritReact", case, "taunt")
        return { kind = "wrong", text = h.feedback, case = case }
    end
    if not Flow.isProofClue(case, clueId) then
        mistake(case)
        Flow.emit("spiritReact", case, "hit")
        local fb = case.proof.feedback and case.proof.feedback[clueId]
        return { kind = "weak", case = case,
                 text = fb or "Essa anotação é verdadeira, mas não prova a conclusão." }
    end
    Flow.state.proven[case.id] = true
    Flow.emit("caseProven", case)
    Flow.emit("spiritReact", case, "nod")
    return { kind = "proven", case = case }
end

function Flow.isProven(case)
    return case and Flow.state.proven[case.id] == true
end

local function resolve(case)
    local s = Flow.state
    s.resolved[case.id] = true
    s.proven[case.id] = nil
    if case.newInscription then
        s.inscriptions[case.grave] = case.newInscription
    end
    Flow.addNote(case.summary)
    Flow.emit("caseResolved", case)
end

-- Correção escrita pelo jogador depois da prova.
-- Resultado: { kind = "fixWrong" | "correct", text, case }
function Flow.fix(case, optionIndex)
    if not Flow.isProven(case) then return nil end
    local fix = case.fix
    if fix and optionIndex ~= fix.correct then
        -- a tentativa errada fica riscada na pedra até o fim
        local scars = Flow.state.scars[case.grave] or {}
        scars[#scars + 1] = fix.options[optionIndex]
        Flow.state.scars[case.grave] = scars
        mistake(case)
        Flow.emit("spiritReact", case, "hit")
        local fb = fix.feedback and fix.feedback[optionIndex]
        return { kind = "fixWrong", case = case, text = fb or "Não foi isso que as provas mostraram." }
    end
    -- a correção certa ainda precisa ser gravada na pedra (segurar E diante da lápide)
    Flow.state.chisel[case.id] = true
    Flow.emit("chiselReady", case)
    return { kind = "chisel", case = case }
end

function Flow.isChiseling(case)
    return case and Flow.state.chisel[case.id] == true
end

-- Caso esperando o cinzel nesta sepultura (ou nil)
function Flow.chiselCaseForGrave(graveIndex)
    local case = Flow.caseForGrave(graveIndex)
    if Flow.isChiseling(case) and Flow.isOpen(case) then return case end
    return nil
end

-- O cinzel terminou: o registro está corrigido
function Flow.completeChisel(case)
    if not Flow.isChiseling(case) then return nil end
    Flow.state.chisel[case.id] = nil
    resolve(case)
    return { kind = "correct", text = case.resolution, case = case }
end

-- Chamado depois que o jogador lê a resolução de um caso
function Flow.advance()
    local s = Flow.state
    s.idle = 0
    s.idleHintSent = false
    if #Flow.openCases() > 0 then
        announceOpenCases()
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

-- Sussurros: o WorldController informa a posição do jogador; cada um dispara uma vez
function Flow.checkWhispers(x, z)
    local s = Flow.state
    if s.phase ~= "playing" or s.modalOpen then return end
    for _, w in ipairs(N.whispers) do
        if not s.whispersSeen[w.id] and s.night >= (w.night or 1) and (not w.flag or s.flags[w.flag]) then
            local dx, dz = x - w.x, z - w.z
            if dx * dx + dz * dz <= w.radius * w.radius then
                s.whispersSeen[w.id] = true
                Flow.emit("whisper", w)
                return
            end
        end
    end
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
    local number = N.graves[case.grave].number
    local head = "Caso em foco: sepultura " .. number .. " — " .. case.title .. ".\n"
    local others = {}
    for _, c in ipairs(Flow.openCases()) do
        if c ~= case then others[#others + 1] = N.graves[c.grave].number end
    end
    local tail = #others > 0 and ("\n\nTambém aberta esta noite: sepultura " .. table.concat(others, ", ") .. ".") or ""

    if Flow.isChiseling(case) then
        return head .. "A correção está decidida. Fique diante da lápide " .. number .. ", mire nela e segure E até o cinzel terminar." .. tail
    end
    if Flow.isProven(case) then
        return head .. "Você já provou o que aconteceu. Examine a sepultura " .. number .. " e use \"Corrigir o registro\"." .. tail
    end
    local _, _, missing = Flow.progress(case)
    if #missing > 0 then
        local id = missing[1]
        local where
        if id:sub(1, 6) == "grave:" then
            where = "Vá até a sepultura " .. number .. ", marcada pela luz fria, mire nela e aperte E para ler a lápide."
        elseif id:sub(1, 5) == "book:" then
            where = "Aperte L (ou vá até o livro sobre a mesa, ao norte) para ler a entrada do registro."
        elseif Flow.placeOf(id) then
            where = "Esse papel não está na cova. Procure o brilho de papel " .. N.places[Flow.placeOf(id)].where .. "."
        else
            where = "Examine a sepultura " .. number .. " e leia o documento \"" .. Flow.sourceTitle(id) .. "\"."
        end
        return head .. "Fonte ainda não consultada: " .. Flow.sourceTitle(id) .. ".\n" .. where .. tail
    end
    if case.decision then
        return head .. "Você já leu tudo. Examine a sepultura " .. number .. " e decida.\n\n" .. case.hint
    end
    local hasProof = false
    for _, c in ipairs(Flow.notedCaseClues(case)) do
        if Flow.isProofClue(case, c.id) then hasProof = true end
    end
    if hasProof then
        return head .. "Você já anotou o detalhe que resolve o caso. Examine a sepultura " .. number .. ", use \"Confrontar registros\" e apresente-o.\n\n" .. case.hint .. tail
    end
    return head .. "Você leu todas as fontes, mas ainda não anotou o detalhe decisivo. Releia os documentos e anote o que desempata a questão.\n\n" .. case.hint .. tail
end

return Flow
