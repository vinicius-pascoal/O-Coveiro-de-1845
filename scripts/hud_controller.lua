-- UIController da cena HUD: painel modal reutilizável, sobreposição de tela cheia
-- (menu, noites, finais), barra superior, dica flutuante e avisos.

local Flow = require("game.flow")
local N = require("game.narrative")
local Settings = require("game.settings")

local HUDController = {
    properties = {
        { name = "selfTest", displayName = "Self Test", type = "bool", default = false },
    }
}

local TEXTS = {
    "NightText", "ObjectiveText", "HoverLabel", "Crosshair", "ToastText",
    "PanelTitle", "PanelSubtitle", "PanelBody",
    "OverlayTitle", "OverlaySubtitle", "OverlayBody", "OverlayFooter",
}
local BUTTONS = {
    "BtnBook", "BtnHelp", "BtnPause", "PanelClose",
    "PanelBtn1", "PanelBtn2", "PanelBtn3", "PanelBtn4",
    "OverlayBtn1", "OverlayBtn2", "OverlayBtn3", "OverlayBtn4",
}
local TOP_BAR = { "NightText", "ObjectiveText" }
-- Botões do topo só aparecem com o cursor livre (painel aberto); na exploração o
-- mouse fica preso e os atalhos L / H / Esc fazem o mesmo papel.
local TOP_BUTTONS = { "BtnBook", "BtnHelp", "BtnPause" }
local KEY_HINTS = "E ou clique: examinar   ·   L: livro   ·   H: ajuda   ·   Esc: menu"

local PANEL_SLOTS = 4
local OVERLAY_SLOTS = 4
local TOAST_SECONDS = 5.5

-- Tamanhos de texto: normal / grande (opção do jogador)
local FONT = {
    body       = { 20, 24 },
    bodySmall  = { 17, 21 },
    overlay    = { 21, 25 },
    objective  = { 18, 21 },
    button     = { 18, 21 },
    toast      = { 19, 22 },
}
local function fontSize(kind)
    return FONT[kind][Settings.largeText and 2 or 1]
end

-- Transparência do fundo de tela cheia: menus deixam ver o cemitério, histórias cobrem a tela
local OVERLAY_ALPHA = { menu = 0.72, options = 0.80, info = 0.86, pause = 0.78, confirm = 0.82 }
local OVERLAY_ALPHA_DEFAULT = 0.95

local FOOTER_DEFAULT = "1–4 ou clique para escolher   ·   Enter: primeira opção"
local FOOTER_BACK = "1–4 ou clique para escolher   ·   Esc: voltar"

local DIGIT_KEYS -- preenchido no init (Input só existe em tempo de execução)

local KIND_LABEL = {
    book = "Livro de registros",
    letter = "Carta",
    testimony = "Testemunho",
    record = "Documento",
}

local function findEntity(scene, name)
    local e = scene:findEntity(name)
    if e == nil or e == 0 then
        Log.error("HUDController: entity not found: " .. name)
        return nil
    end
    return e
end

