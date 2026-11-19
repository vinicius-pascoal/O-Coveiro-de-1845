-- UIController da cena HUD: painel modal reutilizável, sobreposição de tela cheia
-- (menu, noites, finais), barra superior, dica flutuante e avisos.

local Flow = require("game.flow")
local N = require("game.narrative")
local Settings = require("game.settings")
local Saves = require("game.saves")

local HUDController = {
    properties = {
        { name = "selfTest", displayName = "Self Test", type = "bool", default = false },
        { name = "demo", displayName = "Visual Demo", type = "bool", default = false },
        { name = "demoGuide", displayName = "Visual Demo (Guide)", type = "bool", default = false },
        { name = "demoFinale", displayName = "Visual Demo (Finale)", type = "bool", default = false },
    }
}

local TEXTS = {
    "NightText", "ObjectiveText", "ProgressLabel", "KeysText", "HoverLabel", "Crosshair", "ToastText",
    "PanelTitle", "PanelSubtitle", "PanelBody",
    "OverlayTitle", "OverlaySubtitle", "OverlayBody", "OverlayFooter",
    "NotebookTitle", "NotebookText", "SpeechName", "SpeechText",
}
local BUBBLE_MAX_TEXT_W = 330   -- largura máxima do texto do balão de fala
local BUBBLE_PAD_X = 24
local BUBBLE_TEXT_Y = 38
local BUBBLE_SIDE_GAP = 70      -- distância da cabeça quando o balão vai para o lado
local CHISEL_FILL_W = 238
local NOTEBOOK_W = 440
local ADVANCE_MAX_DELAY = 12   -- segundos para ler a resolução antes de a noite acabar
local ENDING_DELAY = 5.2       -- despedida (escrivão e Benedito) antes do epílogo
local URGENT_CUT = 0.6         -- segundos que a legenda atual ainda fica quando chega uma fala urgente
local PROGRESS_ICONS = 6

-- Ícones recortados da spritesheet (assets/ui/horror). Botões e títulos escolhem pelo nome.
local ICONS = {
    play = "ui/horror/icon_play.png", gear = "ui/horror/icon_gear.png", question = "ui/horror/icon_question.png",
    home = "ui/horror/icon_home.png", x = "ui/horror/icon_x.png", check = "ui/horror/icon_check.png",
    plus = "ui/horror/icon_plus.png", minus = "ui/horror/icon_minus.png", pause = "ui/horror/icon_pause.png",
    candle = "ui/horror/candle.png", skull = "ui/horror/skull.png", tomb = "ui/horror/tombstone.png",
    speaker = "ui/horror/icon_speaker.png", mute = "ui/horror/icon_mute.png",
    correct = "ui/horror/tile_check_on.png", wrong = "ui/horror/tile_x_on.png", help = "ui/horror/tile_help_hover.png",
}
local PROGRESS_ON = "ui/horror/tile_check_on.png"
local PROGRESS_OFF = "ui/horror/tile_check_off.png"

-- Medidas da diagramação responsiva (pixels do canvas)
local SCREEN_MARGIN = 16
local CARD_PAD_X = 56
local OVERLAY_BUTTON_W, OVERLAY_BUTTON_H, OVERLAY_BUTTON_GAP = 440, 50, 10
local OVERLAY_BODY_WIDTH = { menu = 560, options = 640, info = 620, pause = 620, confirm = 520, credits = 620 }
local OVERLAY_BODY_WIDTH_DEFAULT = 780   -- prólogo, noites e epílogos
local PANEL_MIN_W, PANEL_MAX_W = 560, 960
local PANEL_PAD = 36
local TOAST_MAX_TEXT_W = 720
local OBJECTIVE_MAX_W = 600
local MIN_BODY_FONT = 14

-- Largura aproximada da linha mais longa (antes de o motor medir o texto de verdade)
local function estimateWidth(s, size)
    local longest = 0
    for line in ((s or "") .. "\n"):gmatch("(.-)\n") do
        local n = (utf8 and utf8.len(line)) or #line
        if n > longest then longest = n end
    end
    return longest * size * 0.5
end

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end
local BUTTONS = {
    "BtnBook", "BtnHelp", "BtnPause", "PanelClose",
    "PanelBtn1", "PanelBtn2", "PanelBtn3", "PanelBtn4", "PanelBtn5", "PanelBtn6",
    "OverlayBtn1", "OverlayBtn2", "OverlayBtn3", "OverlayBtn4", "OverlayBtn5", "OverlayBtn6", "OverlayBtn7",
}

-- Papéis: o painel padrão usa a moldura escura da spritesheet (assets/ui/horror);
-- documentos mostram por cima a folha clara (PanelPaper) tingida com a cor do papel (sRGB).
local PAPER = {
    default   = { title = { 0.95, 0.80, 0.55 }, sub = { 0.74, 0.62, 0.56 }, body = { 0.93, 0.90, 0.86 } },
    letter    = { bg = { 0.92, 0.84, 0.66, 1.0 }, title = { 0.42, 0.10, 0.06 }, sub = { 0.38, 0.28, 0.20 }, body = { 0.16, 0.11, 0.07 } },
    book      = { bg = { 0.80, 0.70, 0.52, 1.0 }, title = { 0.34, 0.08, 0.05 }, sub = { 0.30, 0.22, 0.16 }, body = { 0.12, 0.08, 0.05 } },
    record    = { bg = { 0.84, 0.82, 0.78, 1.0 }, title = { 0.30, 0.10, 0.12 }, sub = { 0.32, 0.28, 0.28 }, body = { 0.12, 0.11, 0.12 } },
    testimony = { bg = { 0.84, 0.82, 0.78, 1.0 }, title = { 0.30, 0.10, 0.12 }, sub = { 0.32, 0.28, 0.28 }, body = { 0.12, 0.11, 0.12 } },
}

-- Legendas: pensamentos de Severino (vela), sussurros (fantasma) e avisos
local SAY_STYLE = {
    thought = { color = { 0.98, 0.88, 0.70 }, prefix = "Severino: ", icon = "candle" },
    whisper = { color = { 0.70, 0.88, 0.92 }, prefix = "", icon = "ghost" },
    spirit  = { color = { 0.74, 0.96, 0.86 }, prefix = "", icon = "ghost" },
    info    = { color = { 0.93, 0.89, 0.84 }, prefix = "" },
}
local TOAST_TEXT_X = 30       -- margem do texto sem ícone
local TOAST_TEXT_X_ICON = 74  -- margem do texto quando há ícone à esquerda
local TOAST_TEXT_Y = 18

-- Lápide decorativa só nas telas "de capa"
local TOMB_MODES = { menu = true, credits = true }
local LOGO_SIZE = 120

local REVEAL_CHARS_PER_SECOND = 70
-- Botões do topo só aparecem com o cursor livre (painel aberto); na exploração o
-- mouse fica preso e os atalhos L / H / Esc fazem o mesmo papel.
local TOP_BUTTONS = { "BtnBook", "BtnHelp", "BtnPause" }
-- Atalhos aparecem na barra só durante a primeira noite; depois ficam em Opções > Controles e na Ajuda (H)
local KEY_HINTS = "E examinar  ·  Tab caderno  ·  L livro  ·  H ajuda  ·  Esc pausa"

local PANEL_SLOTS = 6
local MODAL_DIM_ALPHA = 0.55
local OVERLAY_SLOTS = 7
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

-- Escurecimento atrás do cartão: menus deixam ver o cemitério, histórias isolam o texto
local OVERLAY_ALPHA = { menu = 0.30, options = 0.45, info = 0.50, pause = 0.45, confirm = 0.55, credits = 0.55 }
local OVERLAY_ALPHA_DEFAULT = 0.78

-- Sliders das opções: trilho à direita do botão (OverlayBtnNTrack, filho do botão,
-- ancorado em CENTER_RIGHT), com preenchimento e marcador dentro dele
local SLIDER_TRACK_W, SLIDER_TRACK_H, SLIDER_RIGHT = 170, 12, 26
local SLIDER_INNER_PAD = 2
local SLIDER_KNOB_W = 10
local SLIDER_LABEL_X = 62          -- onde começa o texto do botão quando há slider (depois do ícone)
local SLIDER_GRAB_PAD = 14         -- folga horizontal para pegar o trilho com o mouse
local KNOB_COLOR = { 0.95, 0.86, 0.66 }
local KNOB_COLOR_FOCUS = { 1.0, 0.62, 0.30 }
local FOOTER_SLIDERS = "Arraste na barra ou use as setas   ·   1–4 escolhe   ·   Esc: voltar"

local FOOTER_DEFAULT = "1–4 ou clique para escolher   ·   Enter: primeira opção"
local FOOTER_BACK = "1–4 ou clique para escolher   ·   Esc: voltar"

local DIGIT_KEYS -- preenchido no init (Input só existe em tempo de execução)

local KIND_LABEL = {
    book = "Livro de registros",
    letter = "Carta",
    testimony = "Testemunho",
    record = "Documento",
}

local function caseById(id)
    for _, c in ipairs(N.cases) do
        if c.id == id then return c end
    end
