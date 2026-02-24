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

local function refreshPanel()
	if not panel._built then return end
	if not SpeedsterDB then return end

	panel.enable:SetChecked(not not SpeedsterDB.enabled)
	panel.druidTravel:SetChecked(not not SpeedsterDB.druid_use_travel)

	local _, classFile = UnitClass("player")
	panel.druidTravel:SetEnabled(classFile == "DRUID")

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

	panel.enable = createCheckButton(panel)
	panel.enable:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", -2, -18)
	panel.enable.Text:SetText("Enable speed macro")
	panel.enable:SetScript("OnClick", function(btn)
		SpeedsterDB.enabled = btn:GetChecked() and true or false
		ns.refreshSpeedButton()
	end)

	panel.druidTravel = createCheckButton(panel)
	panel.druidTravel:SetPoint("TOPLEFT", panel.enable, "BOTTOMLEFT", 0, -8)
	panel.druidTravel.Text:SetText("Druid: use Travel Form outdoors when known")
	panel.druidTravel:SetScript("OnClick", function(btn)
		SpeedsterDB.druid_use_travel = btn:GetChecked() and true or false
		ns.refreshSpeedButton()
	end)

	panel.bindButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	panel.bindButton:SetSize(220, 22)
	panel.bindButton:SetPoint("TOPLEFT", panel.druidTravel, "BOTTOMLEFT", 2, -14)
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
	panel.bindText:SetPoint("TOPLEFT", panel.bindButton, "BOTTOMLEFT", 0, -10)
	panel.bindText:SetJustifyH("LEFT")
	panel.bindText:SetText("Current keybind: "..NOT_BOUND)

	panel.macroLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	panel.macroLabel:SetPoint("TOPLEFT", panel.bindText, "BOTTOMLEFT", 0, -12)
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
