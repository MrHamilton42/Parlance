local handler
local secret = {}
function issecretvalue(value)
    return rawequal(value, secret)
end

local localLines, chat, tts, outbound = {}, {}, {}, {}
local now, lockdown = 100, false
local inputs, boxes, buttons, dropdowns = {}, {}, {}, {}
local registeredPrefixes = {}
local registeredPrefix, voicePrefix = "ForeverVoice1", "ForeverVoiceV"
local group, addonLockdown

local function widget(name)
    local object = { scripts = {}, text = "" }
    for _, method in ipairs({
        "SetSize", "SetPoint", "SetFrameStrata", "SetClampedToScreen", "SetMovable",
        "EnableMouse", "RegisterForDrag", "StartMoving", "StopMovingOrSizing", "SetWidth",
        "SetJustifyH", "SetAutoFocus", "SetMultiLine", "SetMaxLetters", "SetFontObject",
        "ClearFocus", "SetDefaultText", "SetupMenu", "Show",
    }) do
        object[method] = function() end
    end
    function object:GetName() return name end
    function object:SetupMenu(callback) self.populate = callback end
    function object:SetDefaultText(text) self.defaultText = text end
    function object:CreateFontString() return widget() end
    function object:SetEnabled(value) self.enabled = value end
    function object:SetChecked(value) self.checked = value end
    function object:GetChecked() return self.checked end
    function object:SetScript(event, callback)
        self.scripts[event] = callback
    end
    function object:SetText(text)
        self.text = text
        if self.scripts.OnTextChanged then
            self.scripts.OnTextChanged(self)
        end
    end
    function object:GetText() return self.text end
    return object
end

