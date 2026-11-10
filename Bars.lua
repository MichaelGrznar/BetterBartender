-- Bars: taking over the original bars, laying out buttons, positions, hiding the originals.
--
-- A bar is saved as { id, name, slots = { slot numbers }, cols, scale, spacing, point, x, y,
-- grid, shown }. Its position is in UIParent units, measured from the screen corner the bar
-- is nearest to: when the number of columns changes, that corner stays put.

local M = BetterBartender
local BUTTON = M.BUTTON_SIZE

function M:BarById(id)
	for _, bar in ipairs(self.profile.bars) do
		if bar.id == id then return bar end
	end
end

-- Size without scale, and the number of columns actually drawn.
function M:BarSize(bar)
	local count = #bar.slots
	local cols = math.max(1, math.min(bar.cols, count))
	local rows = math.ceil(count / cols)
	local step = BUTTON + bar.spacing
	return cols * step - bar.spacing, rows * step - bar.spacing, cols
end

-- Saves the position given by the top left corner (in UIParent units).
function M:PlaceBar(bar, left, top)
	local w, h = self:BarSize(bar)
	w, h = w * bar.scale, h * bar.scale
	local right, bottom = left + w, top - h
	local screenW, screenH = UIParent:GetWidth(), UIParent:GetHeight()
	local vertical = (top + bottom) / 2 >= screenH / 2 and "TOP" or "BOTTOM"
	local horizontal = (left + right) / 2 >= screenW / 2 and "RIGHT" or "LEFT"
	bar.point = vertical .. horizontal
	bar.x = horizontal == "LEFT" and left or right - screenW
	bar.y = vertical == "BOTTOM" and bottom or top - screenH
end

---------------------------------------------------------------------------
-- First run: what is on the screen now
---------------------------------------------------------------------------

local ORIGINAL = {
	{ name = "Hlavní", prefix = "ActionButton", first = 1, cols = 12, y = 60 },
	{ name = "Spodní levý", prefix = "MultiBarBottomLeftButton", first = 61, cols = 12, y = 105, toggles = { 1 } },
	{ name = "Spodní pravý", prefix = "MultiBarBottomRightButton", first = 49, cols = 12, y = 150, toggles = { 2 } },
	{ name = "Pravý", prefix = "MultiBarRightButton", first = 25, cols = 1, toggles = { 3 } },
	{ name = "Pravý 2", prefix = "MultiBarLeftButton", first = 37, cols = 1, toggles = { 3, 4 } },
}

