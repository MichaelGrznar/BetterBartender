-- Edit mode: bars are dragged with the mouse; a window sets the slot count, columns and size.

local M = BetterBartender

local SNAP = 8 -- how close a bar must come to another bar's edge to snap to it
local panel, sliders, checks, title, deleteBtn, bindBtn
local guides, position
local nudges = {}
local updating -- while the window is set from a bar, it must not change the bar back

---------------------------------------------------------------------------
-- Snapping and saving the position
---------------------------------------------------------------------------

local function Rect(f)
	local s = f:GetScale()
	return f:GetLeft() * s, f:GetRight() * s, f:GetTop() * s, f:GetBottom() * s
end

local function DropBar(bar, f)
	local left, right, top, bottom = Rect(f)
	local bestX, bestY = SNAP, SNAP
	local moveX, moveY = 0, 0
	-- The screen's centre snaps too: dropped near the line, a bar is exactly centred.
	local toCenterX = UIParent:GetWidth() / 2 - (left + right) / 2
	local toCenterY = UIParent:GetHeight() / 2 - (top + bottom) / 2
	if math.abs(toCenterX) < bestX then bestX, moveX = math.abs(toCenterX), toCenterX end
	if math.abs(toCenterY) < bestY then bestY, moveY = math.abs(toCenterY), toCenterY end
	for _, other in ipairs(M.profile.bars) do
		local g = M.frames[other.id]
		if other ~= bar and g and g:IsShown() then
			local otherLeft, otherRight, otherTop, otherBottom = Rect(g)
			for _, d in ipairs({ otherLeft - left, otherRight - right, otherRight - left, otherLeft - right }) do
				if math.abs(d) < bestX then bestX, moveX = math.abs(d), d end
			end
			for _, d in ipairs({ otherTop - top, otherBottom - bottom, otherBottom - top, otherTop - bottom }) do
				if math.abs(d) < bestY then bestY, moveY = math.abs(d), d end
			end
		end
	end
	M:PlaceBar(bar, left + moveX, top + moveY)
	M:LayoutBar(bar)
end

---------------------------------------------------------------------------
-- Coloured overlay over a bar
---------------------------------------------------------------------------

local function CreateOverlay(f, id)
	local o = CreateFrame("Frame", nil, f)
	o.barId = id
	o:SetAllPoints(f)
	o:SetFrameLevel(f:GetFrameLevel() + 30)
	o:EnableMouse(true)
	o:RegisterForDrag("LeftButton")
	o.bg = o:CreateTexture(nil, "BACKGROUND")
	o.bg:SetAllPoints(o)
	o.label = o:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	o.label:SetPoint("CENTER")
	o:SetScript("OnMouseDown", function(self)
		M.selectedBar = self.barId
		M:UpdateOverlays()
		M:UpdatePanel()
	end)
	o:SetScript("OnDragStart", function(self)
		if InCombatLockdown() then return end
		f:StartMoving()
	end)
	o:SetScript("OnDragStop", function(self)
		f:StopMovingOrSizing()
		f:SetUserPlaced(false)
		local bar = M:BarById(self.barId)
		if bar and not InCombatLockdown() then DropBar(bar, f) end
	end)
	f.overlay = o
	return o
end

function M:UpdateOverlay(bar, f)
	local o = f.overlay
	if not self.editing or self.binding then
		if o then o:Hide() end
		return
	end
	o = o or CreateOverlay(f, bar.id)
	o.barId = bar.id
	o.label:SetText(bar.name)
	if self.selectedBar == bar.id then
		o.bg:SetTexture(1, 0.8, 0.1, 0.4)
	elseif bar.shown then
		o.bg:SetTexture(0.1, 0.5, 0.9, 0.35)
	else
		o.bg:SetTexture(0.5, 0.5, 0.5, 0.55)
	end
	o:Show()
end

function M:UpdateOverlays()
	for _, bar in ipairs(self.profile.bars) do
		local f = self.frames[bar.id]
		if f then self:UpdateOverlay(bar, f) end
	end