end

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
        [Input.KEY_1] = 1, [Input.KEY_2] = 2, [Input.KEY_3] = 3, [Input.KEY_4] = 4, [Input.KEY_5] = 5, [Input.KEY_6] = 6, [Input.KEY_7] = 7,
        [Input.KEY_KP_1] = 1, [Input.KEY_KP_2] = 2, [Input.KEY_KP_3] = 3, [Input.KEY_KP_4] = 4, [Input.KEY_KP_5] = 5, [Input.KEY_KP_6] = 6, [Input.KEY_KP_7] = 7,
    }
    self.panelBg = Image(s, findEntity(s, "PanelBg"))
    self.panelPaper = Image(s, findEntity(s, "PanelPaper"))
    self.toastIcon = {
        ghost = Image(s, findEntity(s, "ToastGhost")),
        candle = Image(s, findEntity(s, "ToastCandle")),
    }
    self.topBarBg = Image(s, findEntity(s, "TopBarBg"))
    self.overlayTomb = Image(s, findEntity(s, "OverlayTomb"))
    self.overlayCard = Image(s, findEntity(s, "OverlayCard"))
    self.overlayRule = Image(s, findEntity(s, "OverlayRule"))
    self.overlaySkull = Image(s, findEntity(s, "OverlaySkull"))
    self.overlayLogo = Image(s, findEntity(s, "OverlayLogo"))
    self.overlayCandles = { Image(s, findEntity(s, "OverlayCandleL")), Image(s, findEntity(s, "OverlayCandleR")) }
    self.panelIcon = Image(s, findEntity(s, "PanelIcon"))
    self.btnIcon = {}
    for i = 1, PANEL_SLOTS do
        self.btnIcon["PanelBtn" .. i] = Image(s, findEntity(s, "PanelBtn" .. i .. "Icon"))
    end
    self.sliders = {}        -- nome do botão -> peças do slider
    self.sliderSpec = {}     -- nome do botão -> spec.slider da tela atual
    for i = 1, OVERLAY_SLOTS do
        local name = "OverlayBtn" .. i
        self.btnIcon[name] = Image(s, findEntity(s, name .. "Icon"))
        local sl = {
            track = Image(s, findEntity(s, name .. "Track")),
            fill = Image(s, findEntity(s, name .. "Fill")),
            knob = Image(s, findEntity(s, name .. "Knob")),
            label = self.button[name]:getLabelObject(),
        }
        sl.track.visible = false
        sl.track.width, sl.track.height = SLIDER_TRACK_W, SLIDER_TRACK_H
        sl.track.positionOffset = Vector2(-SLIDER_RIGHT, 0)
        sl.knob.width = SLIDER_KNOB_W
        self.sliders[name] = sl
    end
    self.progressIcons = {}
    for i = 1, PROGRESS_ICONS do
        self.progressIcons[i] = Image(s, findEntity(s, "ProgressIcon" .. i))
    end
    self.chiselBar = Image(s, findEntity(s, "ChiselBar"))
    self.chiselFill = Image(s, findEntity(s, "ChiselFill"))
    self.chiselBar.visible = false
    self.bubbleBg = Image(s, findEntity(s, "SpeechBubble"))
    self.bubbleBg.visible = false
    self.bubble = nil
    self.notebookBg = Image(s, findEntity(s, "NotebookBg"))
    self.notebookBg.visible = false
    self.notebookOpen = false
    self.notebookDirty = true
    self.frame = 0
    self.iconPaths = {}      -- imagem -> textura atual (evita recarregar a cada frame)
    self.placed = {}         -- objeto -> "x,y" já aplicado
    self.topBarShown = false
    self.shrinkWait = 0
    self.sayQueue = {}
    self.reveal = nil

    Settings.load()
    self:applyTextSize()

    RegisterEngineEvent(self, "onUpdate")
    RegisterEngineEvent(self, "onKeyDown")

    Saves.install()
    Flow.on("nightIntro", "hud", function(n) self:showNightIntro(n) end)
    Flow.on("casesOpened", "hud", function(list) self:onCasesOpened(list) end)
    Flow.on("casesChanged", "hud", function() self:refreshObjective() end)
    Flow.on("evidenceRead", "hud", function() self:refreshObjective() end)
    Flow.on("idleHint", "hud", function() self:onIdleHint() end)
    Flow.on("worldClick", "hud", function(h) self:onWorldClick(h) end)
    Flow.on("focus", "hud", function(h) self:onFocus(h) end)
    Flow.on("whisper", "hud", function(w)
        self:say(w.text, w.speaker == "Severino" and "thought" or "whisper")
    end)
    Flow.on("reset", "hud", function()
        self.sayQueue = {}
        self.advanceTimer = nil
        self.pendingEnding, self.endingDelay = nil, nil
        self.notebookOpen = false
        self:setChiselProgress(nil)
    end)
    Flow.on("spiritAwake", "hud", function(case)
        local sp = Flow.spirit(case)
        self:speak(case.id, sp.name, sp.awaken)
    end)
    Flow.on("caseResolved", "hud", function(case) self:onResolved(case) end)
    Flow.on("guideSay", "hud", function(speaker, text, source)
        -- pensamentos do coveiro continuam na legenda; o que o vulto e os mortos dizem
        -- aparece num balão sobre a cabeça de quem fala
        if speaker == "Severino" then
            self:say(text, "thought", true)
        elseif source then
            self:speak(source, speaker == "Sussurro" and "O vulto" or speaker, text)
        else
            self:say(text, "whisper", true)
        end
    end)
    Flow.on("chiselProgress", "hud", function(_, p) self:setChiselProgress(p) end)
    for _, ev in ipairs({ "clueNoted", "evidenceRead", "casesChanged", "chiselReady", "caseProven" }) do
        Flow.on(ev, "hud_notebook", function() self.notebookDirty = true end)
    end
    Flow.on("nightIntro", "hud_clear", function()
        -- histórias da noite anterior não atravessam a abertura da próxima
        self.sayQueue = {}
        self:hideToast()
        self.advanceTimer = nil
    end)
    Flow.on("mistake", "hud", function(_, count)
        local lines = N.mistakeWhispers or {}
        if #lines > 0 then self:say(lines[(count - 1) % #lines + 1], "whisper") end
    end)

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
    self.topBarShown = visible
    self:refreshObjective()
    self:refreshExploreUI()
end

-- Troca a textura de uma imagem só quando muda; nil esconde
function HUDController:setIcon(img, name, path)
    path = path or (name and ICONS[name])
    if not img then return end
    if not path then
        img.visible = false
        return
    end
    if self.iconPaths[img] ~= path then
        img:setTexture(path)
        self.iconPaths[img] = path
    end
    img.visible = true
end

-- Posiciona (positionOffset) só quando o valor muda
function HUDController:place(obj, x, y)
    x, y = math.floor(x + 0.5), math.floor(y + 0.5)
    local key = x .. "," .. y
    if self.placed[obj] ~= key then
        obj.positionOffset = Vector2(x, y)
        self.placed[obj] = key
    end
end

local function setSize(obj, w, h)
    w = math.max(1, math.floor(w + 0.5))
    if obj.width ~= w then obj.width = w end
    if h then
        h = math.max(1, math.floor(h + 0.5))
        if obj.height ~= h then obj.height = h end
    end
end

-- Muda a largura de um texto com quebra de linha e força o motor a quebrar de novo
local function setTextWidth(textObj, w)
    w = math.floor(w + 0.5)
    if textObj.width ~= w then
        textObj.width = w
        local t = textObj.text
        textObj.text = t .. " "
        textObj.text = t
    end
end

-- Texto de uma linha só ocupa a própria largura; texto longo quebra em maxW
local function fitTextWidth(textObj, message, size, maxW)
    if estimateWidth(message, size) <= maxW then
        if textObj.fixedWidth then textObj.fixedWidth = false end
    else
        if not textObj.fixedWidth then textObj.fixedWidth = true end
        setTextWidth(textObj, maxW)
    end
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
        local slider = self.sliders and self.sliders[name]
        if spec then
            btn.visible = true
            btn.label = string.format("%d   %s", index, spec.label)
            btn.labelFontSize = fontSize("button")
            btn.disabled = spec.disabled and true or false
            self:setIcon(self.btnIcon[name], spec.icon)
            self.slotLabels[name] = spec.label
            self.actions[name] = (not spec.disabled) and spec.action or nil
            keys[index] = name
        else
            btn.visible = false
            setVisible(self.btnIcon[name], false)
            self.slotLabels[name] = nil
            self.actions[name] = nil
        end
        -- linha com slider: o clique no botão só escolhe o slider (o valor muda pela barra e pelas setas)
        if slider then
            local sliderSpec = spec and spec.slider or nil
            self.sliderSpec[name] = sliderSpec
            setVisible(slider.track, sliderSpec ~= nil)
            if sliderSpec then
                sliderSpec.index = index
                self.actions[name] = function() self:focusSlider(name) end
                self:refreshSlider(name)
            elseif slider.labelShifted then
                slider.label.positionOffset = Vector2(0, 0)
                slider.labelShifted = false
            end
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

----------------------------------------------------------------------
-- Texto que se escreve aos poucos (respeita UTF-8; Espaço completa)
----------------------------------------------------------------------
-- Antes de escrever, o texto completo fica alguns frames invisível para o motor medir
-- a altura final: assim o painel já nasce do tamanho certo e não cresce durante a animação.
local MEASURE_FRAMES = 2

function HUDController:setRevealText(textObj, full, animate)
    if self.reveal and self.reveal.obj == textObj then self.reveal = nil end
    textObj.visible = true
    local len = utf8 and utf8.len(full)
    if not animate or not Settings.animateText or not len or len < 2 then
        textObj.text = full
        return
    end
    textObj.text = full
    textObj.visible = false
    self.reveal = { obj = textObj, full = full, len = len, shown = 0, measuring = MEASURE_FRAMES }
end

-- Recomeça a medição (ex.: a fonte diminuiu para caber na tela)
function HUDController:remeasureReveal(textObj)
    local r = self.reveal
    if not r or r.obj ~= textObj then return end
    r.obj.text = r.full
    r.obj.visible = false
    r.height = nil
    r.shown = 0
    r.measuring = MEASURE_FRAMES
end

function HUDController:finishReveal()
    if not self.reveal then return false end
    self.reveal.obj.text = self.reveal.full
    self.reveal.obj.visible = true
    self.reveal = nil
    return true
end

-- Altura final do texto, mesmo enquanto ele ainda está sendo escrito
function HUDController:textHeight(textObj)
    local r = self.reveal
    if r and r.obj == textObj then
        if r.height then return r.height end
        return textObj.height
    end
    if textObj.text == "" then return 0 end
    return textObj.height
end

function HUDController:updateReveal(dt)
    local r = self.reveal
    if not r then return end
    if r.measuring > 0 then
        r.measuring = r.measuring - 1
        if r.measuring == 0 then
            r.height = r.obj.height
            r.obj.text = ""
            r.obj.visible = true
        end
        return
    end
    r.shown = r.shown + dt * REVEAL_CHARS_PER_SECOND
    local n = math.floor(r.shown)
    if n >= r.len then
        self:finishReveal()
    elseif n > 0 then
        r.obj.text = r.full:sub(1, utf8.offset(r.full, n + 1) - 1)
    end
end

local function applyColor(textObj, c, a)
    textObj:setColor(c[1], c[2], c[3], a or 1)
end

function HUDController:applyPaper(kind)
    local p = PAPER[kind] or PAPER.default
    if p.bg then
        self.panelPaper:setColor(p.bg[1], p.bg[2], p.bg[3], p.bg[4])
        self.panelPaper.visible = true
    else
        self.panelPaper.visible = false
    end
    applyColor(self.text.PanelTitle, p.title)
    applyColor(self.text.PanelSubtitle, p.sub)
    applyColor(self.text.PanelBody, p.body)
end

-- Largura do painel conforme o conteúdo: documentos ganham folha larga, avisos curtos ficam estreitos
local function panelWidthFor(spec, bodySize)
    local need = PANEL_MIN_W
    if spec.paper and spec.paper ~= "default" then need = 820 end
    need = math.max(need, math.min(estimateWidth(spec.body, bodySize), 860) + 2 * PANEL_PAD)
    need = math.max(need, estimateWidth(spec.title, 30) + 2 * PANEL_PAD + 140)
    for i, b in ipairs(spec.buttons or {}) do
        need = math.max(need, estimateWidth(i .. "   " .. b.label, fontSize("button")) + 2 * PANEL_PAD + 130)
    end
    return clamp(need, PANEL_MIN_W, math.min(PANEL_MAX_W, Engine.canvasWidth - 2 * SCREEN_MARGIN))
