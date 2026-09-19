local addonName, ns = ...

local function yesNo(value) return value and "yes" or "no" end

local function framePoint(frame)
    if not frame or not frame.GetPoint then return "not created" end
    local point, relativeTo, relativePoint, x, y = frame:GetPoint(1)
    return table.concat({ tostring(point or "?"), tostring(relativeTo and relativeTo:GetName() or "?"),
        tostring(relativePoint or "?"), string.format("%.1f", x or 0), string.format("%.1f", y or 0) }, " ")
end

function ns.BuildDiagnosticReport()
    local interface
    if GetBuildInfo then
        local ok, _, _, _, value = pcall(GetBuildInfo)
        if ok then interface = value end
    end
    local db = ns.db or SpeedsterDB or {}
    local minimap = _G[addonName .. "MinimapButton"]
    local floating = _G[addonName .. "FloatingButton"]
    local lines = {
        "Speedster diagnostics",
        "Version: " .. tostring(ns.addonMetadata and ns.addonMetadata("Version") or "unknown"),
        "Interface: " .. tostring(interface or "unknown"),
        "Target: " .. tostring(ns.addonMetadata and ns.addonMetadata("X-Speedster-Target") or "Retail"),
        "Database: " .. (ns.dbWasFresh and "created this load" or type(ns.db) == "table" and "loaded" or "unavailable"),
        "Enabled: " .. yesNo(db.enabled),
        "Class: " .. tostring(select(2, UnitClass("player")) or "unknown"),
        "Primary binding: " .. tostring(ns.getBindingText and ns.getBindingText() or "unknown"),
        "Utility actions exposed: " .. tostring(#(ns.getUtilityActionIDs and ns.getUtilityActionIDs() or {})),
        "Minimap shown: " .. yesNo(db.show_minimap_button),
        "Minimap stored angle: " .. tostring(db.minimap_angle or "none"),
        "Minimap visible: " .. yesNo(minimap and minimap:IsShown()),
        "Minimap point: " .. framePoint(minimap),
        "Floating button shown: " .. yesNo(db.show_floating_button),
        "Floating button point: " .. framePoint(floating),
        "Combat lockdown: " .. yesNo(InCombatLockdown and InCombatLockdown()),
        "Report privacy: no character name or macro text included; configured keybindings are included.",
    }
    return table.concat(lines, "\n")
end

local dialog
function ns.ShowDiagnosticReport()
    if not dialog then
        dialog = CreateFrame("Frame", "SpeedsterCopyReport", UIParent, "BackdropTemplate")
        dialog:SetSize(640, 360); dialog:SetPoint("CENTER"); dialog:SetFrameStrata("FULLSCREEN_DIALOG")
        dialog:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12 })
        dialog:SetBackdropColor(0.035, 0.035, 0.04, 0.98); dialog:SetBackdropBorderColor(0.58, 0.43, 0.22, 1); dialog:EnableMouse(true)
        local title = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge"); title:SetPoint("TOPLEFT", 18, -16); title:SetText("Copy Speedster report")
        local help = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); help:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -5); help:SetText("Press Ctrl+C, then Escape.")
        local scroll = CreateFrame("ScrollFrame", nil, dialog, "UIPanelScrollFrameTemplate"); scroll:SetPoint("TOPLEFT", 18, -66); scroll:SetPoint("BOTTOMRIGHT", -38, 44)
        local edit = CreateFrame("EditBox", nil, scroll); edit:SetMultiLine(true); edit:SetAutoFocus(false); edit:SetFontObject(ChatFontNormal); edit:SetWidth(565); edit:SetHeight(800); edit:SetTextInsets(4, 4, 4, 4); edit:SetScript("OnEscapePressed", function() dialog:Hide() end); scroll:SetScrollChild(edit); dialog.edit = edit
        local close = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate"); close:SetSize(90, 22); close:SetPoint("BOTTOMRIGHT", -18, 14); close:SetText("Close"); close:SetScript("OnClick", function() dialog:Hide() end)
    end
    dialog.edit:SetText(ns.BuildDiagnosticReport()); dialog:Show(); dialog.edit:SetFocus(); dialog.edit:HighlightText()
end