end

---------------------------------------------------------------------------
-- Settings window
---------------------------------------------------------------------------

local function SelectedBar()
	return M.selectedBar and M:BarById(M.selectedBar)
end

-- How many interface units make one real screen pixel. UIParent spans the whole screen
-- height, but its units are not pixels (at 1080 rows there may be only 768 of them).
local function PixelSize()
	local height = tonumber(string.match(GetCVar("gxResolution") or "", "%d+x(%d+)"))
	return height and UIParent:GetHeight() / height or 1
end

-- Moves the selected bar by whole pixels, without snapping. It starts from the position in
-- the last frame and keeps to the screen's edges itself: the bar is clamped to the screen,
-- and its saved position would otherwise drift away from where it is drawn.
local function Nudge(dx, dy)
	local bar = SelectedBar()
	local f = bar and M.frames[bar.id]
	if not f or not f:GetLeft() or InCombatLockdown() then return end
	local left, right, top, bottom = Rect(f)
	local pixel = PixelSize()
	local moveX, moveY = dx * pixel, dy * pixel
	if left + moveX < 0 then moveX = -left end
	if right + moveX > UIParent:GetWidth() then moveX = UIParent:GetWidth() - right end
	if bottom + moveY < 0 then moveY = -bottom end
	if top + moveY > UIParent:GetHeight() then moveY = UIParent:GetHeight() - top end
	M:PlaceBar(bar, left + moveX, top + moveY)
	M:LayoutBar(bar)
end

-- Distance from the centre in pixels and its description; zero means "exactly centred".
local function FromCenter(delta, pixel, lower, higher)
	local px = math.floor(math.abs(delta) / pixel + 0.5)
	if px == 0 then return 0, "|cff33ff33na středu|r" end
	return px, px .. " px " .. (delta < 0 and lower or higher)
end

local LINE_CENTERED = { 0.2, 1, 0.2, 0.9 }
local LINE_OFF = { 1, 1, 1, 0.25 }

local function RefreshPosition()
	local bar = SelectedBar()
	local f = bar and M.frames[bar.id]
	if not f or not f:GetLeft() then
		position:SetText("")
		guides.vertical:SetTexture(unpack(LINE_OFF))
		guides.horizontal:SetTexture(unpack(LINE_OFF))
		return
	end
	local left, right, top, bottom = Rect(f)
	local pixel = PixelSize()
	local pxX, textX = FromCenter((left + right) / 2 - UIParent:GetWidth() / 2, pixel, "vlevo", "vpravo")
	local pxY, textY = FromCenter((top + bottom) / 2 - UIParent:GetHeight() / 2, pixel, "dolů", "nahoru")
	position:SetText(string.format("Poloha: X %d, Y %d px\nOd středu obrazovky:\nvodorovně %s\nsvisle %s",
		math.floor(left / pixel + 0.5), math.floor(bottom / pixel + 0.5), textX, textY))
	guides.vertical:SetTexture(unpack(pxX == 0 and LINE_CENTERED or LINE_OFF))
	guides.horizontal:SetTexture(unpack(pxY == 0 and LINE_CENTERED or LINE_OFF))
end

-- Lines through the screen's centre: they turn green when the selected bar is centred on them.
local function CreateGuides()
	guides = CreateFrame("Frame", nil, UIParent)
	guides:SetAllPoints(UIParent)
	guides:SetFrameStrata("MEDIUM")
	guides:SetFrameLevel(60)
	guides:Hide()
	local thickness = PixelSize() * 2
	guides.vertical = guides:CreateTexture(nil, "OVERLAY")
	guides.vertical:SetPoint("TOP", UIParent, "TOP")
	guides.vertical:SetPoint("BOTTOM", UIParent, "BOTTOM")
	guides.vertical:SetWidth(thickness)
	guides.horizontal = guides:CreateTexture(nil, "OVERLAY")
	guides.horizontal:SetPoint("LEFT", UIParent, "LEFT")
	guides.horizontal:SetPoint("RIGHT", UIParent, "RIGHT")
	guides.horizontal:SetHeight(thickness)
	local sum = 0
	guides:SetScript("OnUpdate", function(self, elapsed)
		sum = sum + elapsed
		if sum >= 0.05 then
			sum = 0
			RefreshPosition()
		end
	end)
