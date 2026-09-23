local ADDON, ns = ...
local L = ns.L

local Core = {}
ns.Core = Core

Core.entries = {}
Core.sections = {}
Core.groups = {}
Core.stats = { total = 0, byStanding = {}, progress = 0 }
Core.session = {}
Core.baseline = nil

local scanning = false

local function HeaderKey(prefix, factionID, name)
	if type(factionID) == "number" and factionID > 0 then
		return prefix .. ":" .. factionID
	end
	return prefix .. ":" .. ns.Lower(name or "")
end

local function ValidFactionID(id)
	return type(id) == "number" and id > 0
end

local function SameFaction(entry, factionID, name)
	if ValidFactionID(factionID) and ValidFactionID(entry.factionID) and factionID == entry.factionID then return true end
	return name and entry.name == name
end

function Core:SafeStanding(id)
	if type(id) ~= "number" or id < 1 or id > 8 then return 4 end
	return id
end

function Core:StandingLabel(id)
	id = self:SafeStanding(id)
	return _G["FACTION_STANDING_LABEL" .. id] or tostring(id)
end

function Core:StandingColor(id)
	id = self:SafeStanding(id)
	local c = FACTION_BAR_COLORS and FACTION_BAR_COLORS[id]
	if c then return c.r, c.g, c.b end
	return 0.55, 0.55, 0.55
end

function Core:WithAllExpanded(fn)
	local collapsed = {}
	local i = 1
	local touched = false

	while i <= GetNumFactions() do
		local name, _, _, _, _, _, _, _, isHeader, isCollapsed, _, _, _, factionID = GetFactionInfo(i)
		if isHeader and isCollapsed and name then
			local key = HeaderKey("restore", factionID, name)
			collapsed[key] = (collapsed[key] or 0) + 1
			touched = true
			ExpandFactionHeader(i)
		end
		i = i + 1
	end

	local ok, err = pcall(fn)

	i = GetNumFactions()
	while i >= 1 do
		local name, _, _, _, _, _, _, _, isHeader, _, _, _, _, factionID = GetFactionInfo(i)
		if isHeader and name then
			local key = HeaderKey("restore", factionID, name)
			if collapsed[key] and collapsed[key] > 0 then
				CollapseFactionHeader(i)
				collapsed[key] = collapsed[key] - 1
			end
		end
		i = i - 1
	end

	if touched then self.suppressUntil = GetTime() + 0.5 end
	if not ok and err then DEFAULT_CHAT_FRAME:AddMessage("|cff1784d1SirusRep|r: " .. tostring(err)) end
	return touched
end

