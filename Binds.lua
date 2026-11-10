-- Keys: override bindings (SetOverrideBinding), taking over the original keys, bind mode.
--
-- Override bindings are not saved into the game's settings, so the original keys stay
-- untouched once the addon is turned off. They are saved in the profile instead:
-- keys[slot] = { key, key }.

local M = BetterBartender

-- The game's commands for the original bars, and each bar's first slot minus one.
local ORIGINAL_KEYS = {
	{ command = "ACTIONBUTTON", offset = 0 },
	{ command = "MULTIACTIONBAR1BUTTON", offset = 60 },
	{ command = "MULTIACTIONBAR2BUTTON", offset = 48 },
	{ command = "MULTIACTIONBAR3BUTTON", offset = 24 },
	{ command = "MULTIACTIONBAR4BUTTON", offset = 36 },
}

function M:ImportKeys()
	local keys = {}
	for _, source in ipairs(ORIGINAL_KEYS) do
		for i = 1, 12 do
			local found = { GetBindingKey(source.command .. i) }
			if #found > 0 then keys[source.offset + i] = found end
		end
	end
	return keys
end

local owner = CreateFrame("Frame", "BetterBartenderBindOwner")
-- A button that does nothing: a key taken off a slot must not keep pressing the hidden
-- original bar.
local noop = CreateFrame("Button", "BetterBartenderNoop", UIParent)
noop:Hide()

function M:ApplyBindings()
	if InCombatLockdown() then
		self.pendingApply = true
		return
	end
	ClearOverrideBindings(owner)
	local bound = {}
	for slot, keys in pairs(self.profile.keys) do
		if self.active[slot] then
			for _, key in ipairs(keys) do
				SetOverrideBindingClick(owner, false, key, M.ButtonName(slot), "LeftButton")
				bound[key] = true
			end
		end
	end
	for _, source in ipairs(ORIGINAL_KEYS) do
		for i = 1, 12 do
			for _, key in ipairs({ GetBindingKey(source.command .. i) }) do
				if not bound[key] then
					SetOverrideBindingClick(owner, false, key, noop:GetName(), "LeftButton")
				end
			end
		end
	end
	for _, b in pairs(self.buttons) do self:UpdateHotkey(b) end
end

-- A key belongs to one slot only: it is taken off any other slot first.
function M:AddKey(slot, key)
	local keys = self.profile.keys
	for other, list in pairs(keys) do
		for i = #list, 1, -1 do
			if list[i] == key then table.remove(list, i) end
		end
		if #list == 0 then keys[other] = nil end
	end
	keys[slot] = keys[slot] or {}
	table.insert(keys[slot], key)
	self:ApplyBindings()
end

function M:ClearKeys(slot)
	self.profile.keys[slot] = nil
	self:ApplyBindings()
end

---------------------------------------------------------------------------
-- Bind mode: hover over a slot and press a key
---------------------------------------------------------------------------

local IGNORED = {
	LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true, LALT = true, RALT = true,
	UNKNOWN = true, PRINTSCREEN = true,
}
local MOUSE = { MiddleButton = "BUTTON3", Button4 = "BUTTON4", Button5 = "BUTTON5" }

local function WithModifiers(key)
	return (IsAltKeyDown() and "ALT-" or "") .. (IsControlKeyDown() and "CTRL-" or "")
		.. (IsShiftKeyDown() and "SHIFT-" or "") .. key
end

local root
local overlays = {}
local hoverSlot

local function ShowTooltip(overlay)
	local slot = overlay.slot
	GameTooltip:SetOwner(overlay, "ANCHOR_TOP")
	local keys = M.profile.keys[slot]
	GameTooltip:AddLine(keys and table.concat(keys, ", ") or "Bez klávesy", 1, 1, 1)
	GameTooltip:AddLine("Stiskni klávesu nebo kolečko a tlačítka myši.", 0.8, 0.8, 0.8)
	GameTooltip:AddLine("Pravý klik smaže klávesy tohoto políčka.", 0.8, 0.8, 0.8)
	GameTooltip:Show()
end

local function Assign(key)
	if not hoverSlot then return end
	M:AddKey(hoverSlot, WithModifiers(key))
	if overlays[hoverSlot] then ShowTooltip(overlays[hoverSlot]) end
end

local function Overlay(slot)
	local o = overlays[slot]
	if o then return o end
	o = CreateFrame("Frame", nil, root)
	o.slot = slot
	o:EnableMouse(true)
	o:EnableMouseWheel(true)
	o.tint = o:CreateTexture(nil, "OVERLAY")
	o.tint:SetAllPoints(o)
	o.tint:SetTexture(0.2, 0.9, 0.3, 0.25)
	o:SetScript("OnEnter", function(self)
		hoverSlot = self.slot
		self.tint:SetTexture(1, 0.8, 0.1, 0.45)
		ShowTooltip(self)
	end)
	o:SetScript("OnLeave", function(self)
		if hoverSlot == self.slot then hoverSlot = nil end
		self.tint:SetTexture(0.2, 0.9, 0.3, 0.25)
		GameTooltip:Hide()
	end)
	o:SetScript("OnMouseDown", function(self, button)
		if button == "RightButton" then
			M:ClearKeys(self.slot)
			ShowTooltip(self)
		elseif MOUSE[button] then
			Assign(MOUSE[button])
		end
	end)
	o:SetScript("OnMouseWheel", function(self, delta)
		Assign(delta > 0 and "MOUSEWHEELUP" or "MOUSEWHEELDOWN")
	end)
	overlays[slot] = o
	return o
end

-- A full-screen frame that takes the keyboard while bind mode is on.
local function CreateRoot()
	root = CreateFrame("Frame", "BetterBartenderBindRoot", UIParent)
	root:SetAllPoints(UIParent)
	root:SetFrameStrata("DIALOG")
	root:EnableKeyboard(true)
	root:Hide()
	root:SetScript("OnKeyDown", function(self, key)
		if key == "ESCAPE" then
			M:SetBindMode(false)
		elseif not IGNORED[key] then
			Assign(key)
		end
	end)
	local hint = root:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	hint:SetPoint("TOP", UIParent, "TOP", 0, -120)
	hint:SetText("Najeď na políčko a stiskni klávesu. Pravý klik maže. Esc konec.")
end

function M:UpdateBindOverlays()
	if not root then return end
	for slot, o in pairs(overlays) do
		if not self.active[slot] then o:Hide() end
	end
	for slot in pairs(self.active) do
		local o = Overlay(slot)
		o:ClearAllPoints()
		o:SetAllPoints(self.buttons[slot])
		o:Show()
	end
end

-- Part of edit mode: a hidden bar is shown there, so its slots can be bound too.
function M:SetBindMode(on)
	if on and InCombatLockdown() then
		self:Print("V boji to nejde.")
		return
	end
	if on and not self.editing then self:SetEditMode(true) end
	if not root then CreateRoot() end
	self.binding = on or nil
	hoverSlot = nil
	GameTooltip:Hide()
	if on then
		self:UpdateBindOverlays()
		root:Show()
	else
		root:Hide()
	end
	self:UpdateOverlays()
	self:UpdatePanel()
end
