local addon, ns = ...

local panel = CreateFrame("Frame", addon.."OptionsPanel")
panel.name = "Speedster"

local categoryID
local waitingForBind = false

local function normalizeBindingKey(key)
	if key == "LeftButton" then key = "BUTTON1" end
	if key == "RightButton" then key = "BUTTON2" end
	if key == "MiddleButton" then key = "BUTTON3" end

	if GetConvertedKeyOrButton then
		key = GetConvertedKeyOrButton(key)
	end
	if not key or key == "" then
		return
	end

	if IsKeyPressIgnoredForBinding and IsKeyPressIgnoredForBinding(key) then
		return
	end

	if CreateKeyChordStringUsingMetaKeyState then
		return CreateKeyChordStringUsingMetaKeyState(key)
	end

	local parts = {}
	if IsControlKeyDown and IsControlKeyDown() then
		parts[#parts + 1] = "CTRL"
	end
	if IsAltKeyDown and IsAltKeyDown() then
		parts[#parts + 1] = "ALT"
	end
	if IsShiftKeyDown and IsShiftKeyDown() then
		parts[#parts + 1] = "SHIFT"
	end
	parts[#parts + 1] = key
	return table.concat(parts, "-")
end

local function stopBindCapture()
	waitingForBind = false
	panel.bindButton:SetText("Bind Key")
	panel.bindCapture:Hide()
	panel.bindCapture:EnableKeyboard(false)
	panel.bindCapture:EnableMouse(false)
	if panel.bindCapture.SetPropagateKeyboardInput then
		panel.bindCapture:SetPropagateKeyboardInput(true)
	end
	if panel.bindCapture.SetPropagateMouseClicks then
		panel.bindCapture:SetPropagateMouseClicks(true)
	end
	if panel.bindCapture.SetPropagateMouseMotion then
		panel.bindCapture:SetPropagateMouseMotion(true)
	end
end

local function tryBindCapturedKey(rawKey)
	if rawKey == "ESCAPE" then
		stopBindCapture()
		print("Speedster: key binding canceled.")
		return
	end

	local bindKey = normalizeBindingKey(rawKey)
	if not bindKey then
		return
	end

	local ok, result = ns.bindKey(bindKey)
	if ok then
		print(("Speedster: bound speed macro to %s."):format(GetBindingText(result, "KEY_") or result))
	else
		print(("Speedster: %s"):format(result))
	end
	stopBindCapture()
	if ns.refreshOptions then
		ns.refreshOptions()
	end
end

local function createCheckButton(parent)
	local ok, btn = pcall(CreateFrame, "CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
	if not ok or not btn then
		btn = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	end
	if not btn.Text then
		btn.Text = btn:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
		btn.Text:SetPoint("LEFT", btn, "RIGHT", 2, 1)
	end
	return btn
end

local function isSpellKnownSafe(spellID)
	if C_SpellBook and C_SpellBook.IsSpellKnown then
		local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
		return C_SpellBook.IsSpellKnown(spellID, bank)
	end
	if IsSpellKnown then
		return IsSpellKnown(spellID)
	end
	if IsPlayerSpell then
		return IsPlayerSpell(spellID)
	end
	return false
end

local function hookHintTooltip(control)
	local function showHint(owner)
		if not control._speedsterHint then return end
		GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
		GameTooltip:SetText(control._speedsterHint, 1, 1, 1, 1, true)
		GameTooltip:Show()
	end
	local function hideHint(owner)
		if GameTooltip and GameTooltip:IsOwned(owner) then
			GameTooltip:Hide()
		end
	end

	control:HookScript("OnEnter", function(self)
		showHint(self)
	end)
	control:HookScript("OnLeave", function(self)
		hideHint(self)
	end)

	if not control._speedsterHintHotspot then
		local hotspot = CreateFrame("Frame", nil, control)
		hotspot:ClearAllPoints()
		hotspot:SetPoint("TOPLEFT", control, "TOPLEFT", 0, 0)
		if control.Text then
			hotspot:SetPoint("BOTTOMRIGHT", control.Text, "BOTTOMRIGHT", 2, 0)
		else
			hotspot:SetPoint("BOTTOMRIGHT", control, "BOTTOMRIGHT", 0, 0)
		end
		hotspot:EnableMouse(false)
		hotspot:Hide()
		hotspot:SetFrameLevel(control:GetFrameLevel() + 10)
		hotspot:SetScript("OnEnter", function(self)
			showHint(self)
		end)
		hotspot:SetScript("OnLeave", function(self)
			hideHint(self)
		end)
		control._speedsterHintHotspot = hotspot
	end
end

local function updateHintTooltipState(control)
	if not control or not control._speedsterHintHotspot then return end
	local active = control:IsShown() and (not control:IsEnabled()) and (type(control._speedsterHint) == "string") and control._speedsterHint ~= ""
	control._speedsterHintHotspot:SetShown(active)
	control._speedsterHintHotspot:EnableMouse(active)
	if not active and GameTooltip and GameTooltip:IsOwned(control._speedsterHintHotspot) then
		GameTooltip:Hide()
	end
end

local function createSectionHeader(parent, text, anchorFrame, offsetY)
	local header = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	header:SetPoint("TOPLEFT", anchorFrame, "BOTTOMLEFT", 0, offsetY or -16)
	header:SetText(text)
	return header
end

local function positionSectionHeader(header, anchorFrame, offsetY)
	header:ClearAllPoints()
	header:SetPoint("TOPLEFT", anchorFrame, "BOTTOMLEFT", 0, offsetY or -16)
end

local function refreshPanel()
	if not panel._built then return end
	if not SpeedsterDB then return end

	panel.enable:SetChecked(not not SpeedsterDB.enabled)
	panel.showMinimapButton:SetChecked(not not SpeedsterDB.show_minimap_button)
	panel.showFloatingButton:SetChecked(not not SpeedsterDB.show_floating_button)
	panel.druidTravel:SetChecked(not not SpeedsterDB.druid_use_travel)
	panel.shamanGhostWolf:SetChecked(not not SpeedsterDB.shaman_use_ghost_wolf)
	panel.cancelFormOnTaxi:SetChecked(not not SpeedsterDB.cancel_form_on_taxi)

	local _, classFile = UnitClass("player")
	local isDruid = classFile == "DRUID"
	local isShaman = classFile == "SHAMAN"
	local showClassSection = isDruid or isShaman

	if showClassSection then
		panel.classHeader:Show()
	else
		panel.classHeader:Hide()
	end
	if isDruid then
		panel.druidTravel:Show()
	else
		panel.druidTravel:Hide()
	end
	if isShaman then
		panel.shamanGhostWolf:Show()
	else
		panel.shamanGhostWolf:Hide()
	end

	local behaviorAnchor = panel.enable
	if showClassSection then
		if isDruid then
			local hasTravelOption = isSpellKnownSafe(783) or isSpellKnownSafe(33943) or isSpellKnownSafe(40120)
			panel.druidTravel:SetEnabled(hasTravelOption)
			panel.druidTravel._speedsterHint = hasTravelOption and nil or "Unlocks after learning Travel Form."
			panel.shamanGhostWolf:SetEnabled(false)
			panel.shamanGhostWolf._speedsterHint = nil
			behaviorAnchor = panel.druidTravel
		elseif isShaman then
			local hasGhostWolf = isSpellKnownSafe(2645)
			panel.shamanGhostWolf:SetEnabled(hasGhostWolf)
			panel.shamanGhostWolf._speedsterHint = hasGhostWolf and nil or "Unlocks after learning Ghost Wolf."
			panel.druidTravel:SetEnabled(false)
			panel.druidTravel._speedsterHint = nil
			behaviorAnchor = panel.shamanGhostWolf
		end
	else
		panel.druidTravel:SetEnabled(false)
		panel.shamanGhostWolf:SetEnabled(false)
		panel.druidTravel._speedsterHint = nil
		panel.shamanGhostWolf._speedsterHint = nil
	end
	updateHintTooltipState(panel.druidTravel)
	updateHintTooltipState(panel.shamanGhostWolf)

	positionSectionHeader(panel.behaviorHeader, behaviorAnchor, -14)

	if ns.getBindingText then
		panel.bindText:SetText("Current keybind: "..ns.getBindingText())
	end

	if ns.getMacro then
		local macro = ns.getMacro()
		if macro == "" then
			macro = "(No speed macro available yet for this class/level)"
		end
		panel.macroValue:SetText(macro)
	end
end
ns.refreshOptions = refreshPanel

local function ensureBuilt()
	if panel._built then return end
	panel._built = true

	-- Header
	local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 16, -16)
	title:SetText("Speedster")

	panel.logo = panel:CreateTexture(nil, "ARTWORK")
	panel.logo:SetSize(64, 64)
	panel.logo:SetPoint("TOPRIGHT", -20, -12)
	panel.logo:SetTexture("Interface\\AddOns\\Speedster\\textures\\Speedster")

	local subtitle = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
	subtitle:SetPoint("RIGHT", panel.logo, "LEFT", -10, 0)
	subtitle:SetJustifyH("LEFT")
	subtitle:SetText("Simple speed macro helper.")

	-- Section: General
	panel.generalHeader = createSectionHeader(panel, "General", subtitle, -20)

	panel.enable = createCheckButton(panel)
	panel.enable:SetPoint("TOPLEFT", panel.generalHeader, "BOTTOMLEFT", -2, -4)
	panel.enable.Text:SetText("Enable speed macro")
	panel.enable:SetScript("OnClick", function(btn)
		SpeedsterDB.enabled = btn:GetChecked() and true or false
		ns.refreshSpeedButton()
	end)

	-- Section: Class
	panel.classHeader = createSectionHeader(panel, "Class", panel.enable, -14)

	panel.druidTravel = createCheckButton(panel)
	panel.druidTravel:SetPoint("TOPLEFT", panel.classHeader, "BOTTOMLEFT", -2, -4)
	panel.druidTravel.Text:SetText("Druid: use Travel Form outdoors when known")
	panel.druidTravel:SetScript("OnClick", function(btn)
		SpeedsterDB.druid_use_travel = btn:GetChecked() and true or false
		ns.refreshSpeedButton()
	end)
	hookHintTooltip(panel.druidTravel)

	panel.shamanGhostWolf = createCheckButton(panel)
	panel.shamanGhostWolf:SetPoint("TOPLEFT", panel.classHeader, "BOTTOMLEFT", -2, -4)
	panel.shamanGhostWolf.Text:SetText("Shaman: use Ghost Wolf when known")
	panel.shamanGhostWolf:SetScript("OnClick", function(btn)
		SpeedsterDB.shaman_use_ghost_wolf = btn:GetChecked() and true or false
		ns.refreshSpeedButton()
	end)
	hookHintTooltip(panel.shamanGhostWolf)

	-- Section: Behavior
	panel.behaviorHeader = createSectionHeader(panel, "Behavior", panel.druidTravel, -14)

	panel.cancelFormOnTaxi = createCheckButton(panel)
	panel.cancelFormOnTaxi:SetPoint("TOPLEFT", panel.behaviorHeader, "BOTTOMLEFT", -2, -4)
	panel.cancelFormOnTaxi.Text:SetText("Auto-cancel shapeshift form when using a flight master")
	panel.cancelFormOnTaxi:SetScript("OnClick", function(btn)
		SpeedsterDB.cancel_form_on_taxi = btn:GetChecked() and true or false
	end)

	-- Section: Buttons
	panel.buttonsHeader = createSectionHeader(panel, "Buttons", panel.cancelFormOnTaxi, -14)

	panel.showMinimapButton = createCheckButton(panel)
	panel.showMinimapButton:SetPoint("TOPLEFT", panel.buttonsHeader, "BOTTOMLEFT", -2, -4)
	panel.showMinimapButton.Text:SetText("Show minimap button")
	panel.showMinimapButton:SetScript("OnClick", function(btn)
		SpeedsterDB.show_minimap_button = btn:GetChecked() and true or false
		ns.refreshSpeedButton()
	end)

	panel.showFloatingButton = createCheckButton(panel)
	panel.showFloatingButton:SetPoint("TOPLEFT", panel.showMinimapButton, "BOTTOMLEFT", 0, -4)
	panel.showFloatingButton.Text:SetText("Show floating on-screen button")
	panel.showFloatingButton:SetScript("OnClick", function(btn)
		SpeedsterDB.show_floating_button = btn:GetChecked() and true or false
		ns.refreshSpeedButton()
	end)

	panel.resetFloatingPosButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	panel.resetFloatingPosButton:SetSize(220, 22)
	panel.resetFloatingPosButton:SetPoint("TOPLEFT", panel.showFloatingButton, "BOTTOMLEFT", 2, -8)
	panel.resetFloatingPosButton:SetText("Reset Floating Button Position")
	panel.resetFloatingPosButton:SetScript("OnClick", function()
		if not ns.resetFloatingButtonPosition then
			print("Speedster: floating button is not ready yet.")
			return
		end
		local ok, reason = ns.resetFloatingButtonPosition()
		if ok then
			print("Speedster: floating button position reset.")
		elseif reason then
			print("Speedster: "..reason)
		end
	end)

	-- Section: Keybind
	local keybindHeader = createSectionHeader(panel, "Keybind", panel.resetFloatingPosButton, -14)

	panel.bindButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	panel.bindButton:SetSize(220, 22)
	panel.bindButton:SetPoint("TOPLEFT", keybindHeader, "BOTTOMLEFT", 0, -8)
	panel.bindButton:SetText("Bind Key")
	panel.bindButton:SetScript("OnClick", function()
		if waitingForBind then
			stopBindCapture()
			return
		end
		waitingForBind = true
		panel.bindButton:SetText("Press a key... (Esc to cancel)")
		panel.bindCapture:Show()
		panel.bindCapture:EnableKeyboard(true)
		panel.bindCapture:EnableMouse(true)
		if panel.bindCapture.SetPropagateKeyboardInput then
			panel.bindCapture:SetPropagateKeyboardInput(false)
		end
		if panel.bindCapture.SetPropagateMouseClicks then
			panel.bindCapture:SetPropagateMouseClicks(false)
		end
		if panel.bindCapture.SetPropagateMouseMotion then
			panel.bindCapture:SetPropagateMouseMotion(false)
		end
	end)

	panel.bindCapture = CreateFrame("Frame", nil, panel)
	panel.bindCapture:SetAllPoints(panel)
	panel.bindCapture:EnableKeyboard(false)
	panel.bindCapture:EnableMouse(false)
	panel.bindCapture:EnableMouseWheel(true)
	if panel.bindCapture.SetPropagateKeyboardInput then
		panel.bindCapture:SetPropagateKeyboardInput(true)
	end
	if panel.bindCapture.SetPropagateMouseClicks then
		panel.bindCapture:SetPropagateMouseClicks(true)
	end
	if panel.bindCapture.SetPropagateMouseMotion then
		panel.bindCapture:SetPropagateMouseMotion(true)
	end
	panel.bindCapture:Hide()
	panel.bindCapture:SetScript("OnKeyDown", function(_, key)
		tryBindCapturedKey(key)
	end)
	panel.bindCapture:SetScript("OnMouseDown", function(_, button)
		tryBindCapturedKey(button)
	end)
	panel.bindCapture:SetScript("OnMouseWheel", function(_, delta)
		tryBindCapturedKey(delta > 0 and "MOUSEWHEELUP" or "MOUSEWHEELDOWN")
	end)

	panel.bindText = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	panel.bindText:SetPoint("TOPLEFT", panel.bindButton, "BOTTOMLEFT", 0, -8)
	panel.bindText:SetJustifyH("LEFT")
	panel.bindText:SetText("Current keybind: "..NOT_BOUND)

	-- Current macro
	panel.macroLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	panel.macroLabel:SetPoint("TOPLEFT", panel.bindText, "BOTTOMLEFT", 0, -16)
	panel.macroLabel:SetJustifyH("LEFT")
	panel.macroLabel:SetText("Current macro:")

	panel.macroValue = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	panel.macroValue:SetPoint("TOPLEFT", panel.macroLabel, "BOTTOMLEFT", 0, -4)
	panel.macroValue:SetPoint("RIGHT", panel, -16, 0)
	panel.macroValue:SetJustifyH("LEFT")
	panel.macroValue:SetJustifyV("TOP")
	panel.macroValue:SetNonSpaceWrap(true)
	panel.macroValue:SetText("")

	panel.help = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	panel.help:SetPoint("TOPLEFT", panel.macroValue, "BOTTOMLEFT", 0, -10)
	panel.help:SetPoint("RIGHT", panel, -16, 0)
	panel.help:SetJustifyH("LEFT")
	panel.help:SetText(
		"Click 'Bind Key', then press your next key/button.\n"
		.."/speedster - Open Speedster options\n"
		.."/speedsterbind [KEY] - Bind speed macro to key (blank = NUMPADMINUS)\n"
		.."/speedstermacro - Print current generated macro"
	)
end

panel:SetScript("OnShow", function()
	ensureBuilt()
	refreshPanel()
end)
panel:HookScript("OnHide", function()
	if waitingForBind then
		stopBindCapture()
	end
end)

local function registerPanel()
	if panel._registered then return end

	if Settings
	and type(Settings.RegisterCanvasLayoutCategory) == "function"
	and type(Settings.RegisterAddOnCategory) == "function"
	then
		local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name, panel.name)
		if category then
			categoryID = category:GetID()
			panel.category = category
			Settings.RegisterAddOnCategory(category)
			panel._registered = true
			return
		end
	end

	if type(InterfaceOptions_AddCategory) == "function" then
		InterfaceOptions_AddCategory(panel)
		panel._registered = true
	end
end

function ns.showOptions()
	registerPanel()
	ensureBuilt()
	refreshPanel()

	if Settings and Settings.OpenToCategory and categoryID then
		Settings.OpenToCategory(categoryID)
		Settings.OpenToCategory(categoryID)
	elseif InterfaceOptionsFrame_OpenToCategory then
		InterfaceOptionsFrame_OpenToCategory(panel)
		InterfaceOptionsFrame_OpenToCategory(panel)
	else
		panel:Show()
	end
end

registerPanel()
