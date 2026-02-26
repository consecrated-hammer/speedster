local addon, ns = ...

local core = CreateFrame("Frame", addon.."Core")
ns.core = core

local buttonName = addon.."_SpeedButton"
local bindingCommand = "CLICK "..buttonName..":LeftButton"
local db
local speedButton
local minimapButton
local floatingButton
local pendingRefresh
local pendingFloatingReset
local MINIMAP_RADIUS = 80
local FLOATING_BUTTON_SIZE = 36
local ICON_PATH = "Interface\\AddOns\\Speedster\\textures\\Speedster.png"
local FALLBACK_ICON_PATH = "Interface\\Icons\\INV_Misc_QuestionMark"
local taxiSecureOverlays = {}
local warnedTaxiCancelFailure

local function cancelShapeshiftForTaxi()
	if not (db and db.cancel_form_on_taxi) then return end
	if InCombatLockdown and InCombatLockdown() then return end

	if CancelShapeshiftForm then
		local ok, err = pcall(CancelShapeshiftForm)
		if not ok and not warnedTaxiCancelFailure then
			warnedTaxiCancelFailure = true
			print(("Speedster: taxi auto-cancel failed (%s)."):format(tostring(err)))
		end
	end
	if CancelForm then
		local ok, err = pcall(CancelForm)
		if not ok and not warnedTaxiCancelFailure then
			warnedTaxiCancelFailure = true
			print(("Speedster: taxi auto-cancel failed (%s)."):format(tostring(err)))
		end
	end
end

local function ensureTaxiSecureOverlay(targetButton)
	if not targetButton then return end
	local buttonName = targetButton:GetName()
	if not buttonName then return end

	local overlay = taxiSecureOverlays[targetButton]
	if not overlay then
		overlay = CreateFrame("Button", buttonName.."_SpeedsterTaxiOverlay", UIParent, "SecureActionButtonTemplate")
		overlay:RegisterForClicks("AnyUp", "AnyDown")
		overlay:EnableMouse(true)
		overlay:SetFrameLevel(1000)
		overlay:SetScript("OnEnter", function()
			local onEnter = targetButton:GetScript("OnEnter")
			if onEnter then
				onEnter(targetButton)
			end
		end)
		overlay:SetScript("OnLeave", function()
			local onLeave = targetButton:GetScript("OnLeave")
			if onLeave then
				onLeave(targetButton)
			end
		end)
		taxiSecureOverlays[targetButton] = overlay
	end

	overlay:SetAttribute("type", "macro")
	overlay:SetAttribute("macrotext", "/stand\n/dismount\n/cancelform\n/click "..buttonName)
	overlay:SetParent(UIParent)
	overlay:ClearAllPoints()
	overlay:SetFrameStrata("TOOLTIP")

	if targetButton:IsVisible() then
		local bW, bH = targetButton:GetSize()
		local uiScale = UIParent:GetEffectiveScale()
		local btnScale = targetButton:GetEffectiveScale()
		if uiScale and uiScale > 0 and btnScale and btnScale > 0 then
			overlay:SetSize(
				math.max(16, (bW or 0) * (btnScale / uiScale)),
				math.max(16, (bH or 0) * (btnScale / uiScale))
			)

			local positioned
			if buttonName:find("^TaxiButton") and TaxiRouteMap and TaxiNodePosition and targetButton.GetID then
				local nodeID = targetButton:GetID()
				if nodeID then
					local tx, ty = TaxiNodePosition(nodeID)
					local mapW, mapH = 316, 352
					if tx and ty then
						overlay:SetPoint("CENTER", TaxiRouteMap, "TOPLEFT", tx * mapW, -(ty * mapH))
						positioned = true
					end
				end
			end

			if not positioned and TaxiRouteMap and targetButton:IsObjectType("Button") and buttonName:find("^TaxiButton") then
				local left, top = TaxiRouteMap:GetLeft(), TaxiRouteMap:GetTop()
				local mapScale = TaxiRouteMap:GetEffectiveScale()
				local cX, cY = targetButton:GetCenter()
				if left and top and mapScale and cX and cY then
					local x = ((cX * btnScale) / uiScale)
					local y = ((cY * btnScale) / uiScale)
					overlay:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
					positioned = true
				end
			end

			if not positioned then
				local cX, cY = targetButton:GetCenter()
				if cX and cY then
					overlay:SetPoint("CENTER", UIParent, "BOTTOMLEFT", (cX * btnScale) / uiScale, (cY * btnScale) / uiScale)
					positioned = true
				end
			end

			if positioned then
				overlay:Show()
			else
				overlay:Hide()
			end
		end
	else
		overlay:Hide()
	end
