-- Buttons: one per slot, styled like BOCoreUI, main bar paging, macro cooldowns.

local M = BetterBartender

-- Named like Bartender's: the server's MacroCD draws macro cooldowns on buttons BT4Button1
-- to BT4Button120 too, so this hooks into it without changing anything.
local function ButtonName(slot)
	return "BT4Button" .. slot
end
M.ButtonName = ButtonName

-- The same files and atlas as BOCoreUI/DFUI/modules/buttons.lua (main_buttons), so the new
-- bars look like the original ones. Without BOCoreUI the game's plain look stays.
local DIR = [[Interface\Panz\BOCoreUI\DFUI\]]
local FONT = DIR .. "expressway.ttf"

local function Style(b)
	local name = b:GetName()
	b:SetWidth(M.BUTTON_SIZE)
	b:SetHeight(M.BUTTON_SIZE)

	-- set_atlas is added to textures by BOCoreUI; without it, keep the default look
	local normal = _G[name .. "NormalTexture"]
	if not normal.set_atlas then return end

	normal:ClearAllPoints()
	normal:SetPoint("TOPRIGHT", b, 2.2, 2.3)
	normal:SetPoint("BOTTOMLEFT", b, -2.2, -2.2)
	normal:SetVertexColor(1, 1, 1, 1)
	normal:SetDrawLayer("OVERLAY")

	local macro = _G[name .. "Name"]
	macro:SetFont(FONT, 13, "")
	macro:SetVertexColor(1, 1, 1, 1)
	macro:SetDrawLayer("OVERLAY")

	local count = _G[name .. "Count"]
	count:SetPoint("BOTTOMRIGHT", 2, -1)
	count:SetFont(FONT, 14, "OUTLINE")
	count:SetDrawLayer("OVERLAY")

	local hotkey = _G[name .. "HotKey"]
	hotkey:SetFont(FONT, 14, "")
	hotkey:SetShadowOffset(-1.3, -1.1)
	hotkey:SetVertexColor(1, 1, 1, 1)
	hotkey:SetShadowColor(0, 0, 0, 1)

	_G[name .. "Flash"]:set_atlas("ui-hud-actionbar-iconframe-flash")

	local icon = _G[name .. "Icon"]
	icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
	icon:SetDrawLayer("BORDER")

	local cooldown = _G[name .. "Cooldown"]
	cooldown:ClearAllPoints()
	cooldown:SetPoint("TOPRIGHT", b, -1, -1)
	cooldown:SetPoint("BOTTOMLEFT", b, 1, 1)

	local border = _G[name .. "Border"]
	border:set_atlas("_ui-hud-actionbar-iconborder-checked")
	border:SetAllPoints(normal)

	b:GetCheckedTexture():set_atlas("_ui-hud-actionbar-iconborder-checked")
	b:GetPushedTexture():set_atlas("_ui-hud-actionbar-iconborder-pushed")
	b:SetHighlightTexture(DIR .. "uiactionbariconframehighlight.tga")
	b:GetCheckedTexture():SetAllPoints(normal)
	b:GetPushedTexture():SetAllPoints(normal)
	b:GetHighlightTexture():SetAllPoints(normal)
	b:GetCheckedTexture():SetDrawLayer("OVERLAY")
	b:GetPushedTexture():SetDrawLayer("OVERLAY")

	local shadow = b:CreateTexture(nil, "ARTWORK", nil, 1)
	shadow:SetPoint("TOPRIGHT", normal, 3.8, 3.8)
	shadow:SetPoint("BOTTOMLEFT", normal, -3.8, -3.8)
	shadow:set_atlas("ui-hud-actionbar-iconframe-flyoutbordershadow", true)

	local background = b:CreateTexture(nil, "BACKGROUND")
	background:SetAllPoints(normal)
	background:set_atlas("ui-hud-actionbar-iconframe-slot")
end

function M:Button(slot)
	local b = self.buttons[slot]
	if b then return b end
	b = CreateFrame("CheckButton", ButtonName(slot), self.hidden, "ActionBarButtonTemplate")
	self.buttons[slot] = b
	b.bbtSlot = slot
	-- The slot is an ID of 1 to 12 plus a page, as on the original bars. The "action"
	-- attribute would need ID 0, and that breaks BOCore: SpellEmoty.lua calls
	-- GetSpellName(button:GetID()) for every spell tooltip, and 0 is not a valid spellbook
	-- slot (7. 11. 2026).
	b:SetID((slot - 1) % 12 + 1)
	b:SetAttribute("actionpage", math.floor((slot - 1) / 12) + 1)
	Style(b)
	-- BOCore's spell tooltip; it is only hooked to the buttons of the five original bars.
	b:HookScript("OnEnter", function(self)
		if type(ShowSpellTooltip) == "function" then ShowSpellTooltip(self) end
	end)
	self:UpdateHotkey(b)
	return b
end