local function Slots(first, count)
	local slots = {}
	for i = 0, count - 1 do slots[#slots + 1] = first + i end
	return slots
end

-- Is the bar turned on in the game's settings? The values are nil, "0" or "1".
-- GetActionBarToggles() must not be used: it returns nonsense until the server's data has
-- arrived (see the comment in UIParent.lua).
local function IsEnabled(def)
	for _, n in ipairs(def.toggles or {}) do
		local value = _G["SHOW_MULTI_ACTIONBAR_" .. n]
		if not value or value == "0" then return false end
	end
	return true
end

-- All bars are taken over, the disabled ones too: in edit mode they are grey and can be
-- turned on.
function M:ImportBars()
	local bars = {}
	local uiScale = UIParent:GetEffectiveScale()
	for i, def in ipairs(ORIGINAL) do
		local bar = {
			id = i, name = def.name, slots = Slots(def.first, 12),
			cols = def.cols, scale = 0.9, spacing = 7, grid = true, shown = IsEnabled(def),
		}
		local b1, b2 = _G[def.prefix .. "1"], _G[def.prefix .. "2"]
		local l1, t1 = b1:GetLeft(), b1:GetTop()
		local l2, t2 = b2:GetLeft(), b2:GetTop()
		if l1 and t1 and l2 and t2 then
			local size = b1:GetWidth()
			bar.scale = b1:GetEffectiveScale() / uiScale
			if math.abs(l2 - l1) > math.abs(t2 - t1) then
				bar.cols = 12
				bar.spacing = l2 - l1 - size
			else
				bar.cols = 1
				bar.spacing = t1 - t2 - size
			end
			self:PlaceBar(bar, l1 * bar.scale, t1 * bar.scale)
		else
			-- The original bar's position is unknown: bottom centre, or upright on the right.
			local w, h = self:BarSize(bar)
			if def.cols == 12 then
				self:PlaceBar(bar, (UIParent:GetWidth() - w * bar.scale) / 2, def.y + h * bar.scale)
			else
				self:PlaceBar(bar, UIParent:GetWidth() - (i - 3) * 45, UIParent:GetHeight() / 2 + h * bar.scale / 2)
			end
		end
		bars[#bars + 1] = bar
	end
	return bars
end

-- Hides the original bars. BOCoreUI's stand (pUiMainBar) stays, only invisible: the pet bar,
-- the stances and the leave-vehicle button hang on it.
function M:HideOriginals()
	for i = 1, 12 do
		local b = _G["ActionButton" .. i]
		if b then b:SetParent(self.hidden) end
	end
	for _, name in ipairs({ "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight", "MultiBarLeft" }) do
		local f = _G[name]
		if f then f:SetParent(self.hidden) end
	end
	-- Page arrows, page number and the gryphons.
	if pUiMainBarArt then pUiMainBarArt:Hide() end
	if pUiMainBar then
		if pUiMainBar.BorderArt then pUiMainBar.BorderArt:Hide() end
		if pUiMainBar.Background then pUiMainBar.Background:Hide() end
		for i = 1, pUiMainBar:GetNumRegions() do
			local region = select(i, pUiMainBar:GetRegions())
			if region and region:GetObjectType() == "Texture" then region:SetAlpha(0) end
		end
		pUiMainBar:EnableMouse(false)
	end
end

---------------------------------------------------------------------------
-- Layout
---------------------------------------------------------------------------

local function BarFrame(id)
	local f = M.frames[id]
	if f then return f end
	f = CreateFrame("Frame", "BetterBartenderBar" .. id, UIParent, "SecureHandlerStateTemplate")
	f:SetFrameStrata("MEDIUM")
	f:SetFrameLevel(10)
	f:SetMovable(true)
	f:SetClampedToScreen(true)
	M.frames[id] = f
	return f
end

function M:LayoutBar(bar)
	local f = BarFrame(bar.id)
	local w, h, cols = self:BarSize(bar)
	f:SetScale(bar.scale)
	f:SetWidth(w)
	f:SetHeight(h)
	f:ClearAllPoints()
	f:SetPoint(bar.point, UIParent, bar.point, bar.x / bar.scale, bar.y / bar.scale)

	local step = BUTTON + bar.spacing
	local showEmpty = bar.grid or self.editing
	for i, slot in ipairs(bar.slots) do
		local b = self:Button(slot)
		b:SetParent(f)
		b:SetFrameLevel(f:GetFrameLevel() + 1)
		_G[b:GetName() .. "Cooldown"]:SetFrameLevel(b:GetFrameLevel() + 1)
		b:ClearAllPoints()
		b:SetPoint("TOPLEFT", f, "TOPLEFT", ((i - 1) % cols) * step, -math.floor((i - 1) / cols) * step)
		b:SetAttribute("statehidden", nil)
		b:SetAttribute("showgrid", showEmpty and 1 or 0)
		ActionButton_Update(b)
		if showEmpty or HasAction(b.action) then b:Show() else b:Hide() end
	end

	-- In edit mode everything is shown, a hidden bar too. Otherwise the bars hide in a
	-- vehicle, which has a bar of its own.
	if self.editing then
		UnregisterStateDriver(f, "visibility")
		f:Show()
	elseif bar.shown then
		RegisterStateDriver(f, "visibility", "[vehicleui] hide; show")
	else
		UnregisterStateDriver(f, "visibility")
		f:Hide()
	end
	self:UpdateOverlay(bar, f)
end

-- Lays everything out by the saved profile. Out of combat only: secure buttons cannot be
-- changed in combat, so the change waits for its end.
function M:ApplyAll()
	if InCombatLockdown() then
		self.pendingApply = true
		return
	end
	local used, ids = {}, {}
	for _, bar in ipairs(self.profile.bars) do
		ids[bar.id] = true
		for _, slot in ipairs(bar.slots) do used[slot] = bar end
	end
	self.active = used
	for slot, b in pairs(self.buttons) do
		if not used[slot] then
			b:SetAttribute("statehidden", true)
			b:Hide()
			b:ClearAllPoints()
			b:SetParent(self.hidden)
		end
	end
	for id, f in pairs(self.frames) do
		if not ids[id] then
			UnregisterStateDriver(f, "visibility")
			f:Hide()
		end
	end
	for _, bar in ipairs(self.profile.bars) do self:LayoutBar(bar) end
	self:ApplyBindings()
	self:UpdateBindOverlays()
end

---------------------------------------------------------------------------
-- Changes to bars from edit mode
---------------------------------------------------------------------------

local function IsFree(slot, used)
	return slot >= 1 and slot <= M.MAX_SLOT and not used[slot]
end

function M:FreeSlots()
	local free = 0
	for slot = 1, self.MAX_SLOT do
		if not self.active[slot] then free = free + 1 end
	end
	return free
end

-- Adds slots after the last one used, so that slots removed earlier come back with their
-- actions.
function M:SetBarCount(bar, count)
	while #bar.slots > count do
		self.active[table.remove(bar.slots)] = nil
	end
	while #bar.slots < count do
		local nextSlot = (bar.slots[#bar.slots] or 0) + 1
		if not IsFree(nextSlot, self.active) then
			nextSlot = nil
			for slot = 1, self.MAX_SLOT do
				if not self.active[slot] then
					nextSlot = slot
					break
				end
			end
		end
		if not nextSlot then break end
		bar.slots[#bar.slots + 1] = nextSlot
		self.active[nextSlot] = bar
	end
	-- The columns are left alone: BarSize limits them to the number of slots for drawing
	-- only, so after adding slots again the columns you set come back (removing slots used
	-- to overwrite them for good).
	self:ApplyAll()
end

-- A new bar: a whole free page of 12 if there is one, otherwise whatever is left.
function M:AddBar()
	local slots
	for page = 1, 10 do
		local first = (page - 1) * 12 + 1
		local whole = true
		for slot = first, first + 11 do
			if self.active[slot] then whole = false end
		end
		if whole then
			slots = Slots(first, 12)
			break
		end
	end
	if not slots then
		slots = {}
		for slot = 1, self.MAX_SLOT do
			if not self.active[slot] and #slots < 12 then slots[#slots + 1] = slot end
		end
	end
	if #slots == 0 then
		self:Print("Všech 120 políček už je na panelech, nové se nedá přidat.")
		return
	end
	local id = 1
	while self:BarById(id) do id = id + 1 end
	local bar = {
		id = id, name = "Panel " .. id, slots = slots,
		cols = #slots, scale = 0.9, spacing = 7, grid = true, shown = true,
	}
	local w, h = self:BarSize(bar)
	self:PlaceBar(bar, (UIParent:GetWidth() - w * bar.scale) / 2, UIParent:GetHeight() / 2 + h * bar.scale / 2)
	table.insert(self.profile.bars, bar)
	self.selectedBar = id
	self:ApplyAll()
	self:UpdatePanel()
end

-- Actions and keys stay saved with their slots: they come back once another bar gets them.
function M:DeleteBar(id)
	for i, bar in ipairs(self.profile.bars) do
		if bar.id == id then
			table.remove(self.profile.bars, i)
			break
		end
	end
	if self.selectedBar == id then self.selectedBar = nil end
	self:ApplyAll()
	self:UpdatePanel()
end