function CreateFrame(kind, name)
    local object = widget(name)
    if name == "ForeverVoiceEditor" then
        object.TitleText = widget()
    elseif kind == "Frame" then
        return {
            RegisterEvent = function() end,
            UnregisterEvent = function() end,
            RegisterUnitEvent = function(_, event, unit)
                assert(event == "UNIT_SPELLCAST_SUCCEEDED" and unit == "player")
            end,
            SetScript = function(self, _, fn)
                handler = function(...) fn(self, ...) end
            end,
        }
    elseif kind == "Button" then
        buttons[#buttons + 1] = object
    elseif kind == "DropdownButton" then
        dropdowns[#dropdowns + 1] = object
    elseif kind == "EditBox" then
        inputs[#inputs + 1] = object
    elseif kind == "ScrollFrame" then
        object.EditBox = widget()
        boxes[#boxes + 1] = object.EditBox
    end
    return object
end

SlashCmdList, UISpecialFrames = {}, {}
tinsert = table.insert
GetTime = function() return now end
DEFAULT_CHAT_FRAME = { AddMessage = function(_, line) table.insert(localLines, line) end }
C_ChatInfo = {
    InChatMessagingLockdown = function() return lockdown end,
    SendChatMessage = function(text, kind) table.insert(chat, { text, kind }) end,
    RegisterAddonMessagePrefix = function(prefix) registeredPrefixes[prefix] = true end,
    IsAddonMessagePrefixRegistered = function(prefix) return registeredPrefixes[prefix] end,
    AreOutgoingAddonChatMessagesRestricted = function() return addonLockdown end,
    SendAddonMessage = function(...) table.insert(outbound, { ... }) end,
}
IsInRaid = function() return group == "RAID" end
IsInGroup = function() return group ~= nil end
GetNumGroupMembers = function() return 2 end
GetNumSubgroupMembers = function() return 1 end
GetNormalizedRealmName = function() return "Realm" end
GetUnitName = function(unit, full)
    assert(full)
    if unit == "player" or unit == "raid1" then
        return "Hero"
    end
    if unit == "party1" or unit == "raid2" then
        return "Friend Name"
    end
end
UnitGUID = function(unit)
    if unit == "party1" or unit == "raid2" then
        return "Player-42"
    end
end
C_FriendList = {
    GetNumFriends = function() return 1 end,
    GetFriendInfoByIndex = function() return { guid = "Player-42", name = "Friend Name" } end,
}
local installedVoices = { { voiceID = 2, name = "Willow" }, { voiceID = 8, name = "Default" } }
C_VoiceChat = {
    GetTtsVoices = function() return installedVoices end,
    SpeakText = function(...) table.insert(tts, { ... }) end,
}
Enum = { TtsVoiceType = { Standard = 0 } }
C_TTSSettings = {
    GetVoiceOptionID = function(kind) assert(kind == 0); return 8 end,
    GetSpeechRate = function() return 1 end,
    GetSpeechVolume = function() return 65 end,
}

local ns = {}
assert(load(__Sharing))("ForeverVoice", ns)
assert(load(__Core))("ForeverVoice", ns)
assert(load(__Editor))("ForeverVoice", ns)
handler("ADDON_LOADED", "ForeverVoice")
local db = ForeverVoiceDB
assert(db.enabled and db.cooldown == 8 and next(db.rules) == nil)
assert(not db.share and not db.listen and registeredPrefixes[registeredPrefix] and registeredPrefixes[voicePrefix])
assert(ns.Lines(("a"):rep(256)) == nil)
assert(ns.SpellID("1.5") == nil)

local function cast(id, unit)
    handler("UNIT_SPELLCAST_SUCCEEDED", unit or "player", "cast-guid", id)
end

local function click(text)
    for _, button in ipairs(buttons) do
        if button.text == text then
            assert(button.enabled ~= false)
            button.scripts.OnClick(button)
            return
        end
    end
    error("Missing button: " .. text)
end

SlashCmdList.FOREVERVOICE("")
click("Capture next cast")
cast(secret)
assert(inputs[3]:GetText() == "")
click("Capture next cast")
cast(100)
assert(inputs[3]:GetText() == "100")
inputs[4]:SetText("25")
inputs[5]:SetText("80")
click("Save rule")
assert(db.rules[100] == nil)
inputs[5]:SetText("50")
click("Save rule")
assert(db.rules[100] == nil)
boxes[1]:SetText("  nods. \r\n\n raises a fist. ")
boxes[2]:SetText("Ready <now> & steady.")
click("Save rule")
local rule = assert(db.rules[100])
assert(#rule.emotes == 2 and rule.emotes[2] == "raises a fist." and #rule.speech == 1)

local roll, row = 25, 2
math.random = function(max)
    local value = max == 100 and roll or row
    assert(value >= 1 and value <= max)
    return value
end

cast(100, "pet")
cast(secret)
assert(#localLines == 0)
cast(100)
assert(localLines[1]:find("Hero raises a fist.", 1, true))
assert(#chat == 0 and #tts == 0)
roll, row, now = 26, 1, 107
cast(100)
assert(#localLines == 1)
db.tts = true
now = 108
cast(100)
assert(localLines[2]:find('Hero says: "Ready <now> & steady."', 1, true))
assert(tts[1][1] == 8 and tts[1][2] == "Ready &lt;now&gt; &amp; steady.")
assert(tts[1][3] == 1 and tts[1][4] == 65 and tts[1][5] == false)

db.public, lockdown, now = true, true, 116
roll = 76
cast(100)
assert(#localLines == 2 and #tts == 1)
roll = 75
cast(100)
assert(#localLines == 3 and #chat == 0, "A silent roll does not consume the cooldown")

lockdown, now = false, 124
cast(100)
assert(#localLines == 3 and chat[1][2] == "SAY")
now = 132
roll = 1
C_ChatInfo.SendChatMessage = function() error("blocked") end
cast(100)
assert(#localLines == 4 and #chat == 1)

now = 140
db.public = false
rule.manual = true
cast(100)
assert(#localLines == 4)
SlashCmdList.FOREVERVOICE("fire 100")
assert(#localLines == 5)
db.enabled = false
now = 148
SlashCmdList.FOREVERVOICE("fire 100")
assert(#localLines == 5)
click("Preview speech")
assert(#localLines == 6 and #chat == 1)
click("Delete rule")
assert(next(db.rules) == nil)

db.rules[100], db.enabled = rule, true
rule.emotes[1] = "[WHISPER] nods."
group, now = "PARTY", 156
SlashCmdList.FOREVERVOICE("fire 100")
assert(#outbound == 0 and tts[#tts][2] == "nods." and tts[#tts][4] == 23)
db.share, now = true, 164
SlashCmdList.FOREVERVOICE("fire 100")
assert(#outbound == 2 and outbound[1][1] == voicePrefix and outbound[1][2]:match("^%d+:$")
    and outbound[2][1] == registeredPrefix and outbound[2][2] == "[WHISPER] nods." and outbound[2][3] == "PARTY")
addonLockdown, now = true, 172
SlashCmdList.FOREVERVOICE("fire 100")
assert(#outbound == 2 and localLines[#localLines]:find("Hero nods.", 1, true))
addonLockdown, group, now = false, "RAID", 180
SlashCmdList.FOREVERVOICE("fire 100")
assert(#outbound == 4 and outbound[4][3] == "RAID")

local distanceSquared, checked = 25, true
UnitDistanceSquared = function(unit)
    assert(unit == (group == "RAID" and "raid2" or "party1"))
    return distanceSquared, checked
end

local function receive(line, sender, channel, prefix)
    handler("CHAT_MSG_ADDON", prefix or registeredPrefix, line, channel or group, sender or "Friend Name-Realm")
end

local before = #tts
receive("test")
assert(#tts == before)
db.listen = true
receive("test", "Hero")
receive("test", "Friend")
receive("test", "Stranger")
receive("test", nil, "WHISPER")
receive("test", nil, nil, "SomeOtherAddon")
receive(secret)
receive("test\ninvalid")
assert(#tts == before)
receive("Ready.")
assert(#tts == before + 1 and tts[#tts][4] == 54)
receive("Too soon.")
assert(#tts == before + 1)

group, distanceSquared, now = "PARTY", 225, 182
receive("Ready.", "Friend Name")
assert(#tts == before + 2 and tts[#tts][4] == 33)
now = 184
receive("[whisper] Out of range.")
assert(#tts == before + 2)
distanceSquared = 16
receive("[whisper] Stay close.")
assert(tts[#tts][2] == "Stay close." and tts[#tts][4] == 11)
distanceSquared, now = 81, 186
receive("[quietly] Over here.")
assert(tts[#tts][2] == "Over here." and tts[#tts][4] == 20)
distanceSquared, now = 900, 188
receive("Too far.")
assert(tts[#tts][2] == "Over here.")
receive("[yell] Over here!")
assert(tts[#tts][2] == "Over here!" and tts[#tts][4] == 33)
now, distanceSquared = 190, secret
receive("[yell] Hidden distance.")
distanceSquared, checked = 0, false
receive("[yell] Unavailable distance.")
checked = secret
receive("[yell] Hidden validity.")
assert(tts[#tts][2] == "Over here!")

local function menuDescription()
    local menu = { buttons = {}, SetScrollMode = function() end, CreateTitle = function() end }
    function menu:CreateButton(label, callback, data)
        local item = menuDescription()
        item.pick = callback and function() callback(data) end
        self.buttons[label] = item
        return item
    end
    return menu
end

local function openMenu(label)
    for _, dropdown in ipairs(dropdowns) do
        if dropdown.defaultText == label then
            local menu = menuDescription()
            dropdown.populate(dropdown, menu)
            return menu.buttons
        end
    end
    error("Missing dropdown: " .. label)
end

openMenu("WoW default").Willow.pick()
assert(db.preferredVoice == "Willow")
click("Hear sample")
assert(tts[#tts][1] == 2)

-- Preserve a full-length legacy line while sending the selected voice separately.
local longLine = ("a"):rep(255)
rule.emotes[1], now = longLine, 198
SlashCmdList.FOREVERVOICE("fire 100")
local hint, packet = outbound[#outbound - 1], outbound[#outbound]
local emoteHint = outbound[#outbound - 2]
assert(hint[1] == voicePrefix and hint[2]:match(":Willow$"))
assert(packet[1] == registeredPrefix and packet[2] == longLine and packet[3] == "PARTY")
distanceSquared, checked = 25, true
installedVoices = {
    { voiceID = 52, name = "Willow" },
    { voiceID = 60, name = "Cedar" },
    { voiceID = 8, name = "Default" },
}

local function deliver(packetHint, line)
    receive(packetHint, nil, nil, voicePrefix)
    receive(line)
end
deliver(hint[2], longLine)
assert(tts[#tts][1] == 52, "Resolve a shared voice by name to the listener's ID")

openMenu("Choose a character friend")["Friend Name"].buttons.Cedar.pick()
now = 200
deliver(hint[2], longLine)
assert(tts[#tts][1] == 60, "Friend override takes priority")
now = 202
installedVoices[2] = { voiceID = 61, name = "Birch" }
deliver(hint[2], longLine)
assert(tts[#tts][1] == 52, "Unavailable override falls back to the speaker's choice")
now = 204
installedVoices[1] = { voiceID = 53, name = "Ash" }
deliver(hint[2], longLine)
assert(tts[#tts][1] == 8, "Unavailable choices fall back to the WoW default")

openMenu("Choose a character friend")["Friend Name (Cedar)"].buttons["Use speaker preference"].pick()
assert(not db.friendVoices["Player-42"])
openMenu("Willow")["WoW default"].pick()
assert(not db.preferredVoice)
installedVoices[1] = { voiceID = 52, name = "Willow" }
now = 206
deliver(hint[2], "A different line.")
assert(tts[#tts][1] == 8, "Voice hints apply only to the matching line")
now = 208
receive(longLine)
assert(tts[#tts][1] == 8, "Legacy messages work without hints")
now = 210
receive(hint[2], nil, nil, voicePrefix)
now = 212
receive(longLine)
assert(tts[#tts][1] == 8, "An expired hint never selects a voice")

openMenu("Use character voices").Birch.pick()
click("Hear narrator")
assert(tts[#tts][1] == 61)
boxes[1]:SetText("[quietly] waves hello.")
click("Preview emote")
assert(tts[#tts][1] == 61 and tts[#tts][2] == "Hero waves hello." and tts[#tts][4] == 39)
boxes[2]:SetText("Ready <now> & steady.")
click("Preview speech")
assert(tts[#tts][1] == 8 and tts[#tts][2] == "Ready &lt;now&gt; &amp; steady.")
now = 214
receive(emoteHint[2], nil, nil, voicePrefix)
deliver(hint[2], longLine)
assert(tts[#tts][1] == 61 and tts[#tts][2] == "Friend Name " .. longLine)
now = 216
deliver(hint[2], longLine)
assert(tts[#tts][1] == 52 and tts[#tts][2] == longLine, "Unmarked lines still use character voices")

inputs[1]:SetText("  KAY-len  ")
click("Save")
assert(db.namePronunciation == "KAY-len")
click("Hear narrator")
assert(tts[#tts][2] == "KAY-len raises a hand in greeting.")
inputs[1]:SetText(("a"):rep(65))
click("Save")
assert(db.namePronunciation == "KAY-len", "Invalid edits preserve the last saved spelling")
rule.emotes[1], now = "waves hello.", 218
SlashCmdList.FOREVERVOICE("fire 100")
assert(tts[#tts][2] == "KAY-len waves hello.")
assert(localLines[#localLines]:find("Hero waves hello.", 1, true))
local spellingPacket, emotePacket = outbound[#outbound - 1], outbound[#outbound]
assert(spellingPacket[1] == voicePrefix and spellingPacket[2]:match("^%d+: KAY%-len$"))
assert(emotePacket[1] == registeredPrefix and emotePacket[2] == "waves hello.")

inputs[1]:SetText("")
click("Save")
assert(not db.namePronunciation)
now = 220
deliver(spellingPacket[2], emotePacket[2])
assert(tts[#tts][2] == "KAY-len waves hello.", "Use the incoming spelling, even without a separate emote hint")
now = 222
deliver(spellingPacket[2], "A different line.")
assert(tts[#tts][2] == "A different line.", "A spelling hint cannot apply to different text")
print("Forever Voice Lua tests passed.")
