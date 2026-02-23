local addon, ns = ...

local core = CreateFrame("Frame", addon.."Core")
ns.core = core

local buttonName = addon.."_SpeedButton"
local bindingCommand = "CLICK "..buttonName..":LeftButton"
local db
local speedButton
local pendingRefresh

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
		local ghostWolf = getSpellNameIfKnown(2645)
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

function ns.refreshSpeedButton()
	if not speedButton then return end
	if InCombatLockdown() then
		pendingRefresh = true
		return
	end
	pendingRefresh = nil
	speedButton:SetAttribute("macrotext", buildMacro())
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
		}
		db = SpeedsterDB

		speedButton = CreateFrame("Button", buttonName, UIParent, "SecureActionButtonTemplate")
		speedButton:RegisterForClicks("AnyUp", "AnyDown")
		speedButton:SetAttribute("type", "macro")
		speedButton:SetAttribute("macrotext", "")
		speedButton:Hide()

		_G["BINDING_HEADER_SPEEDSTER"] = "Speedster"
		_G["BINDING_NAME_"..bindingCommand] = "Use speed macro"

		ns.refreshSpeedButton()
	elseif event == "PLAYER_REGEN_ENABLED" then
		if pendingRefresh then
			ns.refreshSpeedButton()
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
for _, eventName in ipairs({
	"LEARNED_SPELL_IN_TAB",
	"LEARNED_SPELL_IN_SPELLBOOK",
}) do
	pcall(core.RegisterEvent, core, eventName)
end