function Core:Scan(light)
	if scanning then return end
	if type(GetNumFactions) ~= "function" or type(GetFactionInfo) ~= "function" then return end
	scanning = true

	local entries = {}
	local sections = {}
	local groups = {}
	local sectionByKey = {}
	local isInactiveFn = type(IsFactionInactive) == "function" and IsFactionInactive or nil

	local collect = function()
		local currentSection = nil
		local currentSubgroup = nil

		for i = 1, GetNumFactions() do
			local name, desc, standing, barMin, barMax, barValue,
				atWar, canWar, isHeader, _, hasRep, isWatched, isChild, factionID = GetFactionInfo(i)

			if name then
				if isHeader and not isChild then
					local key = HeaderKey("section", factionID, name)
					currentSection = {
						key = key,
						name = name,
						factionID = factionID,
						order = i,
						factions = {},
						nodes = {},
						subgroups = {},
						subgroupByKey = {},
					}
					sections[#sections + 1] = currentSection
					groups[#groups + 1] = name
					sectionByKey[key] = currentSection
					currentSubgroup = nil
				elseif isHeader and isChild then
					if not currentSection then
						local key = "section:other"
						currentSection = sectionByKey[key]
						if not currentSection then
							currentSection = { key = key, name = L.OTHER, order = i, factions = {}, nodes = {}, subgroups = {}, subgroupByKey = {} }
							sections[#sections + 1] = currentSection
							groups[#groups + 1] = L.OTHER
							sectionByKey[key] = currentSection
						end
					end
					local key = HeaderKey("subgroup", factionID, (currentSection.key or "") .. ":" .. name)
					currentSubgroup = {
						key = key,
						name = name,
						factionID = factionID,
						order = i,
						sectionKey = currentSection.key,
						sectionName = currentSection.name,
						factions = {},
					}
					currentSection.subgroups[#currentSection.subgroups + 1] = currentSubgroup
					currentSection.subgroupByKey[key] = currentSubgroup
					currentSection.nodes[#currentSection.nodes + 1] = { kind = "subgroup", subgroup = currentSubgroup }
				elseif not isChild then
					currentSubgroup = nil
				end

				if (not isHeader) or hasRep then
					if not currentSection then
						local key = "section:other"
						currentSection = sectionByKey[key]
						if not currentSection then
							currentSection = { key = key, name = L.OTHER, order = i, factions = {}, nodes = {}, subgroups = {}, subgroupByKey = {} }
							sections[#sections + 1] = currentSection
							groups[#groups + 1] = L.OTHER
							sectionByKey[key] = currentSection
						end
					end

					barMin = tonumber(barMin) or 0
					barMax = tonumber(barMax) or 1
					barValue = tonumber(barValue) or 0

					local cur = barValue - barMin
					local max = barMax - barMin
					if max <= 0 then max = 1 end
					if cur < 0 then cur = 0 end
					if cur > max then cur = max end
					standing = self:SafeStanding(standing)

					local subgroup = isChild and currentSubgroup or nil
					local entry = {
						name = name,
						desc = desc,
						group = currentSection.name,
						sectionKey = currentSection.key,
						sectionName = currentSection.name,
						subgroupKey = subgroup and subgroup.key or nil,
						subgroupName = subgroup and subgroup.name or nil,
						factionID = factionID,
						standing = standing,
						cur = cur,
						max = max,
						remain = max - cur,
						pct = cur / max,
						total = barValue,
						atWar = atWar and true or false,
						canWar = canWar and true or false,
						watched = isWatched and true or false,
						isChild = isChild and true or false,
						inactive = isInactiveFn and isInactiveFn(i) or false,
						exalted = standing == 8,
						order = i,
					}

					entries[#entries + 1] = entry
					currentSection.factions[#currentSection.factions + 1] = entry
					if subgroup then
						subgroup.factions[#subgroup.factions + 1] = entry
					else
						currentSection.nodes[#currentSection.nodes + 1] = { kind = "entry", entry = entry }
					end
				end
			end
		end
	end

	if light then
		local ok, err = pcall(collect)
		if not ok and err then DEFAULT_CHAT_FRAME:AddMessage("|cff1784d1SirusRep|r: " .. tostring(err)) end
	else
		self:WithAllExpanded(collect)
	end

	if not self.baseline then
		self.baseline = {}
		for i = 1, #entries do
			local e = entries[i]
			local key = ValidFactionID(e.factionID) and ("id:" .. e.factionID) or ("name:" .. e.name)
			self.baseline[key] = e.total
		end
	end

	local stats = { total = 0, byStanding = {}, progress = 0 }
	for s = 1, 8 do stats.byStanding[s] = 0 end
	local sumValue = 0

	for i = 1, #entries do
		local e = entries[i]
		stats.total = stats.total + 1
		stats.byStanding[e.standing] = stats.byStanding[e.standing] + 1

		local key = ValidFactionID(e.factionID) and ("id:" .. e.factionID) or ("name:" .. e.name)
		local base = self.baseline[key]
		if base then
			local d = e.total - base
			self.session[key] = d ~= 0 and d or nil
		end

		local v = e.total
		if v < 0 then v = 0 end
		if v > 42000 then v = 42000 end
		sumValue = sumValue + v
	end

	if stats.total > 0 then
		stats.progress = math.floor((sumValue / (stats.total * 42000)) * 100 + 0.5)
	end

	self.entries = entries
	self.sections = sections
	self.groups = groups
	self.stats = stats
	scanning = false

	if ns.UI and ns.UI.OnDataChanged then ns.UI:OnDataChanged() end
end

function Core:WithFaction(factionID, name, fn)
	if not factionID and not name then return end
	self:WithAllExpanded(function()
		for i = 1, GetNumFactions() do
			local fname, _, _, _, _, _, _, _, _, _, _, _, _, fid = GetFactionInfo(i)
			if (ValidFactionID(factionID) and ValidFactionID(fid) and fid == factionID) or ((not ValidFactionID(factionID) or not ValidFactionID(fid)) and fname == name) then
				fn(i)
				return
			end
		end
	end)
end

function Core:ToggleWatch(entry)
	if not entry then return end
	self:WithFaction(entry.factionID, entry.name, function(index)
		if type(SetWatchedFactionIndex) ~= "function" then return end
		local _, _, _, _, _, _, _, _, _, _, _, isWatched = GetFactionInfo(index)
		SetWatchedFactionIndex(isWatched and 0 or index)
	end)
	self:Scan()
	self:ScanSoon(0.5)
end

function Core:ToggleWar(entry)
	if not entry then return end
	local done = false
	self:WithFaction(entry.factionID, entry.name, function(index)
		local _, _, _, _, _, _, atWar, canWar = GetFactionInfo(index)
		if not canWar then return end
		if type(SetSelectedFaction) == "function" then SetSelectedFaction(index) end
		if type(FactionToggleAtWar) == "function" then
			FactionToggleAtWar(index)
			done = true
		elseif atWar and type(SetFactionNotAtWar) == "function" then
			SetFactionNotAtWar(index)
			done = true
		elseif (not atWar) and type(SetFactionAtWar) == "function" then
			SetFactionAtWar(index)
			done = true
		end
	end)
	if not done then DEFAULT_CHAT_FRAME:AddMessage("|cff1784d1SirusRep|r: переключение войны недоступно для этой фракции.") end
	if type(ReputationFrame_Update) == "function" then pcall(ReputationFrame_Update) end
	self:Scan()
	self:ScanSoon(0.6)
end

function Core:FavoriteKey(entryOrName)
	if type(entryOrName) == "table" then
		if ValidFactionID(entryOrName.factionID) then return "id:" .. entryOrName.factionID end
		return "name:" .. (entryOrName.name or "")
	end
	return "name:" .. tostring(entryOrName or "")
end

function Core:IsFavorite(entryOrName)
	if not SirusRepCharDB or not SirusRepCharDB.favorites then return false end
	local key = self:FavoriteKey(entryOrName)
	if SirusRepCharDB.favorites[key] then return true end
	if type(entryOrName) == "table" and SirusRepCharDB.favorites[entryOrName.name] then return true end
	if type(entryOrName) == "string" and SirusRepCharDB.favorites[entryOrName] then return true end
	return false
end

function Core:ToggleFavorite(entryOrName)
	if not entryOrName then return end
	local key = self:FavoriteKey(entryOrName)
	local fav = SirusRepCharDB.favorites
	fav[key] = (not self:IsFavorite(entryOrName)) or nil
	if type(entryOrName) == "table" and entryOrName.name then fav[entryOrName.name] = nil end
	if ns.UI and ns.UI.OnDataChanged then ns.UI:OnDataChanged() end
end

function Core:FindEntry(factionID, name)
	for i = 1, #self.entries do
		local e = self.entries[i]
		if SameFaction(e, factionID, name) then return e end
	end
end

function Core:GetSection(key)
	for i = 1, #self.sections do
		if self.sections[i].key == key or self.sections[i].name == key then return self.sections[i] end
	end
end

function Core:GetSubgroup(key)
	for i = 1, #self.sections do
		local section = self.sections[i]
		for j = 1, #section.subgroups do
			local subgroup = section.subgroups[j]
			if subgroup.key == key or subgroup.name == key then return subgroup, section end
		end
	end
end

local defaults = {
	point = "CENTER", x = 0, y = 0,
	width = 820, height = 580,
	sort = "game",
	hideExalted = false,
	standingFilter = 0,
	grouping = true,
	fontScale = 1.0,
	replaceTab = false,
	infoShown = true,
	search = "",
	category = "__all",
	minimapAngle = 200,
}

local function ApplyDefaults()
	SirusRepDB = SirusRepDB or {}
	for k, v in pairs(defaults) do if SirusRepDB[k] == nil then SirusRepDB[k] = v end end
	SirusRepDB.customGuides = SirusRepDB.customGuides or {}
	SirusRepDB.sidebarExpanded = SirusRepDB.sidebarExpanded or {}
	SirusRepDB.listCollapsed = SirusRepDB.listCollapsed or {}

	SirusRepCharDB = SirusRepCharDB or {}
	SirusRepCharDB.favorites = SirusRepCharDB.favorites or {}

	ns.db = SirusRepDB
end

local deferFrame = CreateFrame("Frame")
local deferQueue = {}
deferFrame:Hide()
deferFrame:SetScript("OnUpdate", function(self)
	local q = deferQueue
	deferQueue = {}
	self:Hide()
	for i = 1, #q do pcall(q[i]) end
end)

function ns.Defer(fn)
	deferQueue[#deferQueue + 1] = fn
	deferFrame:Show()
end

local soonFrame = CreateFrame("Frame")
local soonLeft = 0
soonFrame:Hide()
soonFrame:SetScript("OnUpdate", function(self, elapsed)
	soonLeft = soonLeft - elapsed
	if soonLeft > 0 then return end
	self:Hide()
	Core.suppressUntil = 0
	local shown = ns.UI and ns.UI.frame and ns.UI.frame:IsShown()
	Core:Scan(not shown)
end)

function Core:ScanSoon(delay)
	soonLeft = delay or 0.6
	soonFrame:Show()
end

local ev = CreateFrame("Frame")
local pending, elapsed = false, 0

ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("UPDATE_FACTION")

ev:SetScript("OnEvent", function(self, event, arg1)
	if event == "ADDON_LOADED" and arg1 == ADDON then
		ApplyDefaults()
	elseif event == "PLAYER_LOGIN" then
		ApplyDefaults()
		local _, _, _, build = GetBuildInfo()
		if build and tonumber(build) and tonumber(build) ~= 30300 then DEFAULT_CHAT_FRAME:AddMessage(L.WRONG_CLIENT) end
		ns.Defer(function()
			Core:Scan()
			if ns.Hooks then ns.Hooks() end
			if ns.CreateMinimapButton then ns.CreateMinimapButton() end
			DEFAULT_CHAT_FRAME:AddMessage(L.LOADED)
		end)
	elseif event == "UPDATE_FACTION" then
		if scanning then return end
		if GetTime() < (Core.suppressUntil or 0) then return end
		pending, elapsed = true, 0
		self:Show()
	end
end)

ev:Hide()
ev:SetScript("OnUpdate", function(self, e)
	if not pending then self:Hide(); return end
	elapsed = elapsed + e
	if elapsed < 0.3 then return end
	pending = false
	self:Hide()
	if GetTime() < (Core.suppressUntil or 0) then return end
	local shown = ns.UI and ns.UI.frame and ns.UI.frame:IsShown()
	Core:Scan(not shown)
end)

function ns.Hooks()
	if ns._hooked then return end
	ns._hooked = true
	if type(CharacterFrame_ShowSubFrame) == "function" then
		hooksecurefunc("CharacterFrame_ShowSubFrame", function(frameName)
			if frameName ~= "ReputationFrame" or not ns.db.replaceTab then return end
			ns.Defer(function()
				if ReputationFrame then ReputationFrame:Hide() end
				if CharacterFrame and CharacterFrame:IsShown() then HideUIPanel(CharacterFrame) end
				ns.UI:Show()
			end)
		end)
	end
end

function ns.RestoreCharacterTab()
	if not CharacterFrame then return end
	CharacterFrame.selectedTab = 1
	if type(PanelTemplates_SetTab) == "function" then PanelTemplates_SetTab(CharacterFrame, 1) end
	if type(CharacterFrame_ShowSubFrame) == "function" then CharacterFrame_ShowSubFrame("PaperDollFrame") end
end

local RADIUS = 80

function ns.CreateMinimapButton()
	if ns.minimapButton or not Minimap then return end
	local db = ns.db
	local b = CreateFrame("Button", "SirusRepMinimapButton", Minimap)
	ns.minimapButton = b
	b:SetSize(31, 31)
	b:SetFrameStrata("MEDIUM")
	b:SetFrameLevel(8)
	b:RegisterForClicks("LeftButtonUp")
	b:RegisterForDrag("LeftButton")

	local icon = b:CreateTexture(nil, "BACKGROUND")
	icon:SetSize(20, 20)
	icon:SetPoint("TOPLEFT", 7, -6)
	icon:SetTexture("Interface\\Icons\\Achievement_Reputation_01")
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

	local border = b:CreateTexture(nil, "OVERLAY")
	border:SetSize(53, 53)
	border:SetPoint("TOPLEFT", 0, 0)
	border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

	local function Reposition()
		local a = math.rad(db.minimapAngle or 200)
		b:ClearAllPoints()
		b:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * RADIUS, math.sin(a) * RADIUS)
	end

	local function DragUpdate()
		local mx, my = Minimap:GetCenter()
		if not mx then return end
		local scale = Minimap:GetEffectiveScale()
		local px, py = GetCursorPosition()
		px, py = px / scale, py / scale
		db.minimapAngle = math.deg(math.atan2(py - my, px - mx))
		Reposition()
	end

	b:SetScript("OnDragStart", function(self)
		GameTooltip:Hide()
		self:SetScript("OnUpdate", DragUpdate)
	end)
	b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
	b:SetScript("OnClick", function() if ns.UI then ns.UI:Toggle() end end)
	b:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:AddLine("|cff1784d1SirusRep|r", 1, 1, 1)
		GameTooltip:AddLine(L.MINIMAP_TIP, 0.7, 0.7, 0.7, true)
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	Reposition()
end

local function ResetMainWindowPosition()
	if not ns.db then return end
	ns.db.point = "CENTER"
	ns.db.x = 0
	ns.db.y = 0

	if ns.UI and ns.UI.frame then
		local frame = ns.UI.frame
		frame:ClearAllPoints()
		frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
		if ns.Info then ns.Info:Reanchor() end
	end

	DEFAULT_CHAT_FRAME:AddMessage(L.POSITION_RESET)
end

SLASH_SIRUSREP1 = "/sr"
SLASH_SIRUSREP2 = "/srep"
SlashCmdList["SIRUSREP"] = function(msg)
	local command = string.lower((msg or ""):match("^%s*(.-)%s*$"))
	if command == "reset" then
		ResetMainWindowPosition()
		return
	end
	if ns.UI then ns.UI:Toggle() end
end
