local addonName, ns = ...
local db
local lastLineAt = -math.huge

local function report(message)
    print("|cff73d6ffParlance|r " .. message)
end

function ns.IsSecret(value)
    return issecretvalue and issecretvalue(value)
end

function ns.SpellID(value)
    local id = tonumber(value)
    if id and id >= 1 and id <= 4294967295 and id == math.floor(id) then
        return id
    end
end

function ns.Lines(text)
    local lines = {}
    for line in text:gmatch("[^\r\n]+") do
        line = line:match("^%s*(.-)%s*$")
        if line ~= "" then
            if #line > 255 or line:find("%c") then
                return nil, "Keep each line within 255 bytes and remove control characters."
            end
            lines[#lines + 1] = line
        end
    end
    return lines
end

local function choose(rule)
    local roll = math.random(100)
    if roll <= rule.emoteChance then
        return "EMOTE", rule.emotes[math.random(#rule.emotes)]
    end
    if roll <= rule.emoteChance + rule.speechChance then
        return "SAY", rule.speech[math.random(#rule.speech)]
    end
end

function ns.GetVoices()
    return C_VoiceChat and C_VoiceChat.GetTtsVoices and C_VoiceChat.GetTtsVoices() or {}
end

local function voiceIDForName(voices, name)
    if name then
        for _, voice in ipairs(voices) do
            if voice.name == name then
                return voice.voiceID
            end
        end
    end
end

function ns.Speak(text, gain, preferredVoice, overrideVoice)
    if not (C_VoiceChat and C_VoiceChat.SpeakText) then
        return false
    end
    local voices = ns.GetVoices()
    if not voices[1] then
        return false
    end
    local voiceID = voiceIDForName(voices, overrideVoice) or voiceIDForName(voices, preferredVoice)
    if not voiceID and C_TTSSettings and C_TTSSettings.GetVoiceOptionID and Enum and Enum.TtsVoiceType
        and Enum.TtsVoiceType.Standard then
        local selected = C_TTSSettings.GetVoiceOptionID(Enum.TtsVoiceType.Standard)
        for _, voice in ipairs(voices) do
            if voice.voiceID == selected then
                voiceID = selected
                break
            end
        end
    end
    voiceID = voiceID or voices[1].voiceID
    -- Windows SpeakText supports XML tags, so treat every custom line as plain text.
    text = text:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
    local rate = C_TTSSettings and C_TTSSettings.GetSpeechRate and C_TTSSettings.GetSpeechRate() or 0
    local volume = C_TTSSettings and C_TTSSettings.GetSpeechVolume and C_TTSSettings.GetSpeechVolume() or 100
    volume = math.floor(math.min(100, math.max(0, volume * gain)) + 0.5)
    if volume == 0 then
        return true
    end
    return pcall(C_VoiceChat.SpeakText, voiceID, text, rate, volume, false)
end

local function characterName()
    local name = GetUnitName("player", true)
    if ns.IsSecret(name) or not name then
        return "You"
    end
    return name
end

function ns.NamePronunciation(text)
    text = text:match("^%s*(.-)%s*$")
    if #text > 64 or text:find("%c") then
        return nil, "Use up to 64 bytes of plain text for the name."
    end
    if text ~= "" then
        return text
    end
end

function ns.NarratedName()
    return db.namePronunciation or characterName()
end

local function showLine(kind, text)
    local name = characterName()
    local line = kind == "SAY" and (name .. ' says: "' .. text .. '"') or (name .. " " .. text)
    DEFAULT_CHAT_FRAME:AddMessage("[Parlance] " .. line:gsub("|", "||"), 0.71, 0.87, 1)
end

local function speakLocal(kind, text, gain)
    if kind == "EMOTE" and db.narratorVoice then
        return ns.Speak(ns.NarratedName() .. " " .. text, gain, db.narratorVoice)
    end
    return ns.Speak(text, gain, db.preferredVoice)
end

function ns.Preview(kind, line, readAloud)
    local text, delivery = ns.Delivery(line)
    showLine(kind, text)
    if readAloud and not speakLocal(kind, text, delivery.gain) then
        report("Text-to-speech is unavailable. Check the game's Accessibility settings and installed voices.")
    end
end

local function fire(id, manual)
    local rule = db.rules[id]
    if not db.enabled or not rule or rule.manual ~= manual then
        return
    end
    local now = GetTime()
    if now - lastLineAt < db.cooldown then
        return
    end
    local kind, line = choose(rule)
    if not kind then
        return
    end
    lastLineAt = now
    local text, delivery = ns.Delivery(line)
    if db.share then
        ns.ShareLine(line, db.preferredVoice, kind == "EMOTE", db.namePronunciation)
    end
    local sent = false
    if db.public and C_ChatInfo and C_ChatInfo.SendChatMessage and C_ChatInfo.InChatMessagingLockdown
        and not C_ChatInfo.InChatMessagingLockdown() then
        sent = pcall(C_ChatInfo.SendChatMessage, text:gsub("|", "||"), kind)
    end
    if not sent then
        showLine(kind, text)
    end
    if db.tts then
        speakLocal(kind, text, delivery.gain)
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
events:SetScript("OnEvent", function(self, event, ...)
    local unit, _, spellID = ...
    if event == "ADDON_LOADED" then
        if unit == addonName then
            ForeverVoiceDB = type(ForeverVoiceDB) == "table" and ForeverVoiceDB or {}
            db = ForeverVoiceDB
            db.rules = type(db.rules) == "table" and db.rules or {}
            db.friendVoices = type(db.friendVoices) == "table" and db.friendVoices or {}
            db.namePronunciation = type(db.namePronunciation) == "string" and ns.NamePronunciation(db.namePronunciation) or nil
            db.enabled = db.enabled ~= false
            db.cooldown = type(db.cooldown) == "number" and db.cooldown or 8
            self:UnregisterEvent("ADDON_LOADED")
            ns.StartSharing(self)
        end
        return
    end
    if event == "CHAT_MSG_ADDON" then
        if db.enabled and db.listen then
            ns.ReceiveLine(db.friendVoices, db.narratorVoice, ...)
        end
        return
    end
    if not db or ns.IsSecret(unit) or unit ~= "player" then
        return
    end
    if ns.IsSecret(spellID) or type(spellID) ~= "number" then
        if ns.OnCapture then
            local capture = ns.OnCapture
            ns.OnCapture = nil
            capture(nil)
        end
        return
    end
    if ns.OnCapture then
        local capture = ns.OnCapture
        ns.OnCapture = nil
        capture(spellID)
        return
    end
    fire(spellID, false)
end)

SLASH_FOREVERVOICE1 = "/parlance"
SLASH_FOREVERVOICE2 = "/fvo"
SlashCmdList.FOREVERVOICE = function(message)
    if not db then
        return
    end
    local action, arg = message:match("^%s*(%S*)%s*(.-)%s*$")
    if action == "fire" then
        local id = ns.SpellID(arg)
        if id then
            fire(id, true)
        end
    elseif action == "" then
        ns.OpenEditor(db)
    else
        report("Use /parlance to open settings, or /parlance fire SPELL_ID for a macro-triggered rule.")
    end
end