end

-- An arrow button: a click is one step, holding it keeps stepping. Up and down are the left
-- arrow turned (texture corners in the order top left, bottom left, top right, bottom right).
local ROTATED = {
	up = { 0, 1, 1, 1, 0, 0, 1, 0 },
	down = { 1, 0, 0, 0, 1, 1, 0, 1 },
}

local function ArrowButton(direction, onStep)
	local page = "Interface\\Buttons\\UI-SpellbookIcon-" .. (direction == "right" and "Next" or "Prev") .. "Page-"
	local b = CreateFrame("Button", nil, panel)
	b:SetWidth(24)
	b:SetHeight(24)
	b:SetNormalTexture(page .. "Up")
	b:SetPushedTexture(page .. "Down")
	b:SetDisabledTexture(page .. "Disabled")
	b:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
	local coords = ROTATED[direction]
	if coords then
		b:GetNormalTexture():SetTexCoord(unpack(coords))
		b:GetPushedTexture():SetTexCoord(unpack(coords))
		b:GetDisabledTexture():SetTexCoord(unpack(coords))
	end
	b:SetScript("OnMouseDown", function(self)
		if self:IsEnabled() then self.heldFor, self.repeated = 0, nil end
	end)
	b:SetScript("OnMouseUp", function(self) self.heldFor = nil end)
	b:SetScript("OnHide", function(self) self.heldFor = nil end)
	b:SetScript("OnUpdate", function(self, elapsed)
		if not self.heldFor then return end
		self.heldFor = self.heldFor + elapsed
		if self.heldFor >= 0.4 then
			self.heldFor = 0.32
			self.repeated = true
			onStep()
		end
	end)
	b:SetScript("OnClick", function(self)
		if not self.repeated then onStep() end
		self.repeated = nil
	end)
	return b
end

-- A slider with arrows on both sides; onChange(bar, value) applies it to the selected bar.
local function Slider(key, label, y, onChange, suffix)
	local name = "BetterBartenderSlider" .. key
	local s = CreateFrame("Slider", name, panel, "OptionsSliderTemplate")
	s:SetPoint("TOP", panel, "TOP", 0, y)
	s:SetWidth(180)
	s:SetValueStep(1)
	s.stepSize = 1
	local function Step(direction)
		s:SetValue(math.floor(s:GetValue() + 0.5) + direction * s.stepSize)
	end
	s.less = ArrowButton("left", function() Step(-1) end)
	s.less:SetPoint("RIGHT", s, "LEFT", -2, 0)
	s.more = ArrowButton("right", function() Step(1) end)
	s.more:SetPoint("LEFT", s, "RIGHT", 2, 0)
	_G[name .. "Low"]:SetText("")
	_G[name .. "High"]:SetText("")
	s:SetScript("OnValueChanged", function(self, value)
		value = math.floor(value + 0.5)
		_G[name .. "Text"]:SetText(label .. ": " .. value .. (suffix or ""))
		if updating or InCombatLockdown() then return end
		local bar = SelectedBar()
		if bar then
			onChange(bar, value)
			M:UpdatePanel()
		end
	end)
	sliders[key] = s
	return s
end

local function Check(key, label, x, y, onClick)
	local name = "BetterBartenderCheck" .. key
	local c = CreateFrame("CheckButton", name, panel, "UICheckButtonTemplate")
	c:SetPoint("TOPLEFT", panel, "TOPLEFT", x, y)
	c:SetWidth(26)
	c:SetHeight(26)
	_G[name .. "Text"]:SetText(label)
	c:SetScript("OnClick", function(self)
		local bar = SelectedBar()
		if bar and not InCombatLockdown() then
			onClick(bar, self:GetChecked() and true or false)
			M:LayoutBar(bar)
			M:UpdatePanel()
		end
	end)
	checks[key] = c
	return c