end

local function refreshTaxiSecureOverlays()
	for targetButton, _ in pairs(taxiSecureOverlays) do
		if targetButton and targetButton.GetName then
			ensureTaxiSecureOverlay(targetButton)
		end
	end
end

local function setupTaxiSecureOverlays()
	if not (db and db.cancel_form_on_taxi) then return end
	if InCombatLockdown and InCombatLockdown() then return end

	for i = 1, 64 do
		ensureTaxiSecureOverlay(_G["TaxiButton"..i])
	end
	for i = 1, 32 do
		ensureTaxiSecureOverlay(_G["GossipTitleButton"..i])
	end

	if C_Timer and C_Timer.After then
		C_Timer.After(0, refreshTaxiSecureOverlays)
		C_Timer.After(0.1, refreshTaxiSecureOverlays)
		C_Timer.After(0.5, refreshTaxiSecureOverlays)
	end
end

local function hideTaxiSecureOverlays()
	for _, overlay in pairs(taxiSecureOverlays) do
		if overlay and overlay.Hide then
			overlay:Hide()
		end
	end
end

local function trim(text)
	if type(text) ~= "string" then return "" end
	return (text:gsub("^%s+", ""):gsub("%s+$", ""))
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

local function getSpellNameIfKnown(spellID)
	if not isSpellKnownSafe(spellID) then return end
	local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellID)
	if not name then
		name = GetSpellInfo(spellID)
	end
	return name
end

local function buildMacro()
	if not db or not db.enabled then return "" end

	local _, classFile = UnitClass("player")
	if classFile == "DRUID" then
		local cat = getSpellNameIfKnown(768)
		if not cat then return "" end

		local aquatic = getSpellNameIfKnown(1066)
		local travel = db.druid_use_travel and getSpellNameIfKnown(783) or nil
		local flight = db.druid_use_travel and (getSpellNameIfKnown(40120) or getSpellNameIfKnown(33943)) or nil

		if travel then
			local air = flight or travel
			if aquatic then
				return ("/cast [swimming]!%s;[indoors]!%s;[flyable,nocombat]!%s;!%s"):format(aquatic, cat, air, travel)
			end
			return ("/cast [indoors]!%s;[flyable,nocombat]!%s;!%s"):format(cat, air, travel)
		end

		if aquatic then
			return ("/cast [swimming]!%s;!%s"):format(aquatic, cat)
		end
		return "/cast !"..cat
	end

	if classFile == "SHAMAN" then
		local ghostWolf = db.shaman_use_ghost_wolf and getSpellNameIfKnown(2645) or nil
		if ghostWolf then return "/cast !"..ghostWolf end
	elseif classFile == "HUNTER" then
		local cheetah = getSpellNameIfKnown(5118)
		if cheetah then return "/cast !"..cheetah end
	elseif classFile == "ROGUE" then
		local sprint = getSpellNameIfKnown(2983)
		if sprint then return "/cast "..sprint end
	elseif classFile == "MAGE" then
		local blink = getSpellNameIfKnown(1953)
		if blink then return "/cast "..blink end
	end

	return ""
end

ns.getMacro = buildMacro

local function applyFloatingButtonPosition()
	if not floatingButton or not db then return end

	floatingButton:ClearAllPoints()
	if type(db.floating_button_point) == "table" and db.floating_button_point.point and db.floating_button_point.relativePoint then
		floatingButton:SetPoint(
			db.floating_button_point.point,
			UIParent,
			db.floating_button_point.relativePoint,
			db.floating_button_point.x or 0,
			db.floating_button_point.y or 0
		)
	else
		floatingButton:SetPoint("CENTER", UIParent, "CENTER", 0, -120)
	end
end

