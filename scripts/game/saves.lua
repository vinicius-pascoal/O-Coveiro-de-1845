-- Saves: até 3 campanhas guardadas (UserSettings do motor, que persiste entre sessões).
-- O estado do Flow é escrito como uma tabela Lua e codificado em hexadecimal, para que
-- acentos e quebras de linha das anotações passem intactos pelo arquivo de configurações.
-- O salvamento é automático (pistas, documentos, casos, noites) e também pode ser pedido na pausa.

local Flow = require("game.flow")

local Saves = {}

Saves.SLOTS = 3
Saves.prefix = "coveiro1845_save_"   -- o autoteste troca por um prefixo próprio
Saves.current = nil                  -- espaço da campanha em andamento
Saves.VERSION = 1

-- Campos do Flow.state que atravessam o save (o resto é estado de tela)
local FIELDS = {
    "night", "focus", "announced", "caseSeen", "clues", "clueOrder", "proven", "read", "resolved",
    "mistakes", "flags", "ending", "notes", "whispersSeen", "inscriptions", "scars", "awakened", "chisel",
}

----------------------------------------------------------------------
-- Codificação
----------------------------------------------------------------------
local function encodeValue(v, out)
    local t = type(v)
    if t == "string" then
        out[#out + 1] = string.format("%q", v)
    elseif t == "number" then
        out[#out + 1] = (math.type and math.type(v) == "integer") and tostring(v) or string.format("%.17g", v)
    elseif t == "boolean" then
        out[#out + 1] = tostring(v)
    elseif t == "table" then
        out[#out + 1] = "{"
        for k, val in pairs(v) do
            local kt = type(k)
            if (kt == "string" or kt == "number") and type(val) ~= "function" then
                out[#out + 1] = "["
                encodeValue(k, out)
                out[#out + 1] = "]="
                encodeValue(val, out)
                out[#out + 1] = ","
            end
        end
        out[#out + 1] = "}"
    else
        out[#out + 1] = "nil"
    end
end

local function toHex(s)
    return (s:gsub(".", function(c) return string.format("%02x", c:byte()) end))
end

local function fromHex(h)
    if #h % 2 ~= 0 or h:find("[^0-9a-f]") then return nil end
    return (h:gsub("..", function(cc) return string.char(tonumber(cc, 16)) end))
end

local function decode(hex)
    local src = fromHex(hex or "")
    if not src or src == "" then return nil end
    -- ambiente vazio: o texto só pode montar tabelas, nunca chamar funções do jogo
    local chunk = load("return " .. src, "save", "t", {})
    if not chunk then return nil end
    local ok, data = pcall(chunk)
    if ok and type(data) == "table" then return data end
    return nil
end

----------------------------------------------------------------------
-- Leitura e escrita dos espaços
----------------------------------------------------------------------
local function key(n) return Saves.prefix .. n end

function Saves.read(n)
    local ok, hex = pcall(UserSettings.getStringForKey, key(n), "")
    if not ok or hex == "" then return nil end
    return decode(hex)
end

-- Resumo para a tela de saves: nil (vazio) ou { night, resolved, total, ending, seq }
function Saves.info(n)
    local data = Saves.read(n)
    if not data or type(data.state) ~= "table" then return nil end
    local s, N = data.state, Flow.narrative()
    local resolved = 0
    for _, c in ipairs(N.cases) do
        if s.resolved and s.resolved[c.id] then resolved = resolved + 1 end
    end
    return { night = s.night or 1, resolved = resolved, total = #N.cases, ending = s.ending,
             seq = data.seq or 0, mistakes = s.mistakes or 0 }
end

-- Espaço em andamento salvo por último (para o "Continuar" do menu)
function Saves.latest()
    local best, bestSeq = nil, -1
    for n = 1, Saves.SLOTS do
        local info = Saves.info(n)
        if info and not info.ending and info.seq > bestSeq then best, bestSeq = n, info.seq end
    end
    return best
end

function Saves.save()
    local n = Saves.current
    local s = Flow.state
    if not n or s.phase == "menu" then return false end
    local state = {}
    for _, f in ipairs(FIELDS) do state[f] = s[f] end
    local data = { version = Saves.VERSION, state = state }
    -- onde o coveiro estava (só vale para retomar a mesma noite)
    local w = Flow.worldController
    if w and w.player and s.phase == "playing" then
        local p = w.player.position
        data.pos = { x = p.x, z = p.z, yaw = w.yaw, night = s.night }
    end
    local okSeq, seq = pcall(UserSettings.getIntegerForKey, Saves.prefix .. "seq", 0)
    data.seq = (okSeq and seq or 0) + 1
    local out = {}
    encodeValue(data, out)
    local ok, err = pcall(function()
        UserSettings.setStringForKey(key(n), toHex(table.concat(out)))
        UserSettings.setIntegerForKey(Saves.prefix .. "seq", data.seq)
    end)
    if not ok then Log.warn("Saves: could not write slot " .. n .. ": " .. tostring(err)) end
    return ok
end

function Saves.delete(n)
    pcall(UserSettings.removeKey, key(n))
    if Saves.current == n then Saves.current = nil end
end

-- Novo jogo no espaço n (apaga o que havia nele)
function Saves.startNew(n)
    Saves.delete(n)
    Saves.current = n
end

-- Retoma a campanha do espaço n: volta à abertura da noite em que parou
function Saves.load(n)
    local data = Saves.read(n)
    if not data or type(data.state) ~= "table" or data.state.ending then return false end
    local s = Flow.newState()
    for _, f in ipairs(FIELDS) do
        if data.state[f] ~= nil then s[f] = data.state[f] end
    end
    s.phase = "night_intro"
    s.resumePos = data.pos and data.pos.night == s.night and data.pos or nil
    Saves.current = n
    Flow.restore(s)
    return true
end

-- Salva sozinho nos momentos que mudam a campanha
function Saves.install()
    local autosave = function() Saves.save() end
    for _, ev in ipairs({ "nightStarted", "nightEnded", "caseResolved", "caseProven", "clueNoted",
                          "evidenceRead", "chiselReady", "mistake", "spiritAwake", "ending" }) do
        Flow.on(ev, "saves", autosave)
    end
end

return Saves