end

local function PanelButton(label, width, onClick)
	local b = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	b:SetWidth(width)
	b:SetHeight(22)
	b:SetText(label)
	b:SetScript("OnClick", onClick)
	return b
end

local function CreatePanel()
	panel = CreateFrame("Frame", "BetterBartenderPanel", UIParent)
	panel:SetWidth(270)
	panel:SetHeight(424)
	panel:SetFrameStrata("HIGH")
	panel:SetClampedToScreen(true)
	panel:SetMovable(true)
	panel:EnableMouse(true)
	panel:RegisterForDrag("LeftButton")
	panel:SetBackdrop({
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true, tileSize = 16, edgeSize = 16,
		insets = { left = 4, right = 4, top = 4, bottom = 4 },
	})
	panel:SetScript("OnDragStart", panel.StartMoving)
	panel:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		self:SetUserPlaced(false)
		M.db.panelLeft, M.db.panelTop = self:GetLeft(), self:GetTop()
	end)
	if M.db.panelLeft and M.db.panelTop then
		panel:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", M.db.panelLeft, M.db.panelTop)
	else
		panel:SetPoint("CENTER", UIParent, "CENTER", 300, 60)
	end
	-- Escape closes the window, and with it edit mode.
	tinsert(UISpecialFrames, "BetterBartenderPanel")
	panel:SetScript("OnHide", function() M:SetEditMode(false) end)

	local head = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	head:SetPoint("TOP", 0, -12)
	head:SetText("BetterBartender")
	local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", -2, -2)

	title = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	title:SetPoint("TOP", 0, -34)
	title:SetWidth(240)

	sliders, checks = {}, {}
	Slider("Count", "Počet políček", -66, function(bar, value) M:SetBarCount(bar, value) end)
	Slider("Cols", "Sloupce", -106, function(bar, value)
		bar.cols = value
		M:LayoutBar(bar)
	end)
	Slider("Scale", "Velikost", -146, function(bar, value)
		bar.scale = value / 100
		M:LayoutBar(bar)
	end, " %")
	Slider("Spacing", "Mezery", -186, function(bar, value)
		bar.spacing = value
		M:LayoutBar(bar)
	end)
	-- The column range is fixed: it used to follow the slot count, and then the slider's
	-- knob moved even though the value had not changed.
	sliders.Cols:SetMinMaxValues(1, 40)
	sliders.Scale:SetMinMaxValues(50, 150)
	sliders.Scale:SetValueStep(5)
	sliders.Scale.stepSize = 5
	sliders.Spacing:SetMinMaxValues(0, 20)

	Check("Grid", "Ukazovat prázdná políčka", 16, -212, function(bar, value) bar.grid = value end)
	Check("Shown", "Zobrazit panel (skrytý dál reaguje na klávesy)", 16, -236, function(bar, value) bar.shown = value end)
	_G["BetterBartenderCheckShownText"]:SetWidth(210)
	_G["BetterBartenderCheckShownText"]:SetJustifyH("LEFT")

	position = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	position:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -276)
	position:SetWidth(170)
	position:SetJustifyH("LEFT")
	-- { direction, dx, dy, x, y } of the four nudge arrows, placed from the top right corner
	local arrows = {
		{ "up", 0, 1, -40, -268 }, { "left", -1, 0, -64, -292 },
		{ "right", 1, 0, -16, -292 }, { "down", 0, -1, -40, -316 },
	}
	for _, a in ipairs(arrows) do
		local dx, dy = a[2], a[3]
		local b = ArrowButton(a[1], function() Nudge(dx, dy) end)
		b:SetPoint("TOPRIGHT", panel, "TOPRIGHT", a[4], a[5])
		nudges[#nudges + 1] = b
	end
	CreateGuides()

	local addBtn = PanelButton("Nový panel", 112, function()
		if not InCombatLockdown() then M:AddBar() end
	end)
	addBtn:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 16, 42)
	deleteBtn = PanelButton("Smazat panel", 112, function()
		local bar = SelectedBar()
		if bar then
			local dialog = StaticPopup_Show("BETTERBARTENDER_DELETE", bar.name)
			if dialog then dialog.data = bar.id end
		end
	end)
	deleteBtn:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -16, 42)
	bindBtn = PanelButton("Přiřadit klávesy", 112, function() M:SetBindMode(not M.binding) end)
	bindBtn:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 16, 16)
	local done = PanelButton("Hotovo", 112, function() M:SetEditMode(false) end)
	done:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -16, 16)
	panel:Hide()