local function saveFloatingButtonPosition()
	if not floatingButton or not db then return end
	local point, _, relativePoint, x, y = floatingButton:GetPoint(1)
	if not point or not relativePoint then return end
	db.floating_button_point = {
		point = point,
		relativePoint = relativePoint,
		x = x or 0,
		y = y or 0,
	}
end

function ns.resetFloatingButtonPosition()
	if not db then
		return false, "settings are not ready yet"
	end

	db.floating_button_point = nil
	if not floatingButton then
		return true
	end
	if InCombatLockdown() then
		pendingFloatingReset = true
		return false, SPELL_FAILED_AFFECTING_COMBAT
	end

	applyFloatingButtonPosition()
	return true
end

local function createMinimapButton()
	minimapButton = CreateFrame("Button", addon.."MinimapButton", Minimap)
	minimapButton:SetSize(31, 31)
	minimapButton:SetFrameStrata("MEDIUM")
	minimapButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
	minimapButton:GetHighlightTexture():SetBlendMode("ADD")

	local bg = minimapButton:CreateTexture(nil, "BACKGROUND")
	bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
	bg:SetAllPoints()

	local icon = minimapButton:CreateTexture(nil, "ARTWORK")
	icon:SetPoint("TOPLEFT", minimapButton, "TOPLEFT", 7, -7)
	icon:SetPoint("BOTTOMRIGHT", minimapButton, "BOTTOMRIGHT", -7, 7)
	icon:SetTexture(ICON_PATH)
	if not icon:GetTexture() then
		icon:SetTexture(FALLBACK_ICON_PATH)
	end
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	minimapButton.icon = icon

	local border = minimapButton:CreateTexture(nil, "OVERLAY")
	border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	border:SetSize(54, 54)
	border:SetPoint("TOPLEFT")

	local function setMinimapButtonPosition(angle)
		local radians = math.rad(angle or 225)
		local x = math.cos(radians) * MINIMAP_RADIUS
		local y = math.sin(radians) * MINIMAP_RADIUS
		minimapButton:ClearAllPoints()
		minimapButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
	end

	local function updateMinimapButtonFromCursor()
		local scale = Minimap:GetEffectiveScale()
		local cursorX, cursorY = GetCursorPosition()
		cursorX = cursorX / scale
		cursorY = cursorY / scale
		local centerX, centerY = Minimap:GetCenter()
		if not centerX or not centerY then return end

		local angle = math.deg(math.atan(cursorY - centerY, cursorX - centerX))
		db.minimap_angle = angle
		setMinimapButtonPosition(angle)
	end

	minimapButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	minimapButton:RegisterForDrag("LeftButton")
	minimapButton:SetScript("OnDragStart", function(self)
		self._dragging = true
		self:SetScript("OnUpdate", updateMinimapButtonFromCursor)
	end)
	minimapButton:SetScript("OnDragStop", function(self)
		self:SetScript("OnUpdate", nil)
		self._dragging = nil
		self._wasDragged = true
	end)
	minimapButton:SetScript("OnClick", function(_, button)
		if minimapButton._wasDragged then
			minimapButton._wasDragged = nil
			return
		end
		if button == "LeftButton" or button == "RightButton" then
			ns.openOptions()
		end
	end)
	minimapButton:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:SetText("Speedster")
		GameTooltip:AddLine("Click: open options", 0.85, 0.85, 0.85)
		GameTooltip:AddLine("Drag: move minimap icon", 0.85, 0.85, 0.85)
		GameTooltip:Show()
	end)
	minimapButton:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	setMinimapButtonPosition(db.minimap_angle or 225)
end