----------------------------------------------------------------------
-- Inicialização
----------------------------------------------------------------------
function HUDController:init()
    local s = self.scene
    self.text = {}
    for _, name in ipairs(TEXTS) do
        self.text[name] = Text(s, findEntity(s, name))
    end
    self.modalDim = Image(s, findEntity(s, "ModalDim"))
    self.toastBg = Image(s, findEntity(s, "ToastBg"))
    self.overlayBg = Image(s, findEntity(s, "OverlayBg"))

    self.button = {}
    self.actions = {}
    for _, name in ipairs(BUTTONS) do
        local btn = Button(s, findEntity(s, name))
        self.button[name] = btn
        local method = "onClick_" .. name
        self[method] = function(me) me:handleButton(name) end
        RegisterEvent(self, btn:getUIComponent().onClick, method)
    end

    self.actions.BtnBook = function() self:openBook() end
    self.actions.BtnHelp = function() self:openHelp() end
    self.actions.BtnPause = function() self:openPause() end
    self.actions.PanelClose = function() self:closePanel() end

    self.toastTime = 0
    self.panelOpen = false
    self.overlayOpen = false
    self.overlayMode = nil
    self.overlayBack = nil
    self.slotLabels = {}
    self.keySlots = { PanelBtn = {}, OverlayBtn = {} }

    DIGIT_KEYS = {
        [Input.KEY_1] = 1, [Input.KEY_2] = 2, [Input.KEY_3] = 3, [Input.KEY_4] = 4,
        [Input.KEY_KP_1] = 1, [Input.KEY_KP_2] = 2, [Input.KEY_KP_3] = 3, [Input.KEY_KP_4] = 4,
    }

    self:applyTextSize()

    RegisterEngineEvent(self, "onUpdate")
    RegisterEngineEvent(self, "onKeyDown")

    Flow.on("nightIntro", "hud", function(n) self:showNightIntro(n) end)
    Flow.on("caseStarted", "hud", function(case) self:onCaseStarted(case) end)
    Flow.on("evidenceRead", "hud", function() self:refreshObjective() end)
    Flow.on("idleHint", "hud", function() self:onIdleHint() end)
    Flow.on("worldClick", "hud", function(h) self:onWorldClick(h) end)
    Flow.on("focus", "hud", function(h) self:onFocus(h) end)

    self:hideToast()
    self:closePanel()
    self:showMainMenu()
end

----------------------------------------------------------------------
-- Infraestrutura de botões / painéis
----------------------------------------------------------------------
function HUDController:handleButton(name)
    local action = self.actions[name]
    if action then action() end
end

local function setVisible(obj, visible)
    if obj then obj.visible = visible end
end

function HUDController:setTopBarVisible(visible)
    for _, name in ipairs(TOP_BAR) do
        setVisible(self.text[name], visible)
    end
    self:refreshExploreUI()
end

-- Mira, aviso de interação e botões do topo conforme o estado
function HUDController:refreshExploreUI()
    local playing = Flow.state.phase == "playing" and not self.overlayOpen
    local exploring = playing and not self.panelOpen
    setVisible(self.text.Crosshair, exploring)
    if not exploring then setVisible(self.text.HoverLabel, false) end
    for _, name in ipairs(TOP_BUTTONS) do
        setVisible(self.button[name], playing and self.panelOpen)
    end
end

function HUDController:updateModalFlag()
    local open = self.panelOpen or self.overlayOpen
    if open ~= Flow.state.modalOpen then
        Flow.setModal(open)
        Flow.emit("modalChanged", open)
    end
    self:refreshExploreUI()
end

-- Distribui os botões nos slots de baixo para cima, deixando o espaço livre para o texto.
-- Cada opção recebe um número (atalho 1–4) na ordem em que aparece.
local function assignButtons(self, prefix, slots, list)
    list = list or {}
    local first = slots - #list + 1
    local keys = {}
    for i = 1, slots do
        local name = prefix .. i
        local btn = self.button[name]
        local index = i - first + 1
        local spec = (i >= first) and list[index] or nil
        if spec then
            btn.visible = true
            btn.label = string.format("%d   %s", index, spec.label)
            btn.labelFontSize = fontSize("button")
            btn.disabled = spec.disabled and true or false
            self.slotLabels[name] = spec.label
            self.actions[name] = (not spec.disabled) and spec.action or nil
            keys[index] = name
        else
            btn.visible = false
            self.slotLabels[name] = nil
            self.actions[name] = nil
        end
    end
    self.keySlots[prefix] = keys
end

-- Aplica o tamanho de texto escolhido nas opções
function HUDController:applyTextSize()
    self.text.ObjectiveText.fontSize = fontSize("objective")
    self.text.OverlayBody.fontSize = fontSize("overlay")
    self.text.ToastText.fontSize = fontSize("toast")
    self.text.PanelBody.fontSize = fontSize("body")
end

-- spec = { title, subtitle, body, small, buttons = { {label, action, disabled}, ... } }
function HUDController:showPanel(spec)
    self.text.PanelTitle.text = spec.title or ""
    self.text.PanelSubtitle.text = spec.subtitle or ""
    self.text.PanelBody.fontSize = fontSize(spec.small and "bodySmall" or "body")
    self.text.PanelBody.text = spec.body or ""
    assignButtons(self, "PanelBtn", PANEL_SLOTS, spec.buttons)
    self.modalDim.visible = true
    self.panelOpen = true
    self:updateModalFlag()
