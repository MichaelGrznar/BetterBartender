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
-- slots 1 to 12, whichever bar they are on.
local PAGE_BY_CLASS = {
	DRUID = "[bonusbar:1,nostealth] 7; [bonusbar:1,stealth] 7; [bonusbar:2] 8; [bonusbar:3] 9; [bonusbar:4] 10; ",
	WARRIOR = "[bonusbar:1] 7; [bonusbar:2] 8; [bonusbar:3] 9; ",
	PRIEST = "[bonusbar:1] 7; ",
	ROGUE = "[bonusbar:1] 7; [form:3] 7; ",
}

-- Bar 1 pages like the game's main bar (17. 11. 2026): Shift+Up and Shift+Down, or the arrows
-- left of the bar, go through pages 1 to PAGES, round and round. Page n shows slots
-- (n - 1) * 12 + 1 to n * 12, as in the original game, so a page another bar has (page 3 is
-- the right bar's slots) shows the same actions there. A vehicle's bar always wins, a stance's
-- bar on page 1 only, as in the game. The page is kept for the next login.
M.PAGES = 9

function M:CreatePager()
	local pager = CreateFrame("Frame", "BetterBartenderPager", UIParent, "SecureHandlerAttributeTemplate")
	for slot = 1, 12 do
		pager:SetFrameRef("slot" .. slot, self:Button(slot))
	end
	pager:Execute([[
		buttons = newtable()
		for slot = 1, 12 do
			table.insert(buttons, self:GetFrameRef("slot" .. slot))
		end
	]])
	-- state-page from the state driver below (11 a vehicle, 7 to 10 a stance, 0 none),
	-- userpage from the arrows and keys
	pager:SetAttribute("_onattributechanged", [[
		if name ~= "state-page" and name ~= "userpage" then return end
		local state = tonumber(self:GetAttribute("state-page")) or 0
		local page = tonumber(self:GetAttribute("userpage")) or 1
		if state == 11 or (state > 0 and page == 1) then page = state end
		for _, button in ipairs(buttons) do
			button:SetAttribute("actionpage", page)
		end
	]])
	local saved = tonumber(self.profile.page) or 1
	if saved < 1 or saved > M.PAGES then saved = 1 end
	pager:SetAttribute("userpage", saved)
	local class = select(2, UnitClass("player"))
	RegisterStateDriver(pager, "page", "[bonusbar:5] 11; " .. (PAGE_BY_CLASS[class] or "") .. "0")
	-- (runs after the secure handler, outside it: only remembers the page and writes it out)
	pager:HookScript("OnAttributeChanged", function(_, name, value)
		if name == "userpage" then
			M.profile.page = tonumber(value)
			M:UpdatePageText()
		end
	end)
	self.pager = pager
	self:CreatePageArrows()
end

---------------------------------------------------------------------------
-- The arrows left of bar 1
---------------------------------------------------------------------------

local ARROW = [[Interface\MainMenuBar\UI-MainMenu-Scroll]]

local function PageTooltip(self)
	GameTooltip:SetOwner(self, "ANCHOR_LEFT")
	GameTooltip:AddLine(string.format("Panel 1: stránka %d z %d", tonumber(M.pager:GetAttribute("userpage")) or 1, M.PAGES))
	GameTooltip:AddLine(self.bbtTip, 1, 1, 1)
	GameTooltip:AddLine("Každá stránka má svých 12 políček. Stránky 3 až 6 jsou políčka ostatních panelů, jako v původní hře.", 0.8, 0.8, 0.8, true)
	GameTooltip:Show()
end

local function PageArrow(name, holder, step, kind, tip)
	local b = CreateFrame("Button", name, holder, "SecureHandlerClickTemplate")
	b:SetWidth(24)
	b:SetHeight(24)
	b:SetNormalTexture(ARROW .. kind .. "Button-Up")
	b:SetPushedTexture(ARROW .. kind .. "Button-Down")
	b:SetHighlightTexture(ARROW .. kind .. "Button-Highlight", "ADD")
	b:RegisterForClicks("AnyUp")
	b:SetFrameRef("pager", M.pager)
	b:SetAttribute("step", step)
	b:SetAttribute("_onclick", string.format([[
		local pager = self:GetFrameRef("pager")
		local page = (tonumber(pager:GetAttribute("userpage")) or 1) + self:GetAttribute("step")
		if page > %d then page = 1 elseif page < 1 then page = %d end
		pager:SetAttribute("userpage", page)
	]], M.PAGES, M.PAGES))
	b.bbtTip = tip
	b:SetScript("OnEnter", PageTooltip)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	return b
end

function M:CreatePageArrows()
	local holder = CreateFrame("Frame", "BetterBartenderPageArrows", self.hidden)
	holder:SetWidth(36)
	holder:SetHeight(M.BUTTON_SIZE)
	self.pageUp = PageArrow("BetterBartenderPageUp", holder, 1, "Up", "Další stránka (Shift + šipka nahoru)")
	self.pageUp:SetPoint("TOPRIGHT", holder, "TOPRIGHT", 2, 5)
	self.pageDown = PageArrow("BetterBartenderPageDown", holder, -1, "Down", "Předchozí stránka (Shift + šipka dolů)")
	self.pageDown:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", 2, -5)
	local text = holder:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	text:SetPoint("RIGHT", holder, "RIGHT", -20, 0)
	holder.text = text
	self.pageArrows = holder
	self:UpdatePageText()
end

function M:UpdatePageText()
	local holder = self.pageArrows
	if not holder then return end
	local page = tonumber(self.pager:GetAttribute("userpage")) or 1
	holder.text:SetText(page)
	if page == 1 then holder.text:SetTextColor(1, 1, 1) else holder.text:SetTextColor(1, 0.82, 0) end
end

-- The arrows stand left of bar 1 and go with it (its scale, hidden with it). Out of combat.
function M:PlacePageArrows(f)
	local holder = self.pageArrows
	if not holder then return end
	holder:SetParent(f)
	holder:ClearAllPoints()
	holder:SetPoint("RIGHT", f, "LEFT", -2, 0)
	holder:Show()
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
