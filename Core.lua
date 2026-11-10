-- BetterBartender: action bars you can move, arrange in columns and bind keys to.
--
-- The server's interface (BOCoreUI) draws only five bars of 12 buttons, yet the game has
-- 120 action slots (pages 1 to 10). So the addon creates its own buttons, each fixed to one
-- slot, and hides the original bars. The server keeps what is in the slots, so the addon
-- never changes or clears them: once it is turned off, the original bars come back with
-- their original keys.

BetterBartender = {}
local M = BetterBartender

M.MAX_SLOT = 120
M.BUTTON_SIZE = 37
M.buttons = {} -- slot -> button
M.frames = {} -- bar id -> frame
M.active = {} -- slot -> the bar that uses it

-- Original bars and unused buttons are moved here: a frame whose parent is hidden shows
-- nothing, even when the game's own code calls Show() on it.
M.hidden = CreateFrame("Frame")
M.hidden:Hide()

function M:Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffBetterBartender:|r " .. tostring(msg))
end

local function DeepCopy(value)
	if type(value) ~= "table" then return value end
	local copy = {}
	for k, v in pairs(value) do copy[k] = DeepCopy(v) end
	return copy
end
M.DeepCopy = DeepCopy

local function ProfileKey()
	return UnitName("player") .. " - " .. GetRealmName()
end

function M:Start()
	if self.started then return end
	self.started = true
	if IsAddOnLoaded("Bartender4") then
		self:Print("Pozor, běží i Bartender4 a používá stejná jména tlačítek. Jeden z nich vypni.")
	end
	local profile = self.profile
	-- First run: take over what is on the screen now, keys included. This has to happen
	-- before the original bars are hidden.
	if not profile.bars then
		profile.bars = self:ImportBars()
		profile.keys = self:ImportKeys()
		profile.defaultBars = DeepCopy(profile.bars)
		profile.defaultKeys = DeepCopy(profile.keys)
		self:Print("Převzal jsem Tvoje lišty a klávesy. Úpravy: /bbt")
	end
	self:CreatePager()
	self:ApplyAll()
	self:HideOriginals()
	self:CreateMinimapButton()
end

function M:ResetLayout()
	if InCombatLockdown() then
		self:Print("V boji to nejde.")
		return
	end
	local profile = self.profile
	profile.bars = DeepCopy(profile.defaultBars)
	profile.keys = DeepCopy(profile.defaultKeys)
	self.selectedBar = nil
	self:ApplyAll()
	self:UpdatePanel()
	self:Print("Lišty a klávesy jsou zase jako při prvním spuštění.")
end

-- Layout and keys from another character, found by the start of its name.
function M:CopyFrom(name)
	if InCombatLockdown() then
		self:Print("V boji to nejde.")
		return
	end
	local own = ProfileKey()
	local want = string.lower(name or "")
	for key, source in pairs(BetterBartenderDB.profiles) do
		if key ~= own and source.bars and string.find(string.lower(key), want, 1, true) == 1 then
			self.profile.bars = DeepCopy(source.bars)
			self.profile.keys = DeepCopy(source.keys)
			self.selectedBar = nil
			self:ApplyAll()
			self:UpdatePanel()
			self:Print("Rozložení a klávesy zkopírované z postavy " .. key .. ".")
			return
		end
	end
	self:Print("Takovou postavu nemám uloženou. Zkopírovat jde jen z postavy, která už s addonem hrála.")
end

local events = CreateFrame("Frame")
-- Start on entering the world: by then the game has laid out the original bars
-- (MultiActionBar_Update) and their positions can be read. At login they may not even be
-- shown yet.
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function(self, event)
	if event == "PLAYER_ENTERING_WORLD" then
		if M.db then return end
		BetterBartenderDB = BetterBartenderDB or {}
		local db = BetterBartenderDB
		db.profiles = db.profiles or {}
		db.minimap = db.minimap or { angle = 200 }
		local key = ProfileKey()
		db.profiles[key] = db.profiles[key] or {}
		M.db = db
		M.profile = db.profiles[key]
		-- After a /reload in combat the secure buttons cannot be created: wait for combat to end.
		if InCombatLockdown() then
			M.pendingStart = true
		else
			M:Start()
		end
	elseif event == "PLAYER_REGEN_DISABLED" then
		-- This event still allows protected changes, for the last time before the lockdown.
		if M.editing then
			M:SetEditMode(false)
			M:Print("V boji se lišty upravovat nedají, režim úprav jsem zavřel.")
		end
	elseif event == "PLAYER_REGEN_ENABLED" then
		if M.pendingStart then
			M.pendingStart = nil
			M:Start()
		elseif M.pendingApply then
			M.pendingApply = nil
			M:ApplyAll()
		end
	end
end)

SLASH_BETTERBARTENDER1 = "/bbt"
SlashCmdList["BETTERBARTENDER"] = function(msg)
	local cmd, rest = string.match(msg or "", "^%s*(%S*)%s*(.-)%s*$")
	cmd = string.lower(cmd or "")
	if not M.started then
		M:Print("Addon čeká na konec boje.")
	elseif cmd == "" then
		M:SetEditMode(not M.editing)
	elseif cmd == "klavesy" or cmd == "klávesy" then
		M:SetBindMode(not M.binding)
	elseif cmd == "reset" then
		StaticPopup_Show("BETTERBARTENDER_RESET")
	elseif cmd == "kopie" then
		if rest == "" then
			M:Print("Napiš, z které postavy: /bbt kopie Craft")
		else
			M:CopyFrom(rest)
		end
	elseif cmd == "minimapa" then
		M.db.minimap.hide = not M.db.minimap.hide or nil
		M:UpdateMinimapButton()
	else
		M:Print("/bbt - úpravy lišt")
		M:Print("/bbt klavesy - přiřazení kláves")
		M:Print("/bbt kopie Craft - rozložení a klávesy z jiné postavy")
		M:Print("/bbt reset - zpátky na stav z prvního spuštění")
		M:Print("/bbt minimapa - skryje nebo ukáže tlačítko u minimapy")
	end
end
