local _, ns = ...
local prefix = "ForeverVoice1"
local voicePrefix = "ForeverVoiceV"
local registered = false
local voiceRegistered = false
local voiceHints = {}
local nextIncomingAt = 0

local normal = { gain = 1, radius = 30 }
local styles = {
    whisper = { gain = 0.35, radius = 8 },
    quietly = { gain = 0.60, radius = 18 },
    yell = { gain = 1, radius = 60 },
}

function ns.Delivery(line)
    local tag, text = line:match("^%[([%a]+)%]%s*(%S.*)$")
    local style = tag and styles[tag:lower()]
    if style then
        return text, style
    end
    return line, normal
end

local function groupChannel()
    if IsInRaid(LE_PARTY_CATEGORY_HOME) then
        return "RAID"
    end
    if IsInGroup(LE_PARTY_CATEGORY_HOME) then
        return "PARTY"
    end
end

local function register(messagePrefix)
    return pcall(C_ChatInfo.RegisterAddonMessagePrefix, messagePrefix)
        and C_ChatInfo.IsAddonMessagePrefixRegistered(messagePrefix)
end

function ns.StartSharing(frame)
    if not (C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix and C_ChatInfo.IsAddonMessagePrefixRegistered) then
        return
    end
    registered = register(prefix)
    if registered then
        voiceRegistered = register(voicePrefix)
        frame:RegisterEvent("CHAT_MSG_ADDON")
    end
end

-- A separate hint leaves all 255 bytes available for the original line and older listeners.
local function lineSignature(line)
    local hash = 0
    for index = 1, #line do
        hash = (hash * 31.0 + line:byte(index)) % 4294967296
    end
    return string.format("%.0f", hash)
end

function ns.ShareLine(line, preferredVoice, isEmote, pronunciation)
    if not registered or not C_ChatInfo.SendAddonMessage then
        return
    end
    local channel = groupChannel()
    if not channel then
        return
    end
    if C_ChatInfo.AreOutgoingAddonChatMessagesRestricted and C_ChatInfo.AreOutgoingAddonChatMessagesRestricted() then
        return
    end
    if voiceRegistered then
        local hasVoice = type(preferredVoice) == "string" and preferredVoice:find("^%S")
            and not preferredVoice:find("%c")
        if isEmote or hasVoice then
            local header = lineSignature(line) .. ":"
            if isEmote then
                pcall(C_ChatInfo.SendAddonMessage, voicePrefix, header, channel)
                if pronunciation then
                    -- The space distinguishes this from a voice name and older listeners ignore it.
                    pcall(C_ChatInfo.SendAddonMessage, voicePrefix, header .. " " .. pronunciation, channel)
                end
            end
            if hasVoice and #header + #preferredVoice <= 255 then
                pcall(C_ChatInfo.SendAddonMessage, voicePrefix, header .. preferredVoice, channel)
            end
        end
    end
    pcall(C_ChatInfo.SendAddonMessage, prefix, line, channel)
end

local function matchesSender(unit, sender)
    -- Forever's UnitFullName tuple carries a surname. GetUnitName gives us the complete name.
    local name = GetUnitName(unit, true)
    if ns.IsSecret(name) or not name then
        return false
    end
    if name == sender then
        return true
    end
    local realm = GetNormalizedRealmName()
    return not ns.IsSecret(realm) and realm and name .. "-" .. realm == sender
end

local function senderUnit(sender, channel)
    if matchesSender("player", sender) then
        return
    end
    local raid = channel == "RAID"
    local unitPrefix = raid and "raid" or "party"
    local count = raid and GetNumGroupMembers(LE_PARTY_CATEGORY_HOME)
        or GetNumSubgroupMembers(LE_PARTY_CATEGORY_HOME)
    local matched
    for index = 1, count do
        local unit = unitPrefix .. index
        if matchesSender(unit, sender) then
            if matched then
                return
            end
            matched = unit
        end
    end
    return matched
end

function ns.ReceiveLine(friendVoices, narratorVoice, messagePrefix, line, channel, sender)
    if ns.IsSecret(messagePrefix) or ns.IsSecret(line) or ns.IsSecret(channel) or ns.IsSecret(sender)
        or (messagePrefix ~= prefix and messagePrefix ~= voicePrefix)
        or type(line) ~= "string" or #line > 255 or line:find("%c") or not line:find("%S")
        or type(sender) ~= "string" or (channel ~= "PARTY" and channel ~= "RAID")
        or channel ~= groupChannel() or not UnitDistanceSquared then
        return
    end
    local unit = senderUnit(sender, channel)
    if not unit then
        return
    end
    local now = GetTime()
    if messagePrefix == voicePrefix then
        local signature, voice = line:match("^(%d+):(.*)$")
        local pronunciation = voice and voice:sub(1, 1) == " " and ns.NamePronunciation(voice)
        if signature and #signature <= 10 and (pronunciation or voice == "" or voice:find("^%S")) then
            for key, hint in pairs(voiceHints) do
                if now >= hint.expires then
                    voiceHints[key] = nil
                end
            end
            local hint = voiceHints[sender]
            if not hint or hint.signature ~= signature or hint.channel ~= channel then
                hint = { signature = signature, channel = channel, expires = now + 2 }
                voiceHints[sender] = hint
            end
            if pronunciation then
                hint.pronunciation = pronunciation
                hint.isEmote = true
            elseif voice == "" then
                hint.isEmote = true
            else
                hint.voice = voice
            end
        end
        return
    end
    local hint = voiceHints[sender]
    voiceHints[sender] = nil
    if now < nextIncomingAt then
        return
    end
    local ok, distanceSquared, checked = pcall(UnitDistanceSquared, unit)
    if not ok or ns.IsSecret(distanceSquared) or ns.IsSecret(checked)
        or not checked or type(distanceSquared) ~= "number" or distanceSquared < 0 then
        return
    end
    local text, delivery = ns.Delivery(line)
    local distance = math.sqrt(distanceSquared)
    if distance < delivery.radius then
        local gain = delivery.gain * (1 - distance / delivery.radius)
        local matchingHint = hint and hint.channel == channel and now < hint.expires
            and hint.signature == lineSignature(line)
        local played
        if matchingHint and hint.isEmote and narratorVoice then
            local name = hint.pronunciation or GetUnitName(unit, true)
            if not ns.IsSecret(name) and name then
                text = name .. " " .. text
            end
            played = ns.Speak(text, gain, narratorVoice)
        else
            local guid = UnitGUID and UnitGUID(unit)
            local overrideVoice = not ns.IsSecret(guid) and guid and friendVoices[guid]
            played = ns.Speak(text, gain, matchingHint and hint.voice, overrideVoice)
        end
        if played then
            nextIncomingAt = now + 2
        end
    end
end
