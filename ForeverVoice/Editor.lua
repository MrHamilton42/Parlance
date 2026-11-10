local _, ns = ...
local editor

local function wholeNumber(text, limit)
    local number = tonumber(text)
    if number and number >= 0 and number <= limit and number == math.floor(number) then
        return number
    end
end

local function spellLabel(id)
    local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id)
    return name and (name .. " (" .. id .. ")") or ("Spell " .. id)
end

local function addVoiceChoices(menu, voices, defaultLabel, save)
    menu:CreateButton(defaultLabel, function() save(nil) end)
    for _, voice in ipairs(voices) do
        menu:CreateButton(voice.name, save, voice.name)
    end
    if #voices == 0 then
        menu:CreateTitle("No voices available in WoW")
    end
end

local function createEditor(db)
    local frame = CreateFrame("Frame", "ForeverVoiceEditor", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(590, 580)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetScript("OnHide", function()
        ns.OnCapture = nil
    end)
    frame.TitleText:SetText("Parlance")
    tinsert(UISpecialFrames, frame:GetName())

    local function place(widget, x, y)
        widget:SetPoint("TOPLEFT", frame, "TOPLEFT", x, -y)
        return widget
    end

    local function label(text, x, y, font)
        local widget = place(frame:CreateFontString(nil, "OVERLAY", font or "GameFontNormal"), x, y)
        widget:SetText(text)
        return widget
    end

    local function button(text, x, y, width, callback)
        local widget = place(CreateFrame("Button", nil, frame, "UIPanelButtonTemplate"), x, y)
        widget:SetSize(width, 24)
        widget:SetText(text)
        widget:SetScript("OnClick", callback)
        return widget
    end

    local function check(text, x, y)
        local widget = place(CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate"), x, y)
        widget:SetSize(24, 24)
        local caption = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        caption:SetPoint("LEFT", widget, "RIGHT", 2, 0)
        caption:SetText(text)
        return widget
    end

    local function input(x, y, width)
        local widget = place(CreateFrame("EditBox", nil, frame, "InputBoxTemplate"), x, y)
        widget:SetSize(width, 24)
        widget:SetAutoFocus(false)
        widget:SetScript("OnEscapePressed", widget.ClearFocus)
        widget:SetScript("OnEnterPressed", widget.ClearFocus)
        return widget
    end

    local function lineBox(x)
        local scroll = place(CreateFrame("ScrollFrame", nil, frame, "InputScrollFrameTemplate"), x, 223)
        scroll:SetSize(250, 126)
        local box = scroll.EditBox
        box:SetWidth(228)
        box:SetMultiLine(true)
        box:SetMaxLetters(0)
        box:SetAutoFocus(false)
        box:SetFontObject(GameFontHighlight)
        return box
    end

    local status = label("", 18, 555, "GameFontHighlightSmall")
    status:SetWidth(552)
    status:SetJustifyH("LEFT")
    local function tell(message)
        status:SetText(message)
    end

    for _, setting in ipairs({
        { key = "enabled", text = "Enabled", x = 16, y = 32 },
        { key = "tts", text = "Read aloud locally", x = 100, y = 32 },
        { key = "public", text = "Try public chat", x = 240, y = 32 },
        { key = "share", text = "Share with group", x = 16, y = 390 },
        { key = "listen", text = "Hear nearby group lines", x = 166, y = 390 },
    }) do
        local key = setting.key
        local widget = check(setting.text, setting.x, setting.y)
        widget:SetChecked(db[key] == true)
        widget:SetScript("OnClick", function(self)
            db[key] = self:GetChecked() and true or false
            tell("Character settings saved.")
        end)
    end
    label("Start a line with [whisper], [quietly], or [yell] to set its delivery.", 18, 417, "GameFontHighlightSmall")

    local function previewVoice(line, voice)
        local played = ns.Speak(line, 1, voice)
        tell(played and "Previewed the voice locally." or "No text-to-speech voice is available in WoW.")
    end

    label("My preferred voice", 18, 442)
    local preferred = place(CreateFrame("DropdownButton", nil, frame, "WowStyle1DropdownTemplate"), 16, 461)
    preferred:SetWidth(230)
    preferred:SetDefaultText(db.preferredVoice or "WoW default")
    preferred:SetupMenu(function(_, menu)
        menu:SetScrollMode(240)
        addVoiceChoices(menu, ns.GetVoices(), "WoW default", function(name)
            db.preferredVoice = name
            preferred:SetDefaultText(name or "WoW default")
            tell("Preferred voice saved.")
        end)
    end)
    button("Hear sample", 252, 461, 100, function()
        previewVoice("This is how my character sounds.", db.preferredVoice)
    end)

    label("Narrator voice for emotes", 18, 495)
    local narrator = place(CreateFrame("DropdownButton", nil, frame, "WowStyle1DropdownTemplate"), 16, 514)
    narrator:SetWidth(230)
    narrator:SetDefaultText(db.narratorVoice or "Use character voices")
    narrator:SetupMenu(function(_, menu)
        menu:SetScrollMode(240)
        addVoiceChoices(menu, ns.GetVoices(), "Use character voices", function(name)
            db.narratorVoice = name
            narrator:SetDefaultText(name or "Use character voices")
            tell("Narrator setting saved.")
        end)
    end)
    button("Hear narrator", 252, 514, 100, function()
        previewVoice(ns.NarratedName() .. " raises a hand in greeting.", db.narratorVoice or db.preferredVoice)
    end)

    label("Name pronunciation (optional)", 369, 495)
    local pronunciation = input(373, 514, 141)
    pronunciation:SetText(db.namePronunciation or "")
    local function savePronunciation()
        local spelling, errorText = ns.NamePronunciation(pronunciation:GetText())
        if errorText then
            tell(errorText)
            return
        end
        db.namePronunciation = spelling
        pronunciation:SetText(spelling or "")
        pronunciation:ClearFocus()
        tell(spelling and "Name pronunciation saved." or "Using your character's actual name.")
    end
    pronunciation:SetScript("OnEnterPressed", savePronunciation)
    button("Save", 520, 514, 51, savePronunciation)

    label("Voices I hear for friends", 369, 442)
    local friends = place(CreateFrame("DropdownButton", nil, frame, "WowStyle1DropdownTemplate"), 367, 461)
    friends:SetWidth(204)
    friends:SetDefaultText("Choose a character friend")
    friends:SetupMenu(function(_, menu)
        menu:SetScrollMode(240)
        local voices = ns.GetVoices()
        local count = C_FriendList and C_FriendList.GetNumFriends and C_FriendList.GetNumFriends()
        local added = false
        if not ns.IsSecret(count) and type(count) == "number" and C_FriendList.GetFriendInfoByIndex then
            for index = 1, count do
                local friend = C_FriendList.GetFriendInfoByIndex(index)
                if not ns.IsSecret(friend) and friend then
                    local guid, name = friend.guid, friend.name
                    if not ns.IsSecret(guid) and not ns.IsSecret(name) and guid and guid ~= "" and name then
                        local voice = db.friendVoices[guid]
                        local title = voice and (name .. " (" .. voice .. ")") or name
                        local choices = menu:CreateButton(title)
                        choices:SetScrollMode(240)
                        addVoiceChoices(choices, voices, "Use speaker preference", function(selectedVoice)
                            db.friendVoices[guid] = selectedVoice
                            tell(selectedVoice and ("Voice saved for " .. name .. ".") or ("Override cleared for " .. name .. "."))
                        end)
                        added = true
                    end
                end
            end
        end
        if not added then
            menu:CreateTitle("No character friends available")
        end
    end)

    label("Cooldown (s)", 380, 40, "GameFontHighlightSmall")
    local cooldown = input(462, 33, 40)
    cooldown:SetText(tostring(db.cooldown))
    local function saveCooldown()
        local value = wholeNumber(cooldown:GetText(), 300)
        if not value then
            tell("Enter a whole cooldown from 0 to 300 seconds.")
            return
        end
        db.cooldown = value
        cooldown:ClearFocus()
        tell("Cooldown saved for all abilities.")
    end
    cooldown:SetScript("OnEnterPressed", saveCooldown)
    button("Set", 513, 33, 56, saveCooldown)

    local selected
    local picker = place(CreateFrame("DropdownButton", nil, frame, "WowStyle1DropdownTemplate"), 16, 68)
    picker:SetWidth(300)
    local spell = input(76, 112, 80)
    local manual = check("Trigger by macro", 343, 112)
    local macro = label("", 18, 145, "GameFontHighlightSmall")
    local emoteChance = input(75, 165, 42)
    local speechChance = input(204, 165, 42)
    local silence = label("", 266, 172, "GameFontHighlightSmall")
    local emotes, speech = lineBox(18), lineBox(309)
    local delete

    label("Spell ID", 18, 118)
    label("Emote %", 18, 172)
    label("Speech %", 138, 172)
    label("Custom emotes (one per line)", 18, 203)
    label("Character speech (one per line)", 309, 203)

    local function updateChances()
        local emote = wholeNumber(emoteChance:GetText(), 100)
        local say = wholeNumber(speechChance:GetText(), 100)
        if emote and say and emote + say <= 100 then
            silence:SetText("Nothing " .. (100 - emote - say) .. "%")
        else
            silence:SetText("Emote and speech must total 100% or less.")
        end
        return emote, say
    end
    emoteChance:SetScript("OnTextChanged", updateChances)
    speechChance:SetScript("OnTextChanged", updateChances)

    local function updateMacro()
        local id = ns.SpellID(spell:GetText())
        local text = id and spellLabel(id) or "Enter an ID or capture your next successful cast."
        if id and manual:GetChecked() then
            text = text .. "   Macro command  /parlance fire " .. id
        end
        macro:SetText(text)
    end
    spell:SetScript("OnTextChanged", updateMacro)
    manual:SetScript("OnClick", updateMacro)

    local function loadRule(id)
        ns.OnCapture = nil
        selected = id
        local rule = db.rules[id]
        picker:SetDefaultText(rule and spellLabel(id) or "Select a saved ability")
        spell:SetText(id and tostring(id) or "")
        manual:SetChecked(rule and rule.manual or false)
        emoteChance:SetText(tostring(rule and rule.emoteChance or 0))
        speechChance:SetText(tostring(rule and rule.speechChance or 0))
        emotes:SetText(rule and table.concat(rule.emotes, "\n") or "")
        speech:SetText(rule and table.concat(rule.speech, "\n") or "")
        delete:SetEnabled(rule ~= nil)
        updateMacro()
        tell(rule and "Edit this ability and click Save rule." or "Add an ability, set its odds and enter your lines.")
    end

    picker:SetupMenu(function(_, menu)
        menu:SetScrollMode(240)
        local ids = {}
        for id in pairs(db.rules) do
            ids[#ids + 1] = id
        end
        table.sort(ids)
        if #ids == 0 then
            menu:CreateTitle("No saved abilities")
        end
        for _, id in ipairs(ids) do
            local ruleID = id
            menu:CreateButton(spellLabel(ruleID), function() loadRule(ruleID) end)
        end
    end)
    button("New ability", 327, 68, 108, function() loadRule(nil) end)
    button("Capture next cast", 174, 112, 150, function()
        spell:ClearFocus()
        ns.OnCapture = function(id)
            if id then
                spell:SetText(tostring(id))
                tell("Captured " .. spellLabel(id) .. ". Click Save rule when ready.")
            else
                tell("The cast ID was hidden. Try out of combat or enter an ID for a macro rule.")
            end
        end
        tell("Use the ability while this window stays open.")
    end)

    local function preview(kind, box)
        local lines, errorText = ns.Lines(box:GetText())
        if not lines or #lines == 0 then
            tell(errorText or "Enter a line to preview it.")
            return
        end
        ns.Preview(kind, lines[1], db.tts)
        tell("Previewed the first line locally.")
    end
    button("Preview emote", 18, 360, 112, function() preview("EMOTE", emotes) end)
    button("Preview speech", 136, 360, 112, function() preview("SAY", speech) end)
    delete = button("Delete rule", 351, 360, 100, function()
        db.rules[selected] = nil
        loadRule(nil)
        tell("Rule deleted.")
    end)
    button("Save rule", 459, 360, 112, function()
        local id = ns.SpellID(spell:GetText())
        local emote, say = updateChances()
        if not id then
            tell("Enter a valid spell ID or capture an ability.")
            return
        end
        if id ~= selected and db.rules[id] then
            tell("This ability already has a rule. Select it from the list to edit it.")
            return
        end
        if not emote or not say or emote + say > 100 then
            tell("Use whole percentages that add up to 100 or less.")
            return
        end
        local actions, actionError = ns.Lines(emotes:GetText())
        local words, wordsError = ns.Lines(speech:GetText())
        if not actions or not words then
            tell(actionError or wordsError)
            return
        end
        if (emote > 0 and #actions == 0) or (say > 0 and #words == 0) then
            tell("Add at least one line for each outcome with odds above zero.")
            return
        end
        if selected and selected ~= id then
            db.rules[selected] = nil
        end
        db.rules[id] = {
            manual = manual:GetChecked() and true or false,
            emoteChance = emote,
            speechChance = say,
            emotes = actions,
            speech = words,
        }
        loadRule(id)
        tell("Saved " .. spellLabel(id) .. " for this character.")
    end)
    loadRule(nil)
    return frame
end

function ns.OpenEditor(db)
    editor = editor or createEditor(db)
    if C_FriendList and C_FriendList.ShowFriends then
        C_FriendList.ShowFriends()
    end
    editor:Show()
end