end

-- spec = { title, subtitle, body, small, paper, icon, reveal, buttons = { {label, action, disabled, icon}, ... } }
function HUDController:showPanel(spec)
    local t = self.text
    -- Conversa com um morto: o painel desce para a parte de baixo e o cemitério fica à vista
    local compact = spec.talk and self.talking ~= nil
    if not compact and self.talking then self:endTalk() end
    self.panelCompact = compact
    local bodySize = fontSize(spec.small and "bodySmall" or "body")
    local w = panelWidthFor(spec, bodySize)
    self.panelWidth = w
    setSize(self.panelBg, w)
    local titleX = spec.icon and (PANEL_PAD + 52) or PANEL_PAD
    self.panelTitleX = titleX
    setTextWidth(t.PanelTitle, w - titleX - 76)
    setTextWidth(t.PanelSubtitle, w - 2 * PANEL_PAD)
    setTextWidth(t.PanelBody, w - 2 * PANEL_PAD)
    for i = 1, PANEL_SLOTS do
        setSize(self.button["PanelBtn" .. i], w - 2 * PANEL_PAD)
    end

    self:applyPaper(spec.paper)
    t.PanelTitle.text = spec.title or ""
    t.PanelSubtitle.text = spec.subtitle or ""
    t.PanelBody.fontSize = bodySize
    self:setRevealText(t.PanelBody, spec.body or "", spec.reveal)
    assignButtons(self, "PanelBtn", PANEL_SLOTS, spec.buttons)
    -- o painel é filho do ModalDim: na conversa ele fica visível, só que transparente
    self.modalDim.visible = true
    self.modalDim:setColor(0, 0, 0, compact and 0 or MODAL_DIM_ALPHA)
    self:setIcon(self.panelIcon, spec.icon)
    self.panelOpen = true
    self.panelFrame = self.frame   -- o E que abriu o painel não pode fechá-lo no mesmo quadro
    self:layoutPanel()
    self:updateModalFlag()
end

-- Altura do painel = título + subtítulo + texto + botões; o texto encolhe se não couber na tela
function HUDController:layoutPanel()
    local t = self.text
    local y = 26
    local titleH = math.max(self:textHeight(t.PanelTitle), self.panelIcon.visible and 44 or 0)
    self:place(t.PanelTitle, self.panelTitleX or PANEL_PAD, y + (self.panelIcon.visible and math.max(0, (44 - self:textHeight(t.PanelTitle)) / 2) or 0))
    y = y + titleH + 6
    if t.PanelSubtitle.text ~= "" then
        self:place(t.PanelSubtitle, PANEL_PAD, y)
        y = y + self:textHeight(t.PanelSubtitle) + 16
    else
        y = y + 10
    end
    self:place(t.PanelBody, PANEL_PAD, y)
    local bodyH = self:textHeight(t.PanelBody)
    y = y + bodyH + 28
    local n = #self.keySlots.PanelBtn
    y = y + (n > 0 and (n * 54 + 16) or 8)

    local maxH = Engine.canvasHeight - 2 * SCREEN_MARGIN
    if y > maxH and t.PanelBody.fontSize > MIN_BODY_FONT and self.shrinkWait <= 0 then
        t.PanelBody.fontSize = t.PanelBody.fontSize - 1
        self:remeasureReveal(t.PanelBody)
        self.shrinkWait = MEASURE_FRAMES + 1
    end
    local h = math.min(y, maxH)
    setSize(self.panelBg, self.panelWidth or 900, h)
    if self.panelCompact then
        self:place(self.panelBg, 0, Engine.canvasHeight / 2 - h / 2 - SCREEN_MARGIN)
    else
        self:place(self.panelBg, 0, 0)
    end
end

-- Começa uma conversa com o morto do caso (a câmera se vira para ele)
function HUDController:beginTalk(case)
    if not Flow.spirit(case) then return false end
    Flow.awaken(case)
    if self.talking ~= case then
        self.talking = case
        self:hideToast()   -- a legenda ocupa o mesmo lugar do painel da conversa
        -- na conversa a barra do objetivo sai de cena: sobra o morto, o balão e as escolhas
        if self.topBarShown then
            self.topBarHiddenByTalk = true
            self:setTopBarVisible(false)
        end
        Flow.emit("talk", case)
    end
    return true
end

function HUDController:endTalk()
    if self.talking then
        self.talking = nil
        -- a fala fixa da conversa sai junto; falas com tempo (ex.: última fala do morto) continuam
        if self.bubble and not self.bubble.timer then self:clearBubble() end
        if self.topBarHiddenByTalk then
            self.topBarHiddenByTalk = nil
            self:setTopBarVisible(Flow.state.phase == "playing")
        end
        Flow.emit("talkEnd")
    end
end

function HUDController:closePanel()
    self:endTalk()
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
    local t = self.text
    self.overlayBodyWidth = math.min(OVERLAY_BODY_WIDTH[spec.mode] or OVERLAY_BODY_WIDTH_DEFAULT,
        Engine.canvasWidth - 2 * (SCREEN_MARGIN + CARD_PAD_X))
    setTextWidth(t.OverlayBody, self.overlayBodyWidth)
    t.OverlayBody.fontSize = fontSize("overlay")
    t.OverlayTitle.text = spec.title or ""
    t.OverlaySubtitle.text = spec.subtitle or ""
    self:setRevealText(t.OverlayBody, spec.body or "", spec.reveal)
    -- o atalho do rodapé acompanha quantas opções a tela tem (Opções chega a 7)
    local nButtons = #(spec.buttons or {})
    local hasSlider = false
    for _, b in ipairs(spec.buttons or {}) do hasSlider = hasSlider or b.slider ~= nil end
    if not hasSlider then self.sliderFocus = nil end
    local footer = spec.footer or (hasSlider and FOOTER_SLIDERS) or (spec.back and FOOTER_BACK or FOOTER_DEFAULT)
    footer = footer:gsub("1–4", nButtons > 1 and ("1–" .. nButtons) or "1")
    t.OverlayFooter.text = footer
    -- só a cena escurece; o conteúdo fica num cartão do tamanho dele (OverlayCard)
    self.overlayBg:setColor(0, 0, 0, OVERLAY_ALPHA[spec.mode] or OVERLAY_ALPHA_DEFAULT)
    self.overlayBg.visible = true
    assignButtons(self, "OverlayBtn", OVERLAY_SLOTS, spec.buttons)
    self.overlayTomb.visible = TOMB_MODES[spec.mode] == true
    self.overlayLogo.visible = spec.logo == true
    self:layoutOverlay()
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

-- Cartão central: empilha título, subtítulo, divisor, texto, botões e rodapé e
-- centraliza tudo na altura da tela. O texto encolhe se a história não couber.
function HUDController:layoutOverlay()
    local t = self.text
    local canvasW, canvasH = Engine.canvasWidth, Engine.canvasHeight
    local titleH = self:textHeight(t.OverlayTitle)
    local hasSub = t.OverlaySubtitle.text ~= ""
    local bodyH = self:textHeight(t.OverlayBody)
    local footerH = t.OverlayFooter.text ~= "" and self:textHeight(t.OverlayFooter) or 0
    local slots = self.keySlots.OverlayBtn
    local n = #slots

    -- posições relativas ao topo do cartão
    local y = 34
    local titleY = y
    y = y + titleH + 8
    local subY = y
    if hasSub then y = y + self:textHeight(t.OverlaySubtitle) + 14 end
    local ruleY = y + 8
    y = ruleY + 32
    local bodyY = y
    if bodyH > 0 then y = y + bodyH + 26 end
    -- logo dos créditos (KayKit), entre o texto e os botões
    local logoY = y
    if self.overlayLogo.visible then y = y + LOGO_SIZE + 22 end
    local btnY = y
    if n > 0 then y = y + n * (OVERLAY_BUTTON_H + OVERLAY_BUTTON_GAP) - OVERLAY_BUTTON_GAP + 20 end
    local footY = y
    y = y + footerH + 28
    local cardH = y

    local maxH = canvasH - 2 * SCREEN_MARGIN
    if cardH > maxH and t.OverlayBody.fontSize > MIN_BODY_FONT and self.shrinkWait <= 0 then
        t.OverlayBody.fontSize = t.OverlayBody.fontSize - 1
        self:remeasureReveal(t.OverlayBody)
        self.shrinkWait = MEASURE_FRAMES + 1
    end

    local contentW = math.max(self.overlayBodyWidth or 600, OVERLAY_BUTTON_W, t.OverlayTitle.width + 170,
        hasSub and t.OverlaySubtitle.width or 0, t.OverlayFooter.width)
    local cardW = math.min(contentW + 2 * CARD_PAD_X, canvasW - 2 * SCREEN_MARGIN)
    local top = math.max(SCREEN_MARGIN, math.floor((canvasH - cardH) / 2))

    setSize(self.overlayCard, cardW, cardH)
    self:place(self.overlayCard, 0, top)
    self:place(t.OverlayTitle, 0, top + titleY)
    self:place(t.OverlaySubtitle, 0, top + subY)
    setSize(self.overlayRule, math.min(520, cardW - 2 * CARD_PAD_X), 6)
    self:place(self.overlayRule, 0, top + ruleY)
    self:place(self.overlaySkull, 0, top + ruleY - 19)
    local candleY = math.max(top + 24, top + titleY + titleH / 2 - 47)
    self:place(self.overlayCandles[1], -(cardW / 2 - 72), candleY)
    self:place(self.overlayCandles[2], cardW / 2 - 72, candleY)
    self:place(t.OverlayBody, 0, top + bodyY)
    if self.overlayLogo.visible then
        setSize(self.overlayLogo, LOGO_SIZE, LOGO_SIZE)
        self:place(self.overlayLogo, 0, top + logoY)
    end
    self.sliderRects = {}
    for i, name in ipairs(slots) do
        local by = top + btnY + (i - 1) * (OVERLAY_BUTTON_H + OVERLAY_BUTTON_GAP)
        self:place(self.button[name], 0, by)
        local sl = self.sliders[name]
        if self.sliderSpec[name] then
            -- texto encostado à esquerda (depois do ícone), deixando a direita para o trilho
            self:place(sl.label, -OVERLAY_BUTTON_W / 2 + SLIDER_LABEL_X + sl.label.width / 2, 0)
            sl.labelShifted = true
            local x0 = (canvasW - OVERLAY_BUTTON_W) / 2 + OVERLAY_BUTTON_W - SLIDER_RIGHT - SLIDER_TRACK_W
            self.sliderRects[name] = { x0 = x0, x1 = x0 + SLIDER_TRACK_W, y0 = by, y1 = by + OVERLAY_BUTTON_H }
        end
    end
    self:place(t.OverlayFooter, 0, top + footY)