-- The key shortened for the button, the way BOCoreUI writes it (formatting.lua).
function M.KeyText(key)
	key = key:gsub("ALT%-", "a"):gsub("CTRL%-", "c"):gsub("SHIFT%-", "s")
	key = key:gsub("MOUSEWHEELUP", "MU"):gsub("MOUSEWHEELDOWN", "MD")
	key = key:gsub("BACKSPACE", "BS"):gsub("BUTTON", "M"):gsub("NUMPAD", "N"):gsub("SPACE", "BAR")
	return key
end

function M:UpdateHotkey(b)
	local hotkey = _G[b:GetName() .. "HotKey"]
	local keys = self.profile.keys and self.profile.keys[b.bbtSlot]
	local key = keys and keys[1]
	if key then
		hotkey:SetText(M.KeyText(key))
		hotkey:SetPoint("TOPLEFT", b, "TOPLEFT", -2, -2)
		hotkey:Show()
	else
		hotkey:SetText(RANGE_INDICATOR)
		hotkey:SetPoint("TOPLEFT", b, "TOPLEFT", 1, -2)
		hotkey:Hide()
	end
end

-- The game rewrites the key text whenever bindings change and knows nothing about our
-- override keys, so it would write an empty one.
hooksecurefunc("ActionButton_UpdateHotkeys", function(self)
	if self.bbtSlot then M:UpdateHotkey(self) end
end)

-- In the game the main bar switches its slots by stance and while controlling another
-- unit (BOCoreUI/DFUI/modules/vehicle.lua, conditions copied from there). This applies to
-- slots 1 to 12, whichever bar they are on. Paging with arrows (bar:2 to bar:6) is gone:
-- pages 2 to 6 are bars of their own now.
local PAGE_BY_CLASS = {
	DRUID = "[bonusbar:1,nostealth] 7; [bonusbar:1,stealth] 7; [bonusbar:2] 8; [bonusbar:3] 9; [bonusbar:4] 10; ",
	WARRIOR = "[bonusbar:1] 7; [bonusbar:2] 8; [bonusbar:3] 9; ",
	PRIEST = "[bonusbar:1] 7; ",
	ROGUE = "[bonusbar:1] 7; [form:3] 7; ",
}

function M:CreatePager()
	local pager = CreateFrame("Frame", "BetterBartenderPager", UIParent, "SecureHandlerStateTemplate")
	for slot = 1, 12 do
		pager:SetFrameRef("slot" .. slot, self:Button(slot))
	end
	pager:Execute([[
		buttons = newtable()
		for slot = 1, 12 do
			table.insert(buttons, self:GetFrameRef("slot" .. slot))
		end
	]])
	pager:SetAttribute("_onstate-page", [[
		for slot, button in ipairs(buttons) do
			button:SetAttribute("actionpage", tonumber(newstate) or 1)
		end
	]])
	local class = select(2, UnitClass("player"))
	RegisterStateDriver(pager, "page", "[bonusbar:5] 11; " .. (PAGE_BY_CLASS[class] or "") .. "1")
end

---------------------------------------------------------------------------
-- Macro cooldowns
---------------------------------------------------------------------------

-- On the server, spells are cast by macros through SeslatKouzlo(), whose cooldown tracking
-- (MaCD in BOCore) covers only the five original bars. Without this, a macro on a new bar
-- would show no cooldown.
local macroSpell = {} -- macro index -> spell

local function RefreshMacroCooldown(b)
	if not b.action then return end
	local kind, macro = GetActionInfo(b.action)
	if kind ~= "macro" then return end
	local spell = macroSpell[macro]
	if not spell then return end
	local start, duration = GetSpellCooldown(spell)
	if start and duration and duration > 0 and start + duration > GetTime() then
		local cooldown = _G[b:GetName() .. "Cooldown"]
		if not cooldown:IsShown() or cooldown.bbtStart ~= start then
			cooldown.bbtStart = start
			cooldown:SetCooldown(start, duration)
			cooldown:Show()
		end
	end
end

-- The game updates a button's cooldown by its slot and hides it for a macro; put it back.
hooksecurefunc("ActionButton_UpdateCooldown", function(self)
	if self.bbtSlot then RefreshMacroCooldown(self) end
end)

local ticker = CreateFrame("Frame")
ticker:Hide()
local elapsedSum = 0
ticker:SetScript("OnUpdate", function(self, elapsed)
	elapsedSum = elapsedSum + elapsed
	if elapsedSum < 0.25 then return end
	elapsedSum = 0
	for slot in pairs(M.active) do
		local b = M.buttons[slot]
		if b then RefreshMacroCooldown(b) end
	end
end)

-- BOCore's MaCD(spell, macro) tracks the cooldowns of its macros: remember which spell each
-- macro casts, and start checking cooldowns once the first one is known.
if type(MaCD) == "function" then
	hooksecurefunc("MaCD", function(spell, macro)
		if macro then
			macroSpell[macro] = spell
			ticker:Show()
		end
	end)
end