local function createFloatingButton()
	floatingButton = CreateFrame("Button", addon.."FloatingButton", UIParent, "ActionButtonTemplate, SecureActionButtonTemplate, SecureHandlerBaseTemplate")
	floatingButton:SetSize(FLOATING_BUTTON_SIZE, FLOATING_BUTTON_SIZE)
	floatingButton:SetMovable(true)
	floatingButton:SetClampedToScreen(true)
	floatingButton:EnableMouse(true)
	floatingButton:RegisterForClicks("AnyUp", "AnyDown")
	floatingButton:SetAttribute("type", "macro")
	floatingButton:SetAttribute("macrotext", "")
	floatingButton:SetAttribute("shift-type1", "")
	local frameName = floatingButton:GetName()
	local icon = _G[frameName.."Icon"]
	if not icon then
		icon = floatingButton:CreateTexture(nil, "ARTWORK")
		icon:SetPoint("TOPLEFT", floatingButton, "TOPLEFT", 6, -6)
		icon:SetPoint("BOTTOMRIGHT", floatingButton, "BOTTOMRIGHT", -6, 6)
	end
	icon:SetTexture(ICON_PATH)
	if not icon:GetTexture() then
		icon:SetTexture(FALLBACK_ICON_PATH)
	end
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	icon:SetVertexColor(0.95, 0.95, 0.95)
	floatingButton.icon = icon

	local hotKey = _G[frameName.."HotKey"]
	if hotKey then
		hotKey:Hide()
	end
	local nameText = _G[frameName.."Name"]
	if nameText then
		nameText:Hide()
	end
	local countText = _G[frameName.."Count"]
	if countText then
		countText:Hide()
	end

	floatingButton:SetScript("OnMouseDown", function(self, button)
		if button ~= "LeftButton" then return end
		if InCombatLockdown() or not IsShiftKeyDown() then return end
		self._isDragging = true
		self:StartMoving()
	end)
	floatingButton:SetScript("OnMouseUp", function(self)
		if not self._isDragging then return end
		self._isDragging = nil
		self:StopMovingOrSizing()
		saveFloatingButtonPosition()
	end)
	floatingButton:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText("Speedster")
		GameTooltip:AddLine("Left-click: use speed macro", 0.85, 0.85, 0.85)
		GameTooltip:AddLine("Shift + left-drag: move button", 0.85, 0.85, 0.85)
		GameTooltip:Show()
	end)
	floatingButton:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	applyFloatingButtonPosition()
end

function ns.refreshSpeedButton()
	if not speedButton then return end
	if InCombatLockdown() then
		pendingRefresh = true
		return
	end
	pendingRefresh = nil
	local macroText = buildMacro()
	speedButton:SetAttribute("macrotext", macroText)
	if floatingButton then
		floatingButton:SetAttribute("macrotext", macroText)
		floatingButton:SetShown(not not db.show_floating_button)
	end
	if minimapButton then
		minimapButton:SetShown(not not db.show_minimap_button)
	end
	if ns.refreshOptions then
		ns.refreshOptions()
	end
end

function ns.getBindingText()
	local key1, key2 = GetBindingKey(bindingCommand)
	if key1 and key2 then
		return ("%s, %s"):format(GetBindingText(key1, "KEY_") or key1, GetBindingText(key2, "KEY_") or key2)
	elseif key1 then
		return GetBindingText(key1, "KEY_") or key1
	end
	return NOT_BOUND
end

function ns.bindKey(keyText)
	if InCombatLockdown() then
		return false, SPELL_FAILED_AFFECTING_COMBAT
	end

	local key = trim(keyText)
	if key == "" then
		key = "NUMPADMINUS"
	end
	key = key:upper()

	local oldAction = GetBindingAction(key)
	local oldKey = GetBindingKey(bindingCommand)
	if oldAction ~= "" and oldAction ~= bindingCommand then
		print(("Speedster: '%s' replaced previous binding '%s'."):format(key, GetBindingName(oldAction) or oldAction))
	end

	if not SetBinding(key, bindingCommand) then
		return false, "failed to set binding"
	end

	if oldKey and oldKey ~= key then
		SetBinding(oldKey, nil)
	end

	SaveBindings(GetCurrentBindingSet())
	if ns.refreshOptions then
		ns.refreshOptions()
	end
	return true, key
end

function ns.openOptions()
	if ns.showOptions then
		ns.showOptions()
	else
		print("Speedster: options are not ready yet.")
	end
end

SLASH_SPEEDSTER1 = "/speedster"
SlashCmdList["SPEEDSTER"] = ns.openOptions

SLASH_SPEEDSTER_BIND1 = "/speedsterbind"
SlashCmdList["SPEEDSTER_BIND"] = function(msg)
	local ok, result = ns.bindKey(msg)
	if ok then
		print(("Speedster: bound speed macro to %s."):format(GetBindingText(result, "KEY_") or result))
	else
		print(("Speedster: %s"):format(result))
	end
end