end

function HUDController:closePanel()
    self.modalDim.visible = false
    self.panelOpen = false
    self.keySlots.PanelBtn = {}
    for i = 1, PANEL_SLOTS do self.actions["PanelBtn" .. i] = nil end
    self:updateModalFlag()
end

-- spec = { mode, title, subtitle, body, footer, back = fn (Esc), buttons = {...} }
function HUDController:showOverlay(spec)
    self:closePanel()
    self.overlayMode = spec.mode
    self.overlayBack = spec.back
    self.text.OverlayTitle.text = spec.title or ""
    self.text.OverlaySubtitle.text = spec.subtitle or ""
    self.text.OverlayBody.text = spec.body or ""
    self.text.OverlayFooter.text = spec.footer or (spec.back and FOOTER_BACK or FOOTER_DEFAULT)
    assignButtons(self, "OverlayBtn", OVERLAY_SLOTS, spec.buttons)
    self.overlayBg:setColor(0.01, 0.012, 0.02, OVERLAY_ALPHA[spec.mode] or OVERLAY_ALPHA_DEFAULT)
    self.overlayBg.visible = true
    self.overlayOpen = true
    self:setTopBarVisible(false)
    self:hideToast()
    self:updateModalFlag()
end

function HUDController:closeOverlay()
    self.overlayBg.visible = false
    self.overlayOpen = false
    self.overlayMode = nil
    self.overlayBack = nil
    self.keySlots.OverlayBtn = {}
    for i = 1, OVERLAY_SLOTS do self.actions["OverlayBtn" .. i] = nil end
    self:setTopBarVisible(Flow.state.phase == "playing")
    self:updateModalFlag()
end

function HUDController:toast(message)
    self.text.ToastText.text = message
    self.toastBg.visible = true
    self.toastTime = TOAST_SECONDS
end

function HUDController:hideToast()
    self.toastBg.visible = false
    self.toastTime = 0
end

----------------------------------------------------------------------
-- Barra superior
----------------------------------------------------------------------
function HUDController:refreshObjective()
    local case = Flow.currentCase()
    local night = N.nights[Flow.state.night]
    self.text.NightText.text = string.format("Noite %d/%d — %s", Flow.state.night, N.nightCount, night and night.subtitle or "")
    if case then
        local readCount, total = Flow.progress(case)
        self.text.ObjectiveText.text = string.format("%s\nFontes consultadas: %d/%d\n%s", case.objective, readCount, total, KEY_HINTS)
    else
        self.text.ObjectiveText.text = ""
    end
end

function HUDController:onCaseStarted(case)
    self.button.BtnHelp.label = "Ajuda"
    self:refreshObjective()
    self:toast("Novo registro a conferir: sepultura " .. N.graves[case.grave].number .. " — " .. case.title .. ". Procure a luz fria.")
end

function HUDController:onIdleHint()
    self.button.BtnHelp.label = "Ajuda (!)"
    if not self.panelOpen and not self.overlayOpen then
        self:toast(N.toasts.idleHint)
    end
end

-- Aviso no centro da tela para o objeto sob a mira
function HUDController:onFocus(h)
    local label = self.text.HoverLabel
    if not h or self.panelOpen or self.overlayOpen then
        label.visible = false
        return
    end
    local caption
    if h.kind == "grave" then
        local g = N.graves[h.grave]
        caption = "Examinar a sepultura " .. g.number
        local case = Flow.currentCase()
        if case and case.grave == h.grave then
            caption = caption .. " — caso atual"
        end
    elseif h.kind == "book" then
        caption = "Ler o livro de registros"
    else
        caption = "Arquivo da Câmara"
    end
    label.text = "[E] " .. caption
    label.visible = true
end

----------------------------------------------------------------------
-- Telas: sepultura, documentos, livro, confronto
----------------------------------------------------------------------
local function readMark(id)
    return Flow.isRead(id) and "  (lido)" or ""
end

function HUDController:onWorldClick(h)
    if h.kind == "grave" then
        self:openGrave(h.grave)
    elseif h.kind == "book" then
        self:openBook()
    else
        self:toast(N.toasts.crypt)
    end