end

----------------------------------------------------------------------
-- Sliders (volume e sensibilidade nas opções)
-- spec.slider = { name, min, max, keyStep, get = fn, set = fn(v), text = fn, icon = fn (opcional),
--                 commit = fn (opcional, chamado ao soltar o mouse ou depois das setas) }
----------------------------------------------------------------------
function HUDController:refreshSlider(name)
    local spec, sl = self.sliderSpec[name], self.sliders[name]
    if not spec or not sl then return end
    local range = spec.max - spec.min
    local frac = range > 0 and clamp((spec.get() - spec.min) / range, 0, 1) or 0
    self.button[name].label = string.format("%d   %s   %s", spec.index, spec.name, spec.text())
    local inner = SLIDER_TRACK_W - 2 * SLIDER_INNER_PAD
    local fillW = inner * frac
    setVisible(sl.fill, fillW >= 1)
    setSize(sl.fill, math.max(1, fillW), SLIDER_TRACK_H - 2 * SLIDER_INNER_PAD)
    self:place(sl.knob, SLIDER_INNER_PAD + fillW - SLIDER_KNOB_W / 2, -7)
    local c = (self.sliderFocus == name) and KNOB_COLOR_FOCUS or KNOB_COLOR
    sl.knob:setColor(c[1], c[2], c[3], 1)
    if spec.icon then self:setIcon(self.btnIcon[name], spec.icon()) end
end

function HUDController:focusSlider(name)
    local old = self.sliderFocus
    self.sliderFocus = name
    if old and old ~= name then self:refreshSlider(old) end
    self:refreshSlider(name)
end

-- Slider com foco (ou o primeiro da tela)
function HUDController:currentSlider()
    if self.sliderFocus and self.sliderSpec[self.sliderFocus] then return self.sliderFocus end
    for _, name in ipairs(self.keySlots.OverlayBtn or {}) do
        if self.sliderSpec[name] then return name end
    end
end

function HUDController:setSliderValue(name, v)
    local spec = self.sliderSpec[name]
    if not spec then return end
    spec.set(clamp(v, spec.min, spec.max))
    self:refreshSlider(name)
end

function HUDController:commitSlider(name)
    local spec = name and self.sliderSpec[name]
    if spec and spec.commit then spec.commit() end
end

-- Setas (ou A/D) mudam o slider com foco
function HUDController:nudgeSlider(dir)
    local name = self:currentSlider()
    if not name then return false end
    local spec = self.sliderSpec[name]
    if self.sliderFocus ~= name then self:focusSlider(name) end
    self:setSliderValue(name, spec.get() + dir * spec.keyStep)
    self:commitSlider(name)
    return true
end

-- Mouse: apertar sobre um trilho pega o slider; arrastar muda o valor; soltar guarda
function HUDController:updateSliderDrag()
    local down = self.overlayOpen and Input.isMousePressed(Input.MOUSE_BUTTON_LEFT)
    if down then
        local m = Input.getMousePosition()
        if not self.mouseWasDown then
            self.dragSlider = nil
            for name, r in pairs(self.sliderRects or {}) do
                if self.sliderSpec[name] and m.x >= r.x0 - SLIDER_GRAB_PAD and m.x <= r.x1 + SLIDER_GRAB_PAD
                    and m.y >= r.y0 and m.y <= r.y1 then
                    self.dragSlider = name
                    self:focusSlider(name)
                end
            end
        end
        local name = self.dragSlider
        local r = name and self.sliderRects[name]
        if r and self.sliderSpec[name] then
            local spec = self.sliderSpec[name]
            local inner = SLIDER_TRACK_W - 2 * SLIDER_INNER_PAD
            local frac = clamp((m.x - r.x0 - SLIDER_INNER_PAD) / inner, 0, 1)
            self:setSliderValue(name, spec.min + frac * (spec.max - spec.min))
        end
    elseif self.dragSlider then
        self:commitSlider(self.dragSlider)
        self.dragSlider = nil
    end
    self.mouseWasDown = down
end

-- Legenda: largura do texto (até TOAST_MAX_TEXT_W) + ícone + margens
function HUDController:layoutToast()
    local t = self.text.ToastText
    local x = self.toastTextX or TOAST_TEXT_X
    local w = x + t.width + 30
    local h = math.max(60, self:textHeight(t) + 2 * TOAST_TEXT_Y)
    setSize(self.toastBg, w, h)
end

-- Barra superior: noite, objetivo, fontes (ícones) e atalhos — só o espaço que o conteúdo pede
function HUDController:layoutTopBar()
    local t = self.text
    local x, y = 26, 18
    self:place(t.NightText, x, y)
    local w = t.NightText.width
    y = y + self:textHeight(t.NightText) + 6
    if t.ObjectiveText.text ~= "" then
        self:place(t.ObjectiveText, x, y)
        w = math.max(w, t.ObjectiveText.width)
        y = y + self:textHeight(t.ObjectiveText) + 10
    end
    if t.ProgressLabel.visible then
        self:place(t.ProgressLabel, x, y + 3)
        local ix = x + t.ProgressLabel.width + 10
        for _, icon in ipairs(self.progressIcons) do
            if icon.visible then
                self:place(icon, ix, y)
                ix = ix + 28
            end
        end
        w = math.max(w, ix - x)
        y = y + 30
    end
    if t.KeysText.visible then
        self:place(t.KeysText, x, y)
        w = math.max(w, t.KeysText.width)
        y = y + self:textHeight(t.KeysText) + 4
    end
    self:place(self.topBarBg, 10, 8)
    setSize(self.topBarBg, w + 2 * (x - 10), y + 12 - 8)
end

-- Mostra uma legenda agora (substitui a atual)
function HUDController:showSay(message, style)
    local st = SAY_STYLE[style] or SAY_STYLE.info
    local text = st.prefix .. message
    local toastText = self.text.ToastText
    fitTextWidth(toastText, text, toastText.fontSize, TOAST_MAX_TEXT_W)
    toastText.text = text
    applyColor(toastText, st.color)
    self.toastBg.visible = true
    for kind, icon in pairs(self.toastIcon) do
        icon.visible = (kind == st.icon)
    end
    self.toastTextX = st.icon and TOAST_TEXT_X_ICON or TOAST_TEXT_X
    self:place(toastText, self.toastTextX, TOAST_TEXT_Y)
    self:layoutToast()
    -- tempo de leitura proporcional ao tamanho do texto
    local len = (utf8 and utf8.len(message)) or #message
    self.toastTime = math.max(TOAST_SECONDS, 2.5 + len / 14)
end

-- Enfileira uma legenda: pensamentos e sussurros não atropelam uns aos outros
-- urgent: fala que precisa sair no momento (vulto, mortos): vai para a frente da fila
-- e encurta a legenda atual, em vez de esperar tudo o que já estava na fila
function HUDController:say(message, style, urgent)
    if not message or message == "" then return end
    if urgent then
        if self.toastTime > 0 or self.panelOpen or self.overlayOpen then
            table.insert(self.sayQueue, 1, { message, style })
            if self.toastTime > 0 then self.toastTime = math.min(self.toastTime, URGENT_CUT) end
        else
            self:showSay(message, style)
        end
        return
    end
    if self.toastTime > 0 or self.panelOpen or self.overlayOpen then
        table.insert(self.sayQueue, { message, style })
    else
        self:showSay(message, style)
    end
end

function HUDController:toast(message)
    self:say(message, "info")
end

function HUDController:hideToast()
    self.toastBg.visible = false
    self.toastTime = 0
end

----------------------------------------------------------------------
-- Barra superior
----------------------------------------------------------------------
function HUDController:refreshObjective()
    local t = self.text
    local shown = self.topBarShown
    local case = shown and Flow.currentCase() or nil
    local night = N.nights[Flow.state.night]
    t.NightText.text = string.format("Noite %d/%d — %s", Flow.state.night, N.nightCount, night and night.subtitle or "")

    local objective = case and case.objective or ""
    if case then
        if Flow.isChiseling(case) then
            objective = objective .. "\nCorreção decidida: mire na lápide e segure E para gravar."
        elseif Flow.isProven(case) then
            objective = objective .. "\nProvado. Falta corrigir o registro."
        end
        for _, other in ipairs(Flow.openCases()) do
            if other ~= case then
                objective = objective .. "\nTambém aberta: sepultura " .. N.graves[other.grave].number .. " — " .. other.title
            end
        end
    end
    fitTextWidth(t.ObjectiveText, objective, t.ObjectiveText.fontSize, OBJECTIVE_MAX_W)
    t.ObjectiveText.text = objective

    -- uma marca da spritesheet por fonte do caso: acesa quando já foi lida
    local sources = case and Flow.requiredSources(case) or {}
    for i, icon in ipairs(self.progressIcons) do
        local id = sources[i]
        if id then
            self:setIcon(icon, nil, Flow.isRead(id) and PROGRESS_ON or PROGRESS_OFF)
        else
            icon.visible = false
        end
    end
    t.ProgressLabel.visible = #sources > 0
    t.KeysText.text = KEY_HINTS
    t.KeysText.visible = shown and Flow.state.night == 1

    setVisible(t.NightText, shown)
    setVisible(t.ObjectiveText, shown and objective ~= "")
    setVisible(self.topBarBg, shown)
    if shown then self:layoutTopBar() end
end