end

function M:UpdatePanel()
	if not panel then return end
	local bar = SelectedBar()
	updating = true
	bindBtn:SetText(self.binding and "Konec kláves" or "Přiřadit klávesy")
	local has = bar and true or false
	for _, s in pairs(sliders) do
		s:SetAlpha(has and 1 or 0.3)
		s:EnableMouse(has)
		if has then
			s.less:Enable()
			s.more:Enable()
		else
			s.less:Disable()
			s.more:Disable()
		end
	end
	for _, c in pairs(checks) do
		c:SetAlpha(has and 1 or 0.3)
		c:EnableMouse(has)
	end
	for _, b in ipairs(nudges) do
		if has then b:Enable() else b:Disable() end
	end
	if self.editing and not self.binding then guides:Show() else guides:Hide() end
	if has then deleteBtn:Enable() else deleteBtn:Disable() end
	if bar then
		title:SetText(bar.name)
		sliders.Count:SetMinMaxValues(1, math.max(1, #bar.slots + self:FreeSlots()))
		sliders.Count:SetValue(#bar.slots)
		sliders.Cols:SetValue(bar.cols)
		-- More columns than slots cannot be drawn: show both, so it is clear why the bar is
		-- narrower than the slider says.
		_G["BetterBartenderSliderColsText"]:SetText(bar.cols > #bar.slots
			and ("Sloupce: " .. bar.cols .. " (teď " .. #bar.slots .. ")") or ("Sloupce: " .. bar.cols))
		sliders.Scale:SetValue(math.floor(bar.scale * 100 + 0.5))
		sliders.Spacing:SetValue(math.floor(bar.spacing + 0.5))
		checks.Grid:SetChecked(bar.grid)
		checks.Shown:SetChecked(bar.shown)
	else
		title:SetText("Klikni na panel. Tažením ho přesuneš.")
	end
	updating = false
	self:UpdateOverlays()
end

function M:SetEditMode(on)
	on = on and true or false
	if on == (self.editing or false) then return end
	if on and InCombatLockdown() then
		self:Print("V boji se lišty upravovat nedají.")
		return
	end
	if not panel then CreatePanel() end
	self.editing = on or nil
	if on then
		panel:Show()
		self:ApplyAll()
		self:UpdatePanel()
	else
		if self.binding then self:SetBindMode(false) end
		panel:Hide()
		guides:Hide()
		-- The overlays separately: they are not secure, so they disappear even when ApplyAll
		-- has to wait for the end of combat, and they do not block clicks on the buttons.
		self:UpdateOverlays()
		self:ApplyAll()
	end
end

StaticPopupDialogs["BETTERBARTENDER_DELETE"] = {
	text = "Smazat panel %s? Akce i klávesy zůstanou uložené u políček, vrátí se, až je dostane jiný panel.",
	button1 = YES,
	button2 = NO,
	OnAccept = function(self, data)
		if not InCombatLockdown() then M:DeleteBar(data) end
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
}

StaticPopupDialogs["BETTERBARTENDER_RESET"] = {
	text = "Vrátit všechny panely a klávesy na stav z prvního spuštění?",
	button1 = YES,
	button2 = NO,
	OnAccept = function() M:ResetLayout() end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
}

---------------------------------------------------------------------------
-- Minimap button (on the same ring as BetterBagnon's, which starts at 160 degrees)
---------------------------------------------------------------------------

-- BOCoreUI hides the minimap and draws MinimapFrame with the house crest at the top right.
-- Returns the frame the ring is around, its anchor point, the ring's centre offset and radius.
local function ButtonRing()
	if MinimapFrame and MinimapFrame.GetObjectType and MinimapFrame:IsShown() then
		return MinimapFrame, "TOPRIGHT", -68.5, -76.5, 74
	end
	if Minimap and Minimap:IsVisible() then
		return Minimap, "CENTER", 0, 0, Minimap:GetWidth() / 2 + 10
	end
	return UIParent, "TOPRIGHT", -110, -110, 80
end

local function RingCenter(host, point, cx, cy)
	local x, y
	if point == "TOPRIGHT" then
		x, y = host:GetRight(), host:GetTop()
	else
		x, y = host:GetCenter()
	end
	return (x or 0) + cx, (y or 0) + cy
end

function M:UpdateMinimapButton()
	local b = self.minimapButton
	if not b then return end
	if self.db.minimap.hide then
		b:Hide()
		return
	end
	local host, point, cx, cy, r = ButtonRing()
	local a = math.rad(self.db.minimap.angle or 200)
	self.minimapHost = host
	b:ClearAllPoints()
	b:SetPoint("CENTER", host, point, cx + math.cos(a) * r, cy + math.sin(a) * r)
	b:Show()
end

function M:CreateMinimapButton()
	if self.minimapButton then return end
	local b = CreateFrame("Button", "BetterBartenderMinimapButton", UIParent)
	b:SetWidth(31)
	b:SetHeight(31)
	b:SetFrameStrata("HIGH")
	b:SetFrameLevel(20)
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	b:RegisterForDrag("LeftButton")
	b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

	local icon = b:CreateTexture(nil, "BACKGROUND")
	icon:SetWidth(20)
	icon:SetHeight(20)
	icon:SetTexture("Interface\\Icons\\INV_Misc_Wrench_01")
	icon:SetPoint("TOPLEFT", 7, -5)

	local border = b:CreateTexture(nil, "OVERLAY")
	border:SetWidth(53)
	border:SetHeight(53)
	border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	border:SetPoint("TOPLEFT")

	b:SetScript("OnClick", function(self, button)
		if button == "RightButton" then
			M:SetBindMode(not M.binding)
		else
			M:SetEditMode(not M.editing)
		end
	end)
	b:SetScript("OnDragStart", function(self)
		self:SetScript("OnUpdate", function()
			local host, point, cx, cy = ButtonRing()
			local mx, my = RingCenter(host, point, cx, cy)
			local px, py = GetCursorPosition()
			local s = host:GetEffectiveScale()
			M.db.minimap.angle = math.deg(math.atan2(py / s - my, px / s - mx))
			M:UpdateMinimapButton()
		end)
	end)
	b:SetScript("OnDragStop", function(self)
		self:SetScript("OnUpdate", nil)
	end)
	b:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:AddLine("BetterBartender")
		GameTooltip:AddLine("Levý klik: úpravy lišt", 1, 1, 1)
		GameTooltip:AddLine("Pravý klik: přiřazení kláves", 1, 1, 1)
		GameTooltip:AddLine("Tažením posuneš tlačítko", 0.7, 0.7, 0.7)
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)

	self.minimapButton = b
	self:UpdateMinimapButton()

	-- BOCoreUI rebuilds the crest after login: put the button back on its ring when it moves.
	local watch = CreateFrame("Frame")
	local sum = 0
	watch:SetScript("OnUpdate", function(_, elapsed)
		sum = sum + elapsed
		if sum < 2 then return end
		sum = 0
		if not M.db.minimap.hide and (not b:IsShown() or ButtonRing() ~= M.minimapHost) then
			M:UpdateMinimapButton()
		end
	end)
end