end

function HUDController:openGrave(g)
    local grave = N.graves[g]
    local case = Flow.currentCase()
    local isCase = case and case.grave == g

    if not isCase then
        local other = Flow.caseForGrave(g)
        local note
        if other and Flow.isResolved(other) then
            note = N.toasts.resolvedGrave .. "\n" .. other.summary
        else
            note = N.toasts.notCaseGrave
        end
        self:showPanel({
            title = "Sepultura " .. grave.number,
            subtitle = "Inscrição da lápide",
            body = Flow.inscription(g) .. "\n\n" .. note,
            buttons = { { label = "Fechar", action = function() self:closePanel() end } },
        })
        return
    end

    Flow.markRead(Flow.graveEvidenceId(g))
    local back = function() self:openGrave(g) end
    local buttons = {}
    for _, id in ipairs(case.evidence) do
        local ev = N.evidence[id]
        local label
        if ev.kind == "book" then
            label = "Consultar o livro de registros" .. readMark(id)
        else
            label = "Ler: " .. ev.title .. readMark(id)
        end
        buttons[#buttons + 1] = { label = label, action = function() self:openEvidence(id, back) end }
    end
    local readCount, total = Flow.progress(case)
    local can = Flow.canConfront(case)
    local confrontLabel = case.decision and "Decidir o destino do livro" or "Confrontar registros"
    if not can then
        confrontLabel = confrontLabel .. string.format("  (%d/%d fontes lidas)", readCount, total)
    end
    buttons[#buttons + 1] = { label = confrontLabel, disabled = not can, action = function() self:openConfront() end }

    self:showPanel({
        title = "Sepultura " .. grave.number .. " — " .. case.title,
        subtitle = "Inscrição da lápide",
        body = Flow.inscription(g) .. "\n\n" .. case.objective,
        buttons = buttons,
    })
end

function HUDController:openEvidence(id, back)
    Flow.markRead(id)
    local ev = N.evidence[id]
    self:showPanel({
        title = ev.title,
        subtitle = ev.subtitle or KIND_LABEL[ev.kind] or "",
        body = Flow.evidenceBody(id),
        buttons = {
            { label = "Voltar", action = back },
            { label = "Fechar", action = function() self:closePanel() end },
        },
    })
end

function HUDController:openBook()
    if Flow.state.phase ~= "playing" then return end
    local case = Flow.currentCase()
    local buttons = {}
    local body
    if case then
        local lines = { "Caso atual: " .. case.objective, "", "Fontes do caso:" }
        for _, id in ipairs(Flow.requiredSources(case)) do
            lines[#lines + 1] = "• " .. Flow.sourceTitle(id) .. (Flow.isRead(id) and " — lida" or " — não consultada")
        end
        body = table.concat(lines, "\n")
        for _, id in ipairs(case.evidence) do
            if id:sub(1, 5) == "book:" then
                buttons[#buttons + 1] = {
                    label = "Ler o registro nº " .. N.graves[case.grave].number .. readMark(id),
                    action = function() self:openEvidence(id, function() self:openBook() end) end,
                }
            end
        end
        buttons[#buttons + 1] = {
            label = "Ir para a sepultura " .. N.graves[case.grave].number,
            action = function() self:openGrave(case.grave) end,
        }
    else
        body = "Nenhum caso aberto."
    end
    buttons[#buttons + 1] = {
        label = string.format("Anotações do coveiro (%d)", #Flow.state.notes),
        action = function() self:openNotes() end,
    }
    if Flow.state.flags.night1_event then
        buttons[#buttons + 1] = {
            label = "Página rasgada" .. readMark("pagina_rasgada"),
            action = function() self:openEvidence("pagina_rasgada", function() self:openBook() end) end,
        }
    end
    while #buttons > PANEL_SLOTS do table.remove(buttons) end
    self:showPanel({
        title = "Livro de registros",
        subtitle = N.town .. " — 1845",
        body = body,
        buttons = buttons,
    })
end

function HUDController:openNotes()
    local notes = Flow.state.notes
    local body
    if #notes == 0 then
        body = "Nenhuma anotação ainda. Cada registro corrigido e cada mudança estranha ficarão anotados aqui."
    else
        local lines = {}
        for _, n in ipairs(notes) do lines[#lines + 1] = "• " .. n end
        body = table.concat(lines, "\n")
    end
    if Flow.state.flags.night2_event then
        body = body .. "\n\nVocê pode reler o testemunho do Padre Inácio abaixo."
    end
    local buttons = { { label = "Voltar ao livro", action = function() self:openBook() end } }
    if Flow.state.flags.night2_event then
        table.insert(buttons, 1, {
            label = "Reler o testemunho do Padre Inácio",
            action = function() self:openEvidence("testemunho_vigario", function() self:openNotes() end) end,
        })
    end
    buttons[#buttons + 1] = { label = "Fechar", action = function() self:closePanel() end }
    self:showPanel({
        title = "Anotações do coveiro",
        subtitle = "Histórico das descobertas",
        body = body,
        small = true,
        buttons = buttons,
    })
end

function HUDController:openConfront()
    local case = Flow.currentCase()
    if not case then return end
    local lines = { case.question, "", "Fontes consultadas:" }
    for _, id in ipairs(Flow.requiredSources(case)) do
        lines[#lines + 1] = "• " .. Flow.sourceTitle(id)
    end
    local buttons = {}
    for i, h in ipairs(case.hypotheses) do
        buttons[#buttons + 1] = { label = h.text, action = function() self:choose(i) end }
    end
    if not case.decision then
        buttons[#buttons + 1] = { label = "Voltar à sepultura", action = function() self:openGrave(case.grave) end }
    end
    self:showPanel({
        title = case.decision and "A última página" or ("Confrontar registros — sepultura " .. N.graves[case.grave].number),
        subtitle = case.title,
        body = table.concat(lines, "\n"),
        buttons = buttons,
    })
end

function HUDController:choose(index)
    local result = Flow.choose(index)
    if not result then return end
    local case = result.case
    if result.kind == "back" then
        self:openGrave(case.grave)
    elseif result.kind == "correct" then
        self:refreshObjective()
        self:showPanel({
            title = "Registro corrigido",
            subtitle = "Sepultura " .. N.graves[case.grave].number .. " — " .. case.title,
            body = result.text,
            buttons = { { label = "Continuar", action = function()
                self:closePanel()
                Flow.advance()
            end } },
        })
    elseif result.kind == "wrong" then
        self:showPanel({
            title = "As provas não sustentam isso",
            subtitle = "O registro continua aberto",
            body = result.text .. "\n\nA névoa sobre o cemitério fica um pouco mais densa.",
            buttons = {
                { label = "Tentar outra conclusão", action = function() self:openConfront() end },
                { label = "Rever os documentos", action = function() self:openGrave(case.grave) end },
            },
        })
    elseif result.kind == "ending" then
        self:showEnding(result.ending, 1)
    end
end

function HUDController:openHelp()
    self.button.BtnHelp.label = "Ajuda"
    Flow.state.idle = 0
    self:showPanel({
        title = "Ajuda",
        subtitle = "Pedir uma pista não tem penalidade",
        body = Flow.hintText() .. "\n\n" .. N.controls,
        small = true,
        buttons = { { label = "Fechar", action = function() self:closePanel() end } },
    })
end

----------------------------------------------------------------------
-- Telas cheias: menu, pausa, noites, finais, créditos
----------------------------------------------------------------------
function HUDController:showMainMenu()
    self:showOverlay({
        mode = "menu",
        title = N.menu.title,
        subtitle = N.menu.subtitle,
        body = N.menu.body,
        footer = FOOTER_DEFAULT .. "   ·   Doriax Flash Jam 2026",
        buttons = {
            { label = "Iniciar", action = function()
                self:closeOverlay()
                Flow.startGame()
            end },
            { label = "Opções", action = function() self:showOptions(function() self:showMainMenu() end) end },
            { label = "Controles", action = function() self:showInfo("Controles", N.controls, function() self:showMainMenu() end) end },
            { label = "Créditos", action = function() self:showInfo("Créditos", N.credits, function() self:showMainMenu() end) end },
        },
    })
end

function HUDController:showInfo(title, body, back)
    self:showOverlay({
        mode = "info",
        title = title,
        subtitle = "",
        body = body,
        back = back,
        buttons = { { label = "Voltar", action = back } },
    })
end

-- Opções: cada botão alterna um valor e a tela se redesenha com o novo estado
function HUDController:showOptions(back)
    local refresh = function() self:showOptions(back) end
    self:showOverlay({
        mode = "options",
        title = "Opções",
        subtitle = "Valem até fechar o jogo",
        body = "Sensibilidade do mouse: quanto a câmera gira ao mover o mouse.\n"
            .. "Inverter eixo vertical: mover o mouse para cima olha para baixo.\n"
            .. "Texto grande: aumenta os textos dos painéis, documentos e avisos.",
        back = back,
        buttons = {
            { label = "Sensibilidade do mouse: " .. Settings.sensitivityLabel(), action = function()
                Settings.cycleSensitivity(); refresh()
            end },
            { label = "Inverter eixo vertical: " .. (Settings.invertY and "Sim" or "Não"), action = function()
                Settings.toggleInvertY(); refresh()
            end },
            { label = "Texto grande: " .. (Settings.largeText and "Sim" or "Não"), action = function()
                Settings.toggleLargeText(); self:applyTextSize(); refresh()
            end },
            { label = "Voltar", action = back },
        },
    })
end

-- Pergunta antes de uma ação que descarta o progresso
function HUDController:confirm(title, body, yesLabel, onYes, onNo)
    self:showOverlay({
        mode = "confirm",
        title = title,
        subtitle = "",
        body = body,
        back = onNo,
        buttons = {
            { label = "Não, voltar", action = onNo },
            { label = yesLabel, action = onYes },
        },
    })
end

function HUDController:pauseSummary()
    local s = Flow.state
    local resolvedCount, nightTotal, nightDone = 0, 0, 0
    for _, c in ipairs(N.cases) do
        if s.resolved[c.id] then resolvedCount = resolvedCount + 1 end
        if c.night == s.night then
            nightTotal = nightTotal + 1
            if s.resolved[c.id] then nightDone = nightDone + 1 end
        end
    end
    local lines = {}
    local case = Flow.currentCase()
    if case then
        local readCount, total = Flow.progress(case)
        lines[#lines + 1] = "Objetivo: " .. case.objective
        lines[#lines + 1] = string.format("Fontes consultadas neste caso: %d de %d", readCount, total)
    end
    lines[#lines + 1] = string.format("Registros desta noite: %d de %d   ·   Campanha: %d de %d", nightDone, nightTotal, resolvedCount, #N.cases)
    if s.mistakes > 0 then
        lines[#lines + 1] = string.format("Conclusões erradas até agora: %d", s.mistakes)
    end
    return table.concat(lines, "\n")
end

function HUDController:openPause()
    if Flow.state.phase ~= "playing" then return end
    local night = N.nights[Flow.state.night]
    local resume = function() self:closeOverlay() end
    self:showOverlay({
        mode = "pause",
        title = "Pausa",
        subtitle = string.format("Noite %d de %d — %s", Flow.state.night, N.nightCount, night and night.subtitle or ""),
        body = self:pauseSummary(),
        back = resume,
        footer = "1–4 ou clique para escolher   ·   Esc: continuar",
        buttons = {
            { label = "Continuar", action = resume },
            { label = "Opções", action = function() self:showOptions(function() self:openPause() end) end },
            { label = "Controles", action = function() self:showInfo("Controles", N.controls, function() self:openPause() end) end },
            { label = "Voltar ao menu principal", action = function()
                self:confirm("Voltar ao menu principal?",
                    "O progresso desta campanha será perdido e a história recomeça da primeira noite.",
                    "Sim, voltar ao menu",
                    function() Flow.reset(); self:showMainMenu() end,
                    function() self:openPause() end)
            end },
        },
    })
end

function HUDController:showNightIntro(n)
    local night = N.nights[n]
    if not night then return end
    local body = night.intro
    local previous = N.nights[n - 1]
    if previous and previous.outro then
        body = previous.outro .. "\n\n" .. night.intro
    end
    self:showOverlay({
        mode = "night",
        title = night.title,
        subtitle = string.format("%s   ·   noite %d de %d", night.subtitle, n, N.nightCount),
        body = body,
        footer = "Enter ou 1: começar",
        buttons = { { label = "Começar a noite", action = function()
            self:closeOverlay()
            Flow.beginNight()
            self:setTopBarVisible(true)
        end } },
    })
end

function HUDController:showEnding(kind, page)
    local ending = N.endings[kind]
    if not ending then return end
    local body = ending.pages[page]
    local isLast = page >= #ending.pages
    if isLast and Flow.state.mistakes >= 3 then
        body = body .. N.endings.mistakesNote
    end
    self:showOverlay({
        mode = "ending",
        title = ending.title,
        subtitle = string.format("Epílogo — %d de %d", page, #ending.pages),
        body = body,
        footer = "Enter ou 1: continuar",
        buttons = { {
            label = isLast and "Créditos" or "Continuar",
            action = function()
                if isLast then self:showCredits() else self:showEnding(kind, page + 1) end
            end,
        } },
    })
end

function HUDController:showCredits()
    local ending = Flow.state.ending and N.endings[Flow.state.ending]
    self:showOverlay({
        mode = "credits",
        title = "Créditos",
        subtitle = ending and ("Final: " .. ending.title .. "   ·   obrigado por jogar") or "Obrigado por jogar",
        body = N.credits,
        buttons = {
            { label = "Jogar novamente", action = function()
                Flow.reset()
                self:showMainMenu()
            end },
        },
    })
end

----------------------------------------------------------------------
-- Eventos do motor
----------------------------------------------------------------------
-- Aciona a opção numerada n do painel aberto (ou da tela cheia)
function HUDController:pressSlot(n)
    local prefix = self.panelOpen and "PanelBtn" or (self.overlayOpen and "OverlayBtn" or nil)
    if not prefix then return false end
    local name = self.keySlots[prefix][n]
    if name and self.actions[name] then
        self:handleButton(name)
        return true
    end
    return false
end

function HUDController:onKeyDown(key, isRepeat, mods)
    if isRepeat then return end

    local digit = DIGIT_KEYS and DIGIT_KEYS[key]
    if digit then
        self:pressSlot(digit)
        return
    end
    -- Enter confirma a primeira opção das telas cheias (nos painéis não, para não escolher hipótese sem querer)
    if (key == Input.KEY_ENTER or key == Input.KEY_KP_ENTER) and self.overlayOpen and not self.panelOpen then
        self:pressSlot(1)
        return
    end

    local playing = Flow.state.phase == "playing" and not self.overlayOpen
    if key == Input.KEY_L and playing then
        if self.panelOpen then self:closePanel() else self:openBook() end
        return
    end
    if key == Input.KEY_H and playing then
        if self.panelOpen then self:closePanel() else self:openHelp() end
        return
    end
    if key ~= Input.KEY_ESCAPE then return end
    if self.panelOpen then
        self:closePanel()
    elseif self.overlayOpen and self.overlayBack then
        self.overlayBack()
    elseif not self.overlayOpen and Flow.state.phase == "playing" then
        self:openPause()
    end
end

function HUDController:runSelfTest()
    local SelfTest = require("game.selftest")
    if Flow.worldController then
        local ok, err = pcall(SelfTest.aimTest, Flow.worldController)
        if not ok then Log.error(tostring(err)) end
    end
    for _, kind in ipairs({ "reveal", "preserve" }) do
        local ok, err = pcall(SelfTest.run, self, kind)
        if not ok then
            Log.error(tostring(err))
            return
        end
    end
end

function HUDController:onUpdate()
    local dt = Engine.deltatime
    if self.selfTest and not self.selfTestDone then
        self.selfTestFrames = (self.selfTestFrames or 0) + 1
        if self.selfTestFrames > 90 then
            self.selfTestDone = true
            self:runSelfTest()
        end
    end
    Flow.tick(dt)
    if self.toastTime > 0 then
        self.toastTime = self.toastTime - dt
        if self.toastTime <= 0 then self:hideToast() end
    end
end

return HUDController