function HUDController:onCasesOpened(list)
    self:refreshObjective()
    if #list == 1 then
        local case = list[1]
        self:say("Novo registro a conferir: sepultura " .. N.graves[case.grave].number .. " — " .. case.title .. ". Procure a luz fria.", "info")
    elseif #list > 1 then
        local parts = {}
        for _, c in ipairs(list) do
            parts[#parts + 1] = N.graves[c.grave].number .. " (" .. c.title .. ")"
        end
        self:say("Registros a conferir esta noite: sepulturas " .. table.concat(parts, " e ") .. ". Procure as luzes frias; a ordem é sua.", "info")
    end
end

----------------------------------------------------------------------
-- Balão de fala sobre a cabeça de quem fala (mortos, Benedito, escrivão)
----------------------------------------------------------------------
-- key = "guide" ou o id do caso; persistent = fica até a conversa mudar (falas do confronto)
function HUDController:speak(key, name, text, persistent)
    if not text or text == "" then return end
    local len = (utf8 and utf8.len(text)) or #text
    self.bubble = { key = key, timer = (not persistent) and math.max(3.5, 2.5 + len / 14) or nil }
    local t = self.text
    t.SpeechName.text = name or ""
    fitTextWidth(t.SpeechText, text, t.SpeechText.fontSize, BUBBLE_MAX_TEXT_W)
    t.SpeechText.text = text
end

function HUDController:clearBubble()
    self.bubble = nil
    self.bubbleBg.visible = false
end

function HUDController:updateBubble(dt)
    local b = self.bubble
    if not b then
        self.bubbleBg.visible = false
        return
    end
    if b.timer then
        b.timer = b.timer - dt
        if b.timer <= 0 then
            self:clearBubble()
            return
        end
    end
    -- some atrás de telas cheias e painéis grandes; na conversa (painel embaixo) continua
    local world = Flow.worldController
    if self.overlayOpen or (self.panelOpen and not self.panelCompact) or not world then
        self.bubbleBg.visible = false
        return
    end
    local t = self.text
    local textW = math.max(t.SpeechText.width, estimateWidth(t.SpeechName.text, t.SpeechName.fontSize))
    local w = textW + 2 * BUBBLE_PAD_X
    local h = BUBBLE_TEXT_Y + self:textHeight(t.SpeechText) + 20
    setSize(self.bubbleBg, w, h)

    local cw, ch = Engine.canvasWidth, Engine.canvasHeight
    local anchor = world:speakerAnchor(b.key)
    local sx, sy
    if anchor then sx, sy = world:projectToCanvas(anchor) end
    local x, y
    if sx and sx > -40 and sx < cw + 40 and sy > 0 and sy < ch then
        -- centralizado acima da cabeça; se não couber (cabeça no alto da tela), ao lado dela
        x, y = sx - w / 2, sy - h - 6
        if y < SCREEN_MARGIN then
            y = sy - 24
            x = sx + BUBBLE_SIDE_GAP
            if x + w > cw - SCREEN_MARGIN then x = sx - BUBBLE_SIDE_GAP - w end
        end
    else
        -- quem fala está fora de vista: o balão fica no alto, ao centro
        x, y = (cw - w) / 2, 110
    end
    x = clamp(x, SCREEN_MARGIN, cw - w - SCREEN_MARGIN)
    y = clamp(y, SCREEN_MARGIN, ch - h - SCREEN_MARGIN)
    self:place(self.bubbleBg, x, y)
    self.bubbleBg.visible = true
end

----------------------------------------------------------------------
-- Cinzel e resolução sem painel
----------------------------------------------------------------------
-- p = 0..1 enquanto o cinzel trabalha; nil esconde a barra
function HUDController:setChiselProgress(p)
    if not p then
        self.chiselBar.visible = false
        return
    end
    self.chiselBar.visible = true
    setSize(self.chiselFill, math.max(1, CHISEL_FILL_W * math.min(1, p)))
end

-- Registro gravado na pedra: a história é contada na legenda e o jogo segue
function HUDController:onResolved(case)
    self:setChiselProgress(nil)
    self:hideToast()   -- a instrução do cinzel dá lugar à história na hora
    self:say("Registro corrigido. " .. case.resolution, "info")
    local sp = Flow.spirit(case)
    if sp and sp.rest then self:speak(case.id, sp.name, sp.rest) end
    self:refreshObjective()
    self.notebookDirty = true
    if #Flow.openCases() > 0 then
        Flow.advance()
        self:refreshObjective()
    else
        -- último registro da noite: tempo para ler antes de a noite terminar
        local len = (utf8 and utf8.len(case.resolution)) or #case.resolution
        self.advanceTimer = math.min(ADVANCE_MAX_DELAY, 3 + len / 16)
    end
end

-- Encerra a espera pela próxima noite (também usado pelo autoteste)
function HUDController:flushAdvance()
    if not self.advanceTimer then return false end
    self.advanceTimer = nil
    Flow.advance()
    self:refreshObjective()
    return true
end

----------------------------------------------------------------------
-- Caderno (Tab): folha lateral que não pausa o jogo
----------------------------------------------------------------------
function HUDController:notebookBody()
    local lines = {}
    local open = Flow.openCases()
    for _, case in ipairs(open) do
        local number = N.graves[case.grave].number
        lines[#lines + 1] = "Sepultura " .. number .. " — " .. case.title
        if Flow.isChiseling(case) then
            lines[#lines + 1] = "   Correção decidida: segure E diante da lápide."
        elseif Flow.isProven(case) then
            lines[#lines + 1] = "   Provado. Falta escrever a correção."
        elseif not case.decision then
            local readCount, total = Flow.progress(case)
            lines[#lines + 1] = string.format("   Fontes lidas: %d de %d", readCount, total)
        end
        for _, c in ipairs(Flow.notedCaseClues(case)) do
            lines[#lines + 1] = "   • " .. c.text
        end
        for _, id in ipairs(case.evidence) do
            local place = Flow.placeOf(id)
            if place and not Flow.isRead(id) then
                lines[#lines + 1] = "   ? " .. N.evidence[id].title .. ": " .. N.places[place].where
            end
        end
        lines[#lines + 1] = ""
    end
    if #open == 0 then lines[#lines + 1] = "Nenhum registro aberto agora." end
    local resolved = 0
    for _, c in ipairs(N.cases) do if Flow.isResolved(c) then resolved = resolved + 1 end end
    lines[#lines + 1] = string.format("Registros corrigidos: %d de %d   ·   Tab fecha", resolved, #N.cases)
    return table.concat(lines, "\n")
end

function HUDController:setNotebookOpen(open)
    self.notebookOpen = open and true or false
    self.notebookDirty = true
end

function HUDController:updateNotebook()
    local show = self.notebookOpen and Flow.state.phase == "playing" and not self.panelOpen and not self.overlayOpen
    self.notebookBg.visible = show
    if not show then return end
    local t = self.text.NotebookText
    if self.notebookDirty then
        self.notebookDirty = false
        setTextWidth(t, NOTEBOOK_W - 52)
        t.text = self:notebookBody()
    end
    setSize(self.notebookBg, NOTEBOOK_W, math.max(120, 50 + self:textHeight(t) + 26))
end

function HUDController:onIdleHint()
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
        local case = Flow.caseForGrave(h.grave)
        if Flow.chiselCaseForGrave(h.grave) then
            label.text = "[Segure E] Gravar a correção na pedra " .. g.number
            label.visible = true
            return
        elseif case and Flow.isOpen(case) then
            caption = caption .. (Flow.isProven(case) and " — corrigir o registro" or " — caso aberto")
        end
    elseif h.kind == "book" then
        caption = "Ler o livro de registros"
    elseif h.kind == "paper" then
        caption = "Pegar " .. N.places[h.place].label
    elseif h.kind == "spirit" then
        local name = N.spirits[h.caseId].name
        local case = caseById(h.caseId)
        if Flow.isChiseling(case) then
            caption = name .. " espera o cinzel na pedra"
        elseif N.spirits[h.caseId].standing then
            caption = "Encarar " .. name
        else
            caption = (Flow.isProven(case) and "Corrigir o registro diante de " or "Confrontar ") .. name
        end
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

-- Fonte já lida mostra o visto; fonte nova mostra o "+"
local function readIcon(id)
    return Flow.isRead(id) and "check" or "plus"
end

function HUDController:onWorldClick(h)
    if h.kind == "grave" then
        self:openGrave(h.grave)
    elseif h.kind == "book" then
        self:openBook()
    elseif h.kind == "paper" then
        self:openPlace(h.place)
    elseif h.kind == "spirit" then
        local c = caseById(h.caseId)
        if c and Flow.isOpen(c) then
            Flow.setFocus(c)
            if Flow.isChiseling(c) then
                self:say("Mire na lápide " .. N.graves[c.grave].number .. " e segure E para gravar a correção.", "info")
            elseif Flow.isProven(c) then
                self:openFix(c)
            else
                self:openConfront(c)
            end
        end
    else
        self:toast(N.toasts.crypt)
    end
end

-- Botões "Anotar" para os detalhes de uma fonte (lápide ou documento)
function HUDController:clueButtons(sourceId, reopen)
    local buttons = {}
    for _, c in ipairs(Flow.cluesFor(sourceId)) do
        if Flow.hasClue(c.id) then
            buttons[#buttons + 1] = { label = "Anotado: " .. c.text, icon = "check", disabled = true }
        else
            buttons[#buttons + 1] = { label = "Anotar: " .. c.text, icon = "plus", action = function()
                Flow.noteClue(c.id)
                reopen()
            end }
        end
    end
    return buttons
end

-- Inscrição atual + as correções erradas que ficaram riscadas na pedra
local function graveText(g)
    local text = Flow.inscription(g)
    local scars = Flow.scars(g)
    if #scars > 0 then
        text = text .. "\n\nRiscado na pedra, pela sua mão: " .. table.concat(scars, " · ")
    end
    return text
end

-- Papel avulso pego no cemitério: lê direto (ou escolhe, se houver mais de um)
function HUDController:openPlace(place)
    local docs = Flow.docsAt(place)
    if #docs == 0 then return end
    if #docs == 1 then
        self:openEvidence(docs[1], nil)
        return
    end
    local buttons = {}
    for _, id in ipairs(docs) do
        buttons[#buttons + 1] = { label = "Ler: " .. N.evidence[id].title .. readMark(id), icon = readIcon(id),
            action = function() self:openEvidence(id, function() self:openPlace(place) end) end }
    end
    buttons[#buttons + 1] = { label = "Fechar", icon = "x", action = function() self:closePanel() end }
    self:showPanel({
        title = "Papéis",
        subtitle = N.places[place].where,
        icon = "candle",
        body = "Há mais de um papel aqui.",
        buttons = buttons,
    })
end

function HUDController:openGrave(g)
    local grave = N.graves[g]
    local case = Flow.caseForGrave(g)
    local isOpen = case and Flow.isOpen(case)

    if not isOpen then
        local note
        if case and Flow.isResolved(case) then
            note = N.toasts.resolvedGrave .. "\n" .. case.summary
        elseif Flow.isLocked(case) then
            note = N.toasts.lockedGrave
        else
            note = N.toasts.notCaseGrave
        end
        self:showPanel({
            title = "Sepultura " .. grave.number,
            subtitle = "Inscrição da lápide",
            icon = "tomb",
            body = graveText(g) .. "\n\n" .. note,
            buttons = { { label = "Fechar", icon = "x", action = function() self:closePanel() end } },
        })
        return
    end

    Flow.setFocus(case)
    local graveId = Flow.graveEvidenceId(g)
    Flow.markRead(graveId)
    local back = function() self:openGrave(g) end
    local buttons = self:clueButtons(graveId, back)
    for _, id in ipairs(case.evidence) do
        local ev = N.evidence[id]
        if ev.place and not Flow.isRead(id) then
            -- o papel não está aqui: só dá para reler depois de achá-lo pelo cemitério
            buttons[#buttons + 1] = { label = "Procurar: " .. ev.title .. " — " .. N.places[ev.place].label,
                icon = "minus", disabled = true }
        else
            local label
            if ev.kind == "book" then
                label = "Consultar o livro de registros" .. readMark(id)
            elseif ev.place then
                label = "Reler: " .. ev.title .. readMark(id)
            else
                label = "Ler: " .. ev.title .. readMark(id)
            end
            buttons[#buttons + 1] = { label = label, icon = readIcon(id), action = function() self:openEvidence(id, back) end }
        end
    end
    if Flow.isChiseling(case) then
        buttons[#buttons + 1] = { label = "Feche e segure E diante da pedra para gravar", icon = "check", disabled = true }
    elseif Flow.isProven(case) then
        buttons[#buttons + 1] = { label = "Corrigir o registro", icon = "check", action = function() self:openFix(case) end }
    elseif case.decision then
        local readCount, total = Flow.progress(case)
        local can = Flow.canConfront(case)
        local label = "Decidir o destino do livro"
        if not can then label = label .. string.format("  (%d/%d fontes lidas)", readCount, total) end
        buttons[#buttons + 1] = { label = label, icon = can and "question" or "minus", disabled = not can, action = function() self:openConfront(case) end }
    else
        local spirit = Flow.spirit(case)
        local label = spirit and ("Confrontar " .. spirit.name) or "Confrontar registros"
        buttons[#buttons + 1] = { label = label, icon = "question", action = function() self:openConfront(case) end }
    end

    local body = graveText(g) .. "\n\n" .. case.objective
    local thought = N.caseThoughts[case.id]
    if thought then body = body .. "\n\n— Severino pensa: \"" .. thought .. "\"" end
    self:showPanel({
        title = "Sepultura " .. grave.number .. " — " .. case.title,
        subtitle = "Inscrição da lápide",
        icon = "tomb",
        body = body,
        buttons = buttons,
    })
end

function HUDController:openEvidence(id, back)
    local firstTime = Flow.markRead(id)
    local ev = N.evidence[id]
    local body = Flow.evidenceBody(id)
    local thought = N.thoughts[id]
    if thought then
        body = body .. "\n\n— Severino pensa: \"" .. thought .. "\""
    end
    local buttons = self:clueButtons(id, function() self:openEvidence(id, back) end)
    if back then
        buttons[#buttons + 1] = { label = "Voltar", icon = "home", action = back }
    else
        buttons[#buttons + 1] = { label = "Guardar o papel", icon = "x", action = function() self:closePanel() end }
    end
    self:showPanel({
        title = ev.title,
        subtitle = ev.subtitle or KIND_LABEL[ev.kind] or "",
        body = body,
        paper = ev.kind,
        reveal = firstTime,
        buttons = buttons,
    })
end

function HUDController:openBook()
    if Flow.state.phase ~= "playing" then return end
    local open = Flow.openCases()
    local buttons = {}
    local lines = {}
    if #open == 0 then
        lines[1] = "Nenhum caso aberto."
    else
        lines[1] = "Registros abertos esta noite:"
    end
    local backToBook = function() self:openBook() end
    for _, case in ipairs(open) do
        local readCount, total = Flow.progress(case)
        local noted = #Flow.notedCaseClues(case)
        local state = Flow.isProven(case) and "provado, falta corrigir"
            or string.format("%d de %d fontes lidas, %d anotações", readCount, total, noted)
        lines[#lines + 1] = "• Sepultura " .. N.graves[case.grave].number .. " — " .. case.title .. ": " .. state
        for _, id in ipairs(case.evidence) do
            if id:sub(1, 5) == "book:" then
                buttons[#buttons + 1] = {
                    label = "Ler o registro nº " .. N.graves[case.grave].number .. readMark(id), icon = readIcon(id),
                    action = function() self:openEvidence(id, backToBook) end,
                }
            end
        end
    end
    for _, case in ipairs(open) do
        buttons[#buttons + 1] = {
            label = "Ir para a sepultura " .. N.graves[case.grave].number, icon = "play",
            action = function() self:openGrave(case.grave) end,
        }
    end
    buttons[#buttons + 1] = {
        label = string.format("Caderno do coveiro (%d)", #Flow.state.clueOrder + #Flow.state.notes), icon = "candle",
        action = function() self:openNotes() end,
    }
    if Flow.state.flags.night1_event then
        buttons[#buttons + 1] = {
            label = "Página rasgada" .. readMark("pagina_rasgada"), icon = readIcon("pagina_rasgada"),
            action = function() self:openEvidence("pagina_rasgada", backToBook) end,
        }
    end
    while #buttons > PANEL_SLOTS do table.remove(buttons) end
    self:showPanel({
        title = "Livro de registros",
        subtitle = N.town .. " — 1845",
        icon = "candle",
        body = table.concat(lines, "\n"),
        buttons = buttons,
    })
end

-- Caderno: anotações dos casos abertos + histórico das descobertas
function HUDController:openNotes()
    local lines = {}
    for _, case in ipairs(Flow.openCases()) do
        if not case.decision then
            lines[#lines + 1] = "Sepultura " .. N.graves[case.grave].number .. " — " .. case.title
            local noted = Flow.notedCaseClues(case)
            if #noted == 0 then
                lines[#lines + 1] = "   (nada anotado ainda)"
            end
            for _, c in ipairs(noted) do lines[#lines + 1] = "   • " .. c.text end
            lines[#lines + 1] = ""
        end
    end
    local notes = Flow.state.notes
    if #notes > 0 then
        lines[#lines + 1] = "Descobertas:"
        for _, n in ipairs(notes) do lines[#lines + 1] = "• " .. n end
    elseif #lines == 0 then
        lines[1] = "Nenhuma anotação ainda. Os detalhes que você anotar nos documentos e cada registro corrigido ficarão aqui."
    end
    local buttons = { { label = "Voltar ao livro", icon = "home", action = function() self:openBook() end } }
    if Flow.isRead("testemunho_vigario") then
        table.insert(buttons, 1, {
            label = "Reler o testemunho do Padre Inácio", icon = "check",
            action = function() self:openEvidence("testemunho_vigario", function() self:openNotes() end) end,
        })
    end
    buttons[#buttons + 1] = { label = "Fechar", icon = "x", action = function() self:closePanel() end }
    self:showPanel({
        title = "Caderno do coveiro",
        icon = "candle",
        subtitle = "Anotações e descobertas",
        body = table.concat(lines, "\n"),
        small = true,
        buttons = buttons,
    })
end

-- Na conversa, o que o morto diz vai para o balão sobre a cabeça dele;
-- o painel de baixo fica só com as escolhas do coveiro.
function HUDController:spiritSays(case, line)
    local spirit = Flow.spirit(case)
    if self.talking == case and spirit and line then
        self:speak(case.id, spirit.name, line, true)
        return true
    end
    return false
end

local function talkSubtitle(case)
    local spirit = Flow.spirit(case)
    return "Diante de " .. (spirit and spirit.name or case.title) .. " — sepultura " .. N.graves[case.grave].number
end

-- Passo 1 do confronto: escolher a conclusão
function HUDController:openConfront(case)
    case = case or Flow.currentCase()
    if not case then return end
    local talking = self:beginTalk(case)
    local spirit = Flow.spirit(case)
    -- a decisão final só é tomada depois de ler tudo
    if case.decision and not Flow.canConfront(case) then
        local readCount, total = Flow.progress(case)
        local body = Flow.hintText()
        if talking then
            self:spiritSays(case, spirit.notReady)
            body = "Leia a última página do livro e a ordem da Câmara, na cripta, antes de responder."
        end
        self:showPanel({
            title = talking and "Sua resposta" or "A última página",
            subtitle = string.format("Fontes lidas: %d de %d", readCount, total),
            icon = "skull",
            body = body,
            talk = true,
            buttons = { { label = "Voltar à sepultura", icon = "home", action = function() self:openGrave(case.grave) end } },
        })
        return
    end
    local buttons = {}
    for i, h in ipairs(case.hypotheses) do
        buttons[#buttons + 1] = { label = h.text, action = function()
            if case.decision then self:decide(case, i) else self:openPresent(case, i) end
        end }
    end
    local body
    if talking then
        self:spiritSays(case, spirit.ask)
        body = case.question
    elseif case.decision then
        body = case.question
    else
        body = case.question .. "\n\nEscolha a conclusão. Em seguida, apresente a anotação do caderno que a prova."
    end
    if not case.decision then
        buttons[#buttons + 1] = { label = "Voltar à sepultura", icon = "home", action = function() self:openGrave(case.grave) end }
    end
    self:showPanel({
        title = talking and "Sua resposta" or (case.decision and "A última página" or ("Confrontar registros — sepultura " .. N.graves[case.grave].number)),
        subtitle = talking and talkSubtitle(case) or case.title,
        icon = "skull",
        body = body,
        talk = true,
        buttons = buttons,
    })
end

-- Passo 2: apresentar a anotação que sustenta a conclusão
function HUDController:openPresent(case, hypIndex)
    local h = case.hypotheses[hypIndex]
    local noted = Flow.notedCaseClues(case)
    local buttons = {}
    local body
    if #noted == 0 then
        self:spiritSays(case, "\"Você não anotou nada sobre mim. Volte quando tiver provas.\"")
        body = "\"" .. h.text .. "\"\n\nSeu caderno ainda não tem nada sobre este caso. Leia a lápide e os documentos e anote os detalhes que importam."
    else
        self:spiritSays(case, "\"E com o que você prova isso, coveiro?\"")
        body = "\"" .. h.text .. "\"\nQual anotação do caderno prova isso?"
        for i = 1, math.min(#noted, PANEL_SLOTS - 1) do
            local c = noted[i]
            buttons[#buttons + 1] = { label = c.text, icon = "candle", action = function() self:present(case, hypIndex, c.id) end }
        end
    end
    buttons[#buttons + 1] = { label = "Voltar às conclusões", icon = "home", action = function() self:openConfront(case) end }
    self:showPanel({
        title = self.talking == case and "Sua prova" or "Apresentar a prova",
        subtitle = self.talking == case and talkSubtitle(case) or ("Sepultura " .. N.graves[case.grave].number .. " — " .. case.title),
        icon = "skull",
        body = body,
        talk = true,
        buttons = buttons,
    })
end

function HUDController:present(case, hypIndex, clueId)
    local result = Flow.present(case, hypIndex, clueId)
    if not result then return end
    local review = { label = "Rever os documentos", icon = "home", action = function() self:openGrave(case.grave) end }
    local fog = "A névoa sobre o cemitério fica um pouco mais densa."
    -- na conversa, a resposta vem da boca do morto
    local said = (result.kind == "wrong" or result.kind == "weak") and self:spiritSays(case, result.text)
    if result.kind == "wrong" then
        self:showPanel({
            title = "As provas não sustentam isso",
            icon = "wrong",
            subtitle = "O registro continua aberto",
            body = said and fog or (result.text .. "\n\n" .. fog),
            talk = true,
            buttons = {
                { label = "Tentar outra conclusão", icon = "question", action = function() self:openConfront(case) end },
                review,
            },
        })
    elseif result.kind == "weak" then
        self:showPanel({
            title = "Essa anotação não prova isso",
            icon = "wrong",
            subtitle = "A conclusão pode estar certa, mas falta a prova",
            body = said and fog or (result.text .. "\n\n" .. fog),
            talk = true,
            buttons = {
                { label = "Apresentar outra anotação", icon = "candle", action = function() self:openPresent(case, hypIndex) end },
                review,
            },
        })
    elseif result.kind == "proven" then
        self:refreshObjective()
        self:openFix(case, true)
    end
end

-- Passo 3: o jogador escreve a correção
function HUDController:openFix(case, justProven)
    self:beginTalk(case)
    local fix = case.fix
    if not fix then
        self:applyFix(case, nil)
        return
    end
    local buttons = {}
    for i, opt in ipairs(fix.options) do
        buttons[#buttons + 1] = { label = opt, icon = "plus", action = function() self:applyFix(case, i) end }
    end
    buttons[#buttons + 1] = { label = "Voltar à sepultura", icon = "home", action = function() self:openGrave(case.grave) end }
    local said = self:spiritSays(case, justProven and "\"...é isso. Agora escreva, com a sua mão.\"" or "\"Escreva, coveiro.\"")
    local intro
    if said then
        intro = "Complete a inscrição:"
    else
        intro = justProven and "As provas sustentam a sua conclusão. Agora corrija com a sua própria mão:" or "Complete a correção:"
    end
    self:showPanel({
        title = fix.title,
        subtitle = said and talkSubtitle(case) or ("Sepultura " .. N.graves[case.grave].number .. " — " .. case.title),
        icon = "tomb",
        body = intro .. "\n\n" .. fix.prompt,
        talk = true,
        buttons = buttons,
    })
end

function HUDController:applyFix(case, optionIndex)
    local result = Flow.fix(case, optionIndex)
    if not result then return end
    if result.kind == "fixWrong" then
        local said = self:spiritSays(case, result.text)
        self:showPanel({
            title = "A mão hesita",
            icon = "wrong",
            subtitle = case.fix.title,
            body = said and "A pedra recusa o que você ia escrever. Escolha de novo." or result.text,
            talk = true,
            buttons = { { label = "Escrever de novo", icon = "question", action = function() self:openFix(case) end } },
        })
        return
    end
    -- correção decidida: agora o coveiro grava com as próprias mãos (segurar E diante da pedra)
    self:closePanel()
    self:refreshObjective()
    self:say("Mire na lápide " .. N.graves[case.grave].number .. " e segure E para gravar: " .. (case.fix and case.fix.options[case.fix.correct] or "a correção") .. ".", "info")
end

function HUDController:decide(case, index)
    local result = Flow.decide(case, index)
    if not result then return end
    if result.kind == "back" then
        self:openGrave(case.grave)
    elseif result.kind == "ending" then
        -- antes do epílogo, Benedito aparece diante do coveiro para se despedir
        self:closePanel()
        self:setTopBarVisible(false)
        self.pendingEnding = result.ending
        self.endingDelay = ENDING_DELAY
        Flow.emit("finale", result.ending)
    end
end

-- Mostra o epílogo que esperava a despedida (também usado pelo autoteste)
function HUDController:flushEnding()
    if not self.pendingEnding then return false end
    local kind = self.pendingEnding
    self.pendingEnding, self.endingDelay = nil, nil
    self:showEnding(kind, 1)
    return true
end

function HUDController:openHelp()
    Flow.state.idle = 0
    self:showPanel({
        title = "Ajuda",
        icon = "help",
        subtitle = "Pedir uma pista não tem penalidade",
        body = Flow.hintText() .. "\n\n" .. N.controls,
        small = true,
        buttons = { { label = "Fechar", icon = "x", action = function() self:closePanel() end } },
    })
end

----------------------------------------------------------------------
-- Telas cheias: menu, pausa, noites, finais, créditos
----------------------------------------------------------------------
function HUDController:showMainMenu()
    Saves.current = nil
    local buttons = {}
    -- atalho para a campanha em andamento salva por último
    local latest = Saves.latest()
    if latest then
        local info = Saves.info(latest)
        buttons[#buttons + 1] = { label = string.format("Continuar (espaço %d, noite %d)", latest, info.night), icon = "play",
            action = function() self:continueSlot(latest) end }
    end
    buttons[#buttons + 1] = { label = latest and "Escolher save" or "Jogar", icon = latest and "tomb" or "play",
        action = function() self:showSlots(false) end }
    for _, b in ipairs({
            { label = "Opções", icon = "gear", action = function() self:showOptions(function() self:showMainMenu() end) end },
            { label = "Créditos", icon = "candle", action = function() self:showInfo("Créditos", N.credits, function() self:showMainMenu() end, true) end },
        }) do
        buttons[#buttons + 1] = b
    end
    self:showOverlay({
        mode = "menu",
        title = N.menu.title,
        subtitle = N.menu.subtitle,
        body = N.menu.body,
        footer = FOOTER_DEFAULT .. "   ·   Doriax Flash Jam 2026",
        buttons = buttons,
    })
end

-- Texto de um espaço de save na lista
local function slotLabel(n, info)
    if not info then return string.format("Espaço %d — vazio (novo jogo)", n) end
    if info.ending then
        local ending = N.endings[info.ending]
        return string.format("Espaço %d — concluído (%s)", n, ending and ending.title or "fim")
    end
    return string.format("Espaço %d — noite %d · %d de %d registros", n, info.night, info.resolved, info.total)
end

function HUDController:continueSlot(n)
    self:closeOverlay()
    if not Saves.load(n) then
        self:showInfo("Save ilegível", "Não foi possível abrir o espaço " .. n .. ". Ele pode ter sido salvo por outra versão do jogo.",
            function() self:showSlots(false) end)
    end
end

-- Escolha do espaço: vazio começa um jogo novo; ocupado continua; concluído recomeça.
-- deleting = true: clicar num espaço pergunta se deve apagá-lo
function HUDController:showSlots(deleting)
    local buttons = {}
    local any = false
    for n = 1, Saves.SLOTS do
        local info = Saves.info(n)
        any = any or info ~= nil
        local label = slotLabel(n, info)
        local action
        if deleting then
            if info then
                label = "Apagar: " .. label
                action = function()
                    self:confirm("Apagar o espaço " .. n .. "?", "Esta campanha será apagada para sempre.", "Sim, apagar",
                        function() Saves.delete(n); self:showSlots(false) end,
                        function() self:showSlots(true) end)
                end
            end
        elseif not info then
            action = function() Saves.startNew(n); self:showPrologue(1) end
        elseif info.ending then
            action = function()
                self:confirm("Recomeçar no espaço " .. n .. "?", "Esta campanha já terminou. Um jogo novo começa neste espaço, no lugar dela.",
                    "Sim, recomeçar", function() Saves.startNew(n); self:showPrologue(1) end,
                    function() self:showSlots(false) end)
            end
        else
            action = function() self:continueSlot(n) end
        end
        buttons[#buttons + 1] = { label = label, icon = info and (info.ending and "check" or "tomb") or "plus",
            disabled = action == nil, action = action }
    end
    if deleting then
        buttons[#buttons + 1] = { label = "Cancelar", icon = "x", action = function() self:showSlots(false) end }
    elseif any then
        buttons[#buttons + 1] = { label = "Apagar um save", icon = "minus", action = function() self:showSlots(true) end }
    end
    buttons[#buttons + 1] = { label = "Voltar", icon = "home", action = function() self:showMainMenu() end }
    self:showOverlay({
        mode = "slots",
        title = deleting and "Apagar um save" or "Saves",
        subtitle = deleting and "Escolha o espaço que será apagado" or "Até três campanhas",
        body = deleting and "Apagar não pode ser desfeito."
            or "O jogo salva sozinho a cada pista, documento e registro corrigido, e no começo de cada noite.\n"
            .. "Ao continuar, você volta à noite em que parou, com tudo o que já descobriu.",
        back = function() if deleting then self:showSlots(false) else self:showMainMenu() end end,
        buttons = buttons,
    })
end

-- Prólogo em cartões; o último começa a campanha
function HUDController:showPrologue(page)
    local card = N.prologue[page]
    if not card then
        self:closeOverlay()
        Flow.startGame()
        return
    end
    local isLast = page >= #N.prologue
    self:showOverlay({
        mode = "prologue",
        title = card.title,
        subtitle = card.subtitle,
        body = card.body,
        reveal = true,
        footer = string.format("Prólogo %d de %d   ·   Enter ou 1: continuar   ·   Espaço: mostrar o texto todo", page, #N.prologue),
        back = function() self:showMainMenu() end,
        buttons = {
            { label = isLast and "Entrar no cemitério" or "Continuar", icon = "play", action = function() self:showPrologue(page + 1) end },
            { label = "Pular o prólogo", icon = "minus", action = function() self:showPrologue(#N.prologue + 1) end },
        },
    })
end

function HUDController:showInfo(title, body, back, logo)
    self:showOverlay({
        mode = "info",
        title = title,
        subtitle = "",
        body = body,
        back = back,
        logo = logo,
        buttons = { { label = "Voltar", icon = "home", action = back } },
    })
end

-- Opções: uma tela com as seções; cada seção alterna valores e se redesenha com o novo estado.
-- Tudo é guardado na hora (Settings.save) e volta na próxima vez que o jogo abrir.
local function yesNo(v) return v and "Sim" or "Não" end

function HUDController:showOptions(back)
    local here = function() self:showOptions(back) end
    local S = Settings
    self:showOverlay({
        mode = "options",
        title = "Opções",
        subtitle = "Salvas automaticamente",
        body = string.format(
            "Som: geral %s   ·   ambiente %s   ·   efeitos %s\n"
            .. "Mouse: sensibilidade %s de 10   ·   eixo vertical %s\n"
            .. "Texto: %s   ·   %s",
            S.volumeLabel("master"), S.volumeLabel("ambient"), S.volumeLabel("effects"),
            S.sensitivityLabel(), S.invertY and "invertido" or "normal",
            S.largeText and "grande" or "normal", S.animateText and "animado" or "instantâneo"),
        back = back,
        buttons = {
            { label = "Áudio", icon = "play", action = function() self:showOptionsAudio(here) end },
            { label = "Controles", icon = "question", action = function() self:showOptionsControls(here) end },
            { label = "Texto e leitura", icon = "candle", action = function() self:showOptionsText(here) end },
            { label = "Restaurar padrões", icon = "minus", disabled = S.isDefault(), action = function()
                self:confirm("Restaurar os padrões?", "Volume, mouse e texto voltam aos valores iniciais. Seus saves não são afetados.",
                    "Sim, restaurar", function() S.resetDefaults(); self:applyTextSize(); here() end, here)
            end },
            { label = "Voltar", icon = "home", action = back },
        },
    })
end

-- Linha de volume com slider (0–100%, setas de 5 em 5)
local function volumeSlider(kind, name)
    return {
        label = name, icon = Settings.volume(kind) > 0 and "speaker" or "mute",
        slider = {
            name = name, min = 0, max = 100, keyStep = 5,
            get = function() return Settings.volumePct[kind] end,
            set = function(v) Settings.setVolume(kind, v) end,
            text = function() return Settings.volumeLabel(kind) end,
            icon = function() return Settings.volume(kind) > 0 and "speaker" or "mute" end,
            commit = Settings.save,
        },
    }
end

function HUDController:showOptionsAudio(back)
    self:showOverlay({
        mode = "options",
        title = "Áudio",
        subtitle = "Os sons mudam na hora",
        body = "Geral: todos os sons do jogo.\n"
            .. "Ambiente: o vento e as rajadas sobre o cemitério.\n"
            .. "Efeitos: passos, portões, rangidos, os mortos e os sussurros.",
        back = back,
        buttons = {
            volumeSlider("master", "Geral"),
            volumeSlider("ambient", "Ambiente"),
            volumeSlider("effects", "Efeitos"),
            { label = "Voltar", icon = "home", action = back },
        },
    })
end

function HUDController:showOptionsControls(back)
    local refresh = function() self:showOptionsControls(back) end
    self:showOverlay({
        mode = "options",
        title = "Controles",
        subtitle = "Mouse e teclado",
        body = "Sensibilidade: quanto a câmera gira ao mover o mouse (1 a 10).\n"
            .. "Inverter eixo vertical: mover o mouse para cima olha para baixo.\n"
            .. "Durante o jogo, H abre a ajuda com estes atalhos e uma pista.",
        back = back,
        buttons = {
            { label = "Sensibilidade", icon = "gear", slider = {
                name = "Sensibilidade", min = Settings.SENSITIVITY_MIN, max = Settings.SENSITIVITY_MAX, keyStep = 1,
                get = function() return Settings.sensitivityLevel end,
                set = function(v) Settings.setSensitivity(v) end,
                text = Settings.sensitivityLabel,
                commit = Settings.save,
            } },
            { label = "Inverter eixo vertical: " .. yesNo(Settings.invertY), icon = Settings.invertY and "check" or "x", action = function()
                Settings.toggleInvertY(); Settings.save(); refresh()
            end },
            { label = "Ver atalhos do teclado", icon = "question", action = function()
                self:showInfo("Atalhos do teclado", N.controls, refresh)
            end },
            { label = "Voltar", icon = "home", action = back },
        },
    })
end

function HUDController:showOptionsText(back)
    local refresh = function() self:showOptionsText(back) end
    self:showOverlay({
        mode = "options",
        title = "Texto e leitura",
        subtitle = "Documentos, cartas e avisos",
        body = "Texto grande: aumenta os textos dos painéis, documentos e avisos.\n"
            .. "Texto animado: documentos e cenas se escrevem aos poucos. Espaço mostra o texto todo de uma vez.",
        back = back,
        buttons = {
            { label = "Texto grande: " .. yesNo(Settings.largeText), icon = Settings.largeText and "check" or "x", action = function()
                Settings.toggleLargeText(); Settings.save(); self:applyTextSize(); refresh()
            end },
            { label = "Texto animado: " .. yesNo(Settings.animateText), icon = Settings.animateText and "check" or "x", action = function()
                Settings.toggleAnimateText(); Settings.save(); refresh()
            end },
            { label = "Voltar", icon = "home", action = back },
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
            { label = "Não, voltar", icon = "x", action = onNo },
            { label = yesLabel, icon = "check", action = onYes },
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
        lines[#lines + 1] = string.format("Fontes consultadas neste caso: %d de %d   ·   Anotações: %d", readCount, total, #Flow.notedCaseClues(case))
    end
    lines[#lines + 1] = string.format("Registros desta noite: %d de %d   ·   Campanha: %d de %d", nightDone, nightTotal, resolvedCount, #N.cases)
    if s.mistakes > 0 then
        lines[#lines + 1] = string.format("Conclusões erradas até agora: %d", s.mistakes)
    end
    return table.concat(lines, "\n")
end

function HUDController:openPause(savedNow)
    if Flow.state.phase ~= "playing" then return end
    local night = N.nights[Flow.state.night]
    local resume = function() self:closeOverlay() end
    local slot = Saves.current
    local body = self:pauseSummary()
    if slot then
        body = body .. "\n" .. (savedNow and ("Jogo salvo no espaço " .. slot .. ".")
            or ("O jogo salva sozinho no espaço " .. slot .. "."))
    end
    self:showOverlay({
        mode = "pause",
        title = "Pausa",
        subtitle = string.format("Noite %d de %d — %s", Flow.state.night, N.nightCount, night and night.subtitle or ""),
        body = body,
        back = resume,
        footer = "1–4 ou clique para escolher   ·   Esc: continuar",
        buttons = {
            { label = "Continuar", icon = "play", action = resume },
            { label = savedNow and "Jogo salvo" or "Salvar jogo", icon = savedNow and "check" or "tomb", disabled = not slot,
              action = function() Saves.save(); self:openPause(true) end },
            { label = "Opções", icon = "gear", action = function() self:showOptions(function() self:openPause() end) end },
            { label = "Voltar ao menu principal", icon = "home", action = function()
                self:confirm("Voltar ao menu principal?",
                    slot and ("O jogo será salvo no espaço " .. slot .. ". Ao continuar, você volta a esta noite, no mesmo lugar, com tudo o que já descobriu.")
                        or "O progresso desta campanha será perdido.",
                    "Sim, voltar ao menu",
                    function() Saves.save(); Flow.reset(); self:showMainMenu() end,
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
        reveal = true,
        title = night.title,
        subtitle = string.format("%s   ·   noite %d de %d", night.subtitle, n, N.nightCount),
        body = body,
        footer = "Enter ou 1: começar",
        buttons = { { label = "Começar a noite", icon = "play", action = function()
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
    if isLast and Flow.state.mistakes >= 5 then
        body = body .. N.endings.mistakesNote
    end
    self:showOverlay({
        mode = "ending",
        reveal = true,
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
        logo = true,
        buttons = {
            { label = "Jogar novamente", icon = "play", action = function()
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
    -- setas (ou A/D) ajustam o slider com foco; segurar a tecla repete
    if self.overlayOpen and not self.panelOpen then
        local dir = (key == Input.KEY_LEFT or key == Input.KEY_A) and -1
            or ((key == Input.KEY_RIGHT or key == Input.KEY_D) and 1) or nil
        if dir and self:nudgeSlider(dir) then return end
    end
    if isRepeat then return end

    -- Espaço completa o texto que está se escrevendo
    if key == Input.KEY_SPACE then
        self:finishReveal()
        return
    end

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
    -- Tab: caderno lateral, sem pausar
    if key == Input.KEY_TAB and Flow.state.phase == "playing" and not self.overlayOpen then
        if self.panelOpen then self:closePanel() end
        self:setNotebookOpen(not self.notebookOpen)
        return
    end
    -- E fecha o painel aberto e devolve o controle (documentos, sepultura, conversa)
    if key == Input.KEY_E and self.panelOpen and not self.overlayOpen and self.panelFrame ~= self.frame then
        self:closePanel()
        return
    end
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
    if (self.demo or self.demoGuide or self.demoFinale) and not self.demoSteps then
        self.demoFrames = (self.demoFrames or 0) + 1
        if self.demoFrames > 60 then
            local SelfTest = require("game.selftest")
            if self.demoFinale then
                self.demoSteps = SelfTest.demoFinaleSteps(self)
            elseif self.demoGuide then
                self.demoSteps = SelfTest.demoGuideSteps(self)
            else
                self.demoSteps = SelfTest.demoSteps(self)
            end
            self.demoIndex, self.demoWait = 1, self.demoSteps[1][1]
        end
    end
    if self.demoSteps and self.demoIndex <= #self.demoSteps then
        self.demoWait = self.demoWait - dt
        if self.demoWait <= 0 then
            local ok, err = pcall(self.demoSteps[self.demoIndex][2])
            Log.print("DEMO step " .. self.demoIndex .. (ok and "" or (" FAILED: " .. tostring(err))))
            self.demoIndex = self.demoIndex + 1
            local nextStep = self.demoSteps[self.demoIndex]
            self.demoWait = nextStep and nextStep[1] or 0
        end
    end
    self.frame = self.frame + 1
    if self.endingDelay then
        self.endingDelay = self.endingDelay - dt
        if self.endingDelay <= 0 then self:flushEnding() end
    end
    if self.advanceTimer and Flow.state.phase == "playing" and not self.panelOpen and not self.overlayOpen then
        self.advanceTimer = self.advanceTimer - dt
        if self.advanceTimer <= 0 then self:flushAdvance() end
    end
    Flow.tick(dt)
    self:updateReveal(dt)
    self:updateNotebook()
    self:updateBubble(dt)
    self:updateSliderDrag()

    -- O motor mede os textos depois que eles mudam: refaz a diagramação com as medidas atuais
    if self.shrinkWait > 0 then self.shrinkWait = self.shrinkWait - 1 end
    if self.overlayOpen then self:layoutOverlay() end
    if self.panelOpen then self:layoutPanel() end
    if self.toastBg.visible then self:layoutToast() end
    if self.topBarShown then self:layoutTopBar() end
    if self.toastTime > 0 then
        self.toastTime = self.toastTime - dt
        if self.toastTime <= 0 then self:hideToast() end
    elseif #self.sayQueue > 0 and not self.panelOpen and not self.overlayOpen then
        local nextSay = table.remove(self.sayQueue, 1)
        self:showSay(nextSay[1], nextSay[2])
    end
end

return HUDController