SLASH_SPEEDSTER_MACRO1 = "/speedstermacro"
SlashCmdList["SPEEDSTER_MACRO"] = function()
	local macro = buildMacro()
	if macro == "" then
		print("Speedster: no speed macro available for current class/level.")
	else
		print("Speedster macro:")
		print(macro)
	end
end

core:SetScript("OnEvent", function(_, event, ...)
	if event == "ADDON_LOADED" then
		local addonName = ...
		if addonName ~= addon then return end

		if type(SpeedsterDB) ~= "table" then
			SpeedsterDB = nil
		end

		SpeedsterDB = SpeedsterDB or {
			enabled = true,
			druid_use_travel = true,
			shaman_use_ghost_wolf = true,
			show_minimap_button = true,
			show_floating_button = true,
			cancel_form_on_taxi = true,
		}
		db = SpeedsterDB
		if db.show_minimap_button == nil then
			db.show_minimap_button = true
		end
		if db.show_floating_button == nil then
			db.show_floating_button = true
		end
		if db.minimap_angle == nil then
			db.minimap_angle = 225
		end
		if db.cancel_form_on_taxi == nil then
			db.cancel_form_on_taxi = true
		end
		if db.shaman_use_ghost_wolf == nil then
			db.shaman_use_ghost_wolf = true
		end

		speedButton = CreateFrame("Button", buttonName, UIParent, "SecureActionButtonTemplate")
		speedButton:RegisterForClicks("AnyUp", "AnyDown")
		speedButton:SetAttribute("type", "macro")
		speedButton:SetAttribute("macrotext", "")
		speedButton:Hide()
		createMinimapButton()
		createFloatingButton()

		_G["BINDING_HEADER_SPEEDSTER"] = "Speedster"
		_G["BINDING_NAME_"..bindingCommand] = "Use speed macro"

		ns.refreshSpeedButton()
	elseif event == "PLAYER_REGEN_ENABLED" then
		if pendingFloatingReset then
			pendingFloatingReset = nil
			applyFloatingButtonPosition()
		end
		if pendingRefresh then
			ns.refreshSpeedButton()
		end
	elseif event == "TAXIMAP_OPENED"
	or event == "TAXI_SHOW"
	or event == "GOSSIP_SHOW" then
		setupTaxiSecureOverlays()
		cancelShapeshiftForTaxi()
		if C_Timer and C_Timer.After then
			C_Timer.After(0, cancelShapeshiftForTaxi)
		end
	elseif event == "TAXIMAP_CLOSED"
	or event == "GOSSIP_CLOSED" then
		hideTaxiSecureOverlays()
	elseif event == "UI_ERROR_MESSAGE" then
		local arg1, arg2 = ...
		if arg1 == ERR_TAXIPLAYERSHAPESHIFTED or arg2 == ERR_TAXIPLAYERSHAPESHIFTED then
			cancelShapeshiftForTaxi()
			if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.editBox and ChatEdit_SendText then
				DEFAULT_CHAT_FRAME.editBox:SetText("/cancelform")
				pcall(ChatEdit_SendText, DEFAULT_CHAT_FRAME.editBox, 0)
			end
		end
	elseif event == "SPELLS_CHANGED"
	or event == "LEARNED_SPELL_IN_TAB"
	or event == "LEARNED_SPELL_IN_SPELLBOOK" then
		ns.refreshSpeedButton()
	end
end)

core:RegisterEvent("ADDON_LOADED")
core:RegisterEvent("PLAYER_REGEN_ENABLED")
core:RegisterEvent("SPELLS_CHANGED")
core:RegisterEvent("TAXIMAP_OPENED")
pcall(core.RegisterEvent, core, "TAXI_SHOW")
pcall(core.RegisterEvent, core, "TAXIMAP_CLOSED")
pcall(core.RegisterEvent, core, "GOSSIP_SHOW")
pcall(core.RegisterEvent, core, "GOSSIP_CLOSED")
pcall(core.RegisterEvent, core, "UI_ERROR_MESSAGE")
for _, eventName in ipairs({
	"LEARNED_SPELL_IN_TAB",
	"LEARNED_SPELL_IN_SPELLBOOK",
}) do
	pcall(core.RegisterEvent, core, eventName)
end
