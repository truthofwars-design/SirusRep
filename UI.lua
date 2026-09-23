local _, ns = ...
local L, Core = ns.L, ns.Core

local UI = {}
ns.UI = UI

local FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
local ROW_H = 68
local SIDE_ROW_H = 24
local SIDE_W = 190
local BAR_TEX = "Interface\\TargetingFrame\\UI-StatusBar"
local WHITE = "Interface\\Buttons\\WHITE8X8"

local rows = {}
local sideButtons = {}

UI.category = "__all"
UI.search = ""
UI.list = {}
UI.visible = 8
UI.sidebarItems = {}

local Lower = ns.Lower

local function SearchPreview(text, maxChars)
	text = tostring(text or "")
	text = text:gsub("[%c]", " "):gsub("|", "||")
	maxChars = maxChars or 36
	local i, chars, n = 1, 0, #text
	while i <= n and chars < maxChars do
		local b = string.byte(text, i) or 0
		local step = 1
		if b >= 240 then
			step = 4
		elseif b >= 224 then
			step = 3
		elseif b >= 192 then
			step = 2
		end
		i = i + step
		chars = chars + 1
	end
	local out = string.sub(text, 1, i - 1)
	if i <= n then out = out .. "..." end
	return out
end

local function ListCollapseKey(key)
	if UI.category == "__fav" or UI.category == "__watched" or UI.category == "__war" then
		return UI.category .. ":" .. tostring(key or "")
	end
	return key
end

local function IsListCollapsed(key)
	return ns.db.listCollapsed[ListCollapseKey(key)] and true or false
end

local function Skin(f, r, g, b, a, er, eg, eb)
	f:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
	f:SetBackdropColor(r or 0.07, g or 0.07, b or 0.09, a or 0.95)
	f:SetBackdropBorderColor(er or 0.22, eg or 0.24, eb or 0.30, 1)
end

local function Text(parent, size, flag, r, g, b)
	local fs = parent:CreateFontString(nil, "OVERLAY")
	fs:SetFont(FONT, size, flag)
	fs:SetTextColor(r or 0.92, g or 0.92, b or 0.92)
	return fs
end

local function FS(size)
	return math.floor(size * ((ns.db and ns.db.fontScale) or 1) + 0.5)
end

local function EntryKey(entry)
	if entry and type(entry.factionID) == "number" and entry.factionID > 0 then return "id:" .. entry.factionID end
	return "name:" .. ((entry and entry.name) or "")
end

local function IsSelectedFaction(entry)
	if not SirusRepCharDB or not entry then return false end
	if not ns.Info or not ns.Info.frame or not ns.Info.frame:IsShown() then return false end
	if type(SirusRepCharDB.selectedFactionID) == "number" and SirusRepCharDB.selectedFactionID > 0
		and type(entry.factionID) == "number" and entry.factionID > 0 then
		return SirusRepCharDB.selectedFactionID == entry.factionID
	end
	return SirusRepCharDB.selectedFaction == entry.name
end

local function SelectFaction(entry)
	if not SirusRepCharDB or not entry then return end
	SirusRepCharDB.selectedFaction = entry.name
	SirusRepCharDB.selectedFactionID = (type(entry.factionID) == "number" and entry.factionID > 0) and entry.factionID or nil
end

function UI:ClearSelectedFaction()
	if SirusRepCharDB then
		SirusRepCharDB.selectedFaction = nil
		SirusRepCharDB.selectedFactionID = nil
	end
end

local function OpenFactionChat(entry)
	if not entry then return end
	local standing = Core:StandingLabel(entry.standing)
	local message
	if entry.exalted then
		message = entry.name .. ": " .. L.CHAT_REPUTATION .. " "
			.. ns.Sep(entry.max) .. " / " .. ns.Sep(entry.max)
			.. " (" .. standing .. ") - " .. L.MAXED .. "."
	else
		message = entry.name .. ": " .. L.CHAT_REPUTATION .. " "
			.. ns.Sep(entry.cur) .. " / " .. ns.Sep(entry.max)
			.. " (" .. standing .. ") - " .. L.LEFT .. " " .. ns.Sep(entry.remain) .. "."
	end
	if type(ChatFrame_OpenChat) == "function" then
		ChatFrame_OpenChat(message)
	elseif _G.ChatFrame1EditBox then
		local editBox = _G.ChatFrame1EditBox
		editBox:Show()
		editBox:SetText(message)
		editBox:SetFocus()
	end
end

local function MakeToggle(parent, label, isOn, onClick)
	local b = CreateFrame("Button", nil, parent)
	b:SetHeight(26)
	Skin(b, 0.11, 0.11, 0.14, 1)
	b.label = Text(b, 12)
	b.label:SetPoint("CENTER")
	b.text = label
	b.isOn = isOn
	function b:Sync()
		self.label:SetFont(FONT, FS(12), nil)
		self.label:SetText(self.text)
		self:SetWidth(self.label:GetStringWidth() + 24)
		if self.isOn() then
			self:SetBackdropColor(0.09, 0.29, 0.47, 1)
			self:SetBackdropBorderColor(0.20, 0.52, 0.82, 1)
			self.label:SetTextColor(0.80, 0.92, 1)
		else
			self:SetBackdropColor(0.11, 0.11, 0.14, 1)
			self:SetBackdropBorderColor(0.22, 0.24, 0.30, 1)
			self.label:SetTextColor(0.72, 0.72, 0.76)
		end
	end
	b:SetScript("OnClick", function(self) onClick(); self:Sync() end)
	b:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(0.45, 0.65, 0.9, 1) end)
	b:SetScript("OnLeave", function(self) self:Sync() end)
	b:Sync()
	return b
end

local sorters = {
	game = function(a, b)
		if (a.order or 0) ~= (b.order or 0) then return (a.order or 0) < (b.order or 0) end
		return a.name < b.name
	end,
	name = function(a, b) return a.name < b.name end,
	standing = function(a, b)
		if a.standing ~= b.standing then return a.standing > b.standing end
		if a.pct ~= b.pct then return a.pct > b.pct end
		return a.name < b.name
	end,
	progress = function(a, b)
		local pa = a.exalted and 1 or a.pct
		local pb = b.exalted and 1 or b.pct
		if pa ~= pb then return pa > pb end
		if a.standing ~= b.standing then return a.standing > b.standing end
		return a.name < b.name
	end,
	remain = function(a, b)
		if a.exalted ~= b.exalted then return b.exalted end
		if a.remain ~= b.remain then return a.remain < b.remain end
		return a.name < b.name
	end,
}

local sortOrder = { "game", "progress", "standing", "remain", "name" }
local sortLabels = {
	game = L.SORT_GAME,
	progress = L.SORT_PROGRESS,
	standing = L.SORT_STANDING,
	remain = L.SORT_REMAIN,
	name = L.SORT_NAME,
}

local function CategoryMatches(entry)
	if UI.category == "__all" then return true end
	if UI.category == "__fav" then return Core:IsFavorite(entry) end
	if UI.category == "__watched" then return entry.watched end
	if UI.category == "__war" then return entry.atWar end
	if entry.sectionKey == UI.category then return true end
	if entry.subgroupKey == UI.category then return true end
	return false
end

local function Passes(entry)
	if ns.db.hideExalted and entry.exalted then return false end
	local standingFilter = tonumber(ns.db.standingFilter) or 0
	if standingFilter > 0 and entry.standing ~= standingFilter then return false end
	if not CategoryMatches(entry) then return false end
	if UI.search ~= "" and not string.find(Lower(entry.name), UI.search, 1, true) then
		return false
	end
	return true
end

local function FilterEntries(source)
	local out = {}
	for i = 1, #source do
		local entry = source[i]
		if Passes(entry) then out[#out + 1] = entry end
	end
	return out
end

local function CategoryEntries(source)
	local out = {}
	for i = 1, #source do
		local entry = source[i]
		if CategoryMatches(entry) then out[#out + 1] = entry end
	end
	return out
end

local function SortEntries(items)
	table.sort(items, sorters[ns.db.sort] or sorters.game)
	return items
end

local function HeaderStats(items)
	local exalted = 0
	for i = 1, #items do if items[i].exalted then exalted = exalted + 1 end end
	local complete = #items > 0 and math.floor((exalted / #items) * 100 + 0.5) or 0
	return #items, exalted, complete
end

local function AddHeader(list, key, name, level, items, parentKey, statsItems)
	local count, exalted, complete = HeaderStats(statsItems or items)
	list[#list + 1] = {
		header = true,
		key = key,
		name = name,
		level = level,
		count = count,
		exalted = exalted,
		complete = complete,
		parentKey = parentKey,
	}
end

function UI:BuildList()
	local db = ns.db
	local pool = FilterEntries(Core.entries)

	if UI.search ~= "" or not db.grouping then
		self.list = SortEntries(pool)
		return
	end

	local list = {}
	for i = 1, #Core.sections do
		local section = Core.sections[i]
		local sectionItems = FilterEntries(section.factions)
		if #sectionItems > 0 then
			AddHeader(list, section.key, section.name, 1, sectionItems, nil, CategoryEntries(section.factions))
			if not IsListCollapsed(section.key) then
				if db.sort == "game" and section.nodes then
					for n = 1, #section.nodes do
						local node = section.nodes[n]
						if node.kind == "entry" then
							local entry = node.entry
							if Passes(entry) then list[#list + 1] = entry end
						elseif node.kind == "subgroup" then
							local subgroup = node.subgroup
							local subItems = FilterEntries(subgroup.factions)
							if #subItems > 0 then
								AddHeader(list, subgroup.key, subgroup.name, 2, subItems, section.key, CategoryEntries(subgroup.factions))
								if not IsListCollapsed(subgroup.key) then
									for k = 1, #subItems do list[#list + 1] = subItems[k] end
								end
							end
						end
					end
				else
					local direct = {}
					for k = 1, #sectionItems do
						if not sectionItems[k].subgroupKey then direct[#direct + 1] = sectionItems[k] end
					end
					SortEntries(direct)
					for k = 1, #direct do list[#list + 1] = direct[k] end
					for j = 1, #section.subgroups do
						local subgroup = section.subgroups[j]
						local subItems = FilterEntries(subgroup.factions)
						if #subItems > 0 then
							SortEntries(subItems)
							AddHeader(list, subgroup.key, subgroup.name, 2, subItems, section.key, CategoryEntries(subgroup.factions))
							if not IsListCollapsed(subgroup.key) then
								for k = 1, #subItems do list[#list + 1] = subItems[k] end
							end
						end
					end
				end
			end
		end
	end
	self.list = list
end

local function ToggleListHeader(item)
	if not item or not item.header then return end
	local collapseKey = ListCollapseKey(item.key)
	if ns.db.listCollapsed[collapseKey] then
		ns.db.listCollapsed[collapseKey] = nil
	else
		ns.db.listCollapsed[collapseKey] = true
	end
	if ns.Info then ns.Info:Hide() end
	UI:BuildList()
	UI:Refresh()
end

local function CreateRow(parent)
	local row = CreateFrame("Button", nil, parent)
	row:SetHeight(ROW_H - 2)

	row.bg = row:CreateTexture(nil, "BACKGROUND")
	row.bg:SetAllPoints()
	row.bg:SetTexture(WHITE)
	row.bg:SetVertexColor(1, 1, 1, 0.02)

	row.hl = row:CreateTexture(nil, "HIGHLIGHT")
	row.hl:SetAllPoints()
	row.hl:SetTexture(WHITE)
	row.hl:SetVertexColor(0.30, 0.62, 0.95, 0.14)

	row.line = row:CreateTexture(nil, "BORDER")
	row.line:SetTexture(WHITE)
	row.line:SetVertexColor(0.22, 0.24, 0.28, 0.75)
	row.line:SetHeight(1)
	row.line:SetPoint("BOTTOMLEFT", 0, 0)
	row.line:SetPoint("BOTTOMRIGHT", 0, 0)

	row.headerTop = row:CreateTexture(nil, "BORDER")
	row.headerTop:SetTexture(WHITE)
	row.headerTop:SetHeight(1)
	row.headerTop:SetPoint("TOPLEFT", 0, 0)
	row.headerTop:SetPoint("TOPRIGHT", 0, 0)
	row.headerTop:Hide()

	row.accent = row:CreateTexture(nil, "ARTWORK")
	row.accent:SetTexture(WHITE)
	row.accent:SetPoint("TOPLEFT", 0, 0)
	row.accent:SetPoint("BOTTOMLEFT", 0, 0)
	row.accent:SetWidth(3)

	row.star = CreateFrame("Button", nil, row)
	row.star:SetSize(18, 18)
	row.star:SetPoint("TOPLEFT", 8, -9)
	row.star.tex = row.star:CreateTexture(nil, "ARTWORK")
	row.star.tex:SetAllPoints()
	row.star.tex:SetTexture("Interface\\Common\\ReputationStar")
	row.star.tex:SetTexCoord(0, 0.5, 0, 0.5)

	row.name = Text(row, 15)
	row.name:SetJustifyH("LEFT")
	if row.name.SetWordWrap then row.name:SetWordWrap(false) end

	row.standing = Text(row, 14)
	row.standing:SetPoint("TOPRIGHT", -8, -8)
	row.standing:SetWidth(128)
	row.standing:SetJustifyH("RIGHT")
	if row.standing.SetWordWrap then row.standing:SetWordWrap(false) end

	row.war = Text(row, 12, nil, 0.88, 0.26, 0.22)
	row.war:SetPoint("RIGHT", row.standing, "LEFT", -8, 0)
	row.war:SetWidth(54)
	row.war:SetJustifyH("RIGHT")
	row.war:SetText("[" .. L.AT_WAR_SHORT .. "]")
	if row.war.SetWordWrap then row.war:SetWordWrap(false) end

	row.barBG = CreateFrame("Frame", nil, row)
	row.barBG:SetPoint("TOPLEFT", 32, -34)
	row.barBG:SetPoint("TOPRIGHT", -8, -34)
	row.barBG:SetHeight(9)
	Skin(row.barBG, 0.03, 0.03, 0.04, 1, 0.16, 0.17, 0.20)

	row.bar = CreateFrame("StatusBar", nil, row.barBG)
	row.bar:SetPoint("TOPLEFT", 1, -1)
	row.bar:SetPoint("BOTTOMRIGHT", -1, 1)
	row.bar:SetStatusBarTexture(BAR_TEX)
	row.bar:SetMinMaxValues(0, 1)

	row.value = Text(row, 12, nil, 0.66, 0.68, 0.72)
	row.value:SetPoint("TOPLEFT", 32, -49)
	row.value:SetPoint("RIGHT", -150, 0)
	row.value:SetJustifyH("LEFT")
	if row.value.SetWordWrap then row.value:SetWordWrap(false) end

	row.session = Text(row, 12, nil, 0.45, 0.85, 0.45)
	row.session:SetPoint("TOPRIGHT", -8, -49)
	row.session:SetWidth(136)
	row.session:SetJustifyH("RIGHT")
	if row.session.SetWordWrap then row.session:SetWordWrap(false) end

	row.expander = CreateFrame("Button", nil, row)
	row.expander:SetSize(20, 20)
	Skin(row.expander, 0.06, 0.08, 0.11, 0.95, 0.28, 0.36, 0.46)
	row.expander.text = Text(row.expander, 15, nil, 0.88, 0.91, 0.96)
	row.expander.text:SetPoint("CENTER", 0, 1)
	row.expander:Hide()

	row.head = Text(row, 15, nil, 0.88, 0.93, 1)
	row.head:SetJustifyH("LEFT")
	if row.head.SetWordWrap then row.head:SetWordWrap(false) end

	row.headInfo = Text(row, 12, nil, 0.60, 0.64, 0.70)
	row.headInfo:SetPoint("RIGHT", -10, 0)
	row.headInfo:SetJustifyH("RIGHT")

	function row:AsHeader(item)
		self.star:Hide()
		self.name:Hide()
		self.standing:Hide()
		self.war:Hide()
		self.barBG:Hide()
		self.value:Hide()
		self.session:Hide()
		self.expander:Show()
		self.head:Show()
		self.headInfo:Show()
		self.headerTop:Show()

		local collapsed = IsListCollapsed(item.key)
		self.expander.text:SetFont(FONT, FS(15), nil)
		self.expander.text:SetText(collapsed and "+" or "-")
		self.head:SetFont(FONT, FS(item.level == 2 and 14 or 15), nil)
		self.head:ClearAllPoints()
		self.expander:ClearAllPoints()

		local active = UI.category == item.key
		local path = item.level == 1 and UI.activeSectionKey == item.key and not active
		if item.level == 2 then
			self.expander:SetPoint("LEFT", 26, 0)
			self.head:SetPoint("LEFT", 54, 0)
			self.head:SetPoint("RIGHT", self.headInfo, "LEFT", -12, 0)
			self.accent:SetVertexColor(0.40, 0.58, 0.76, 1)
			self.headerTop:SetVertexColor(0.20, 0.30, 0.40, 0.95)
			self.line:SetVertexColor(0.18, 0.25, 0.34, 0.95)
			if active then
				self.bg:SetVertexColor(0.09, 0.25, 0.39, 0.96)
				self.head:SetTextColor(0.88, 0.96, 1)
			else
				self.bg:SetVertexColor(0.075, 0.09, 0.125, 0.96)
				self.head:SetTextColor(0.72, 0.82, 0.92)
			end
		else
			self.expander:SetPoint("LEFT", 9, 0)
			self.head:SetPoint("LEFT", 37, 0)
			self.head:SetPoint("RIGHT", self.headInfo, "LEFT", -12, 0)
			self.accent:SetVertexColor(0.18, 0.55, 0.86, 1)
			self.headerTop:SetVertexColor(0.16, 0.42, 0.66, 1)
			self.line:SetVertexColor(0.13, 0.31, 0.48, 1)
			if active then
				self.bg:SetVertexColor(0.07, 0.24, 0.39, 0.98)
				self.head:SetTextColor(0.82, 0.94, 1)
			elseif path then
				self.bg:SetVertexColor(0.06, 0.18, 0.29, 0.98)
				self.head:SetTextColor(0.75, 0.88, 0.98)
			else
				self.bg:SetVertexColor(0.045, 0.12, 0.19, 0.98)
				self.head:SetTextColor(0.69, 0.84, 0.95)
			end
		end

		self.expander:SetBackdropColor(0.045, 0.065, 0.09, 1)
		self.expander:SetBackdropBorderColor(0.30, 0.48, 0.64, 1)
		self.head:SetText(item.name)
		self.headInfo:SetFont(FONT, FS(12), nil)
		local progress = "  |cff72a9d8" .. tostring(item.complete or 0) .. "%|r"
		local ex = ""
		if item.exalted > 0 then ex = "  |cffe6b34d" .. item.exalted .. " " .. Core:StandingLabel(8) .. "|r" end
		self.headInfo:SetText(item.count .. " " .. string.lower(L.FACTIONS) .. progress .. ex)
		self.item = item
	end

	function row:AsFaction(item, rowIndex)
		self.expander:Hide()
		self.head:Hide()
		self.headInfo:Hide()
		self.headerTop:Hide()
		self.star:Show()
		self.name:Show()
		self.standing:Show()
		self.barBG:Show()
		self.value:Show()
		self.line:SetVertexColor(0.22, 0.24, 0.28, 0.75)

		local r, g, b = Core:StandingColor(item.standing)
		self.accent:SetVertexColor(r, g, b, 0.98)
		local zebra = ((rowIndex or 1) % 2 == 0) and 0.050 or 0.020
		if item.watched then zebra = zebra + 0.022 end
		if IsSelectedFaction(item) then
			self.bg:SetVertexColor(0.08, 0.28, 0.50, 0.52)
			self.accent:SetWidth(5)
		else
			self.bg:SetVertexColor(1, 1, 1, zebra)
			self.accent:SetWidth(3)
		end

		self.name:SetFont(FONT, FS(15), nil)
		self.name:ClearAllPoints()
		self.name:SetPoint("TOPLEFT", 32, -8)
		if item.atWar then
			self.war:Show()
			self.war:SetFont(FONT, FS(12), nil)
			self.name:SetPoint("TOPRIGHT", self.war, "TOPLEFT", -8, 0)
		else
			self.war:Hide()
			self.name:SetPoint("TOPRIGHT", self.standing, "TOPLEFT", -10, 0)
		end
		local prefix = item.watched and "|cff4fa3e3>|r " or ""
		self.name:SetText(prefix .. item.name)
		self.name:SetTextColor(0.96, 0.96, 0.98)

		self.standing:SetFont(FONT, FS(14), nil)
		self.standing:SetText(Core:StandingLabel(item.standing))
		self.standing:SetTextColor(r, g, b)

		self.bar:SetStatusBarColor(r, g, b, 0.9)
		self.bar:SetValue(item.exalted and 1 or item.pct)

		self.value:SetFont(FONT, FS(12), nil)
		if item.exalted then
			self.value:SetText(ns.Sep(item.max) .. " / " .. ns.Sep(item.max) .. "  -  " .. L.MAXED)
		else
			self.value:SetText(ns.Sep(item.cur) .. " / " .. ns.Sep(item.max)
				.. "  -  " .. math.floor(item.pct * 100 + 0.5) .. "%"
				.. "  -  " .. L.LEFT .. " " .. ns.Sep(item.remain))
		end

		local d = Core.session[EntryKey(item)]
		self.session:SetFont(FONT, FS(12), nil)
		if d and d > 0 then
			self.session:SetText("+" .. ns.Sep(d) .. " " .. L.SESSION)
			self.session:Show()
		else
			self.session:Hide()
		end

		if Core:IsFavorite(item) then
			self.star.tex:SetVertexColor(1, 0.82, 0.25)
			self.star.tex:SetAlpha(1)
		else
			self.star.tex:SetVertexColor(0.45, 0.45, 0.5)
			self.star.tex:SetAlpha(0.55)
		end
		self.item = item
	end

	function row:SetItem(item, rowIndex)
		self.accent:SetWidth(3)
		if item.header then self:AsHeader(item) else self:AsFaction(item, rowIndex) end
	end

	row.expander:RegisterForClicks("LeftButtonUp")
	row.expander:SetScript("OnClick", function()
		ToggleListHeader(row.item)
	end)
	row.expander:SetScript("OnEnter", function(self)
		local item = row.item
		if not item or not item.header then return end
		self:SetBackdropColor(0.10, 0.24, 0.36, 1)
		self:SetBackdropBorderColor(0.34, 0.70, 0.96, 1)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine((IsListCollapsed(item.key) and L.EXPAND_SECTION or L.COLLAPSE_SECTION) .. ": " .. item.name, 1, 0.85, 0.4)
		GameTooltip:AddLine(L.SECTION_CONTROL_TIP, 0.70, 0.76, 0.84, true)
		GameTooltip:Show()
	end)
	row.expander:SetScript("OnLeave", function(self)
		self:SetBackdropColor(0.045, 0.065, 0.09, 1)
		self:SetBackdropBorderColor(0.30, 0.48, 0.64, 1)
		GameTooltip:Hide()
	end)

	row.star:SetScript("OnClick", function()
		local item = row.item
		if item and not item.header then Core:ToggleFavorite(item) end
	end)
	row.star:SetScript("OnEnter", function(self)
		local item = row.item
		if not item or item.header then return end
		self.tex:SetAlpha(1)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine(Core:IsFavorite(item) and L.FAVORITE_TIP_REMOVE or L.FAVORITE_TIP_ADD, 1, 0.85, 0.4)
		GameTooltip:Show()
	end)
	row.star:SetScript("OnLeave", function(self)
		local item = row.item
		if item and not Core:IsFavorite(item) then self.tex:SetAlpha(0.55) end
		GameTooltip:Hide()
	end)

	row:RegisterForClicks("LeftButtonUp")
	row:SetScript("OnClick", function(self)
		local item = self.item
		if not item or item.header then return end
		if IsShiftKeyDown() then
			Core:ToggleWatch(item)
		elseif IsControlKeyDown() then
			Core:ToggleFavorite(item)
		elseif type(IsAltKeyDown) == "function" and IsAltKeyDown() then
			OpenFactionChat(item)
		else
			SelectFaction(item)
			UI:Refresh()
			if ns.Info then ns.Info:Show(item) end
		end
	end)

	row:SetScript("OnEnter", function(self)
		local item = self.item
		if not item or item.header then return end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine(item.name, 1, 0.85, 0.4)
		if item.desc and item.desc ~= "" then GameTooltip:AddLine(item.desc, 0.85, 0.85, 0.85, true) end
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine(L.TIP_ROW, 0.5, 0.7, 1, true)
		GameTooltip:Show()
	end)
	row:SetScript("OnLeave", function() GameTooltip:Hide() end)
	return row
end

local function CreateSideButton(parent)
	local b = CreateFrame("Button", nil, parent)
	b:SetHeight(SIDE_ROW_H - 2)
	Skin(b, 0.09, 0.09, 0.11, 0)
	b:SetBackdropBorderColor(0, 0, 0, 0)

	b.toggle = CreateFrame("Button", nil, b)
	b.toggle:SetSize(16, 16)
	b.toggle:SetPoint("LEFT", 2, 0)
	Skin(b.toggle, 0.045, 0.055, 0.075, 1, 0.25, 0.32, 0.40)
	b.toggle.text = Text(b.toggle, 12, nil, 0.80, 0.84, 0.90)
	b.toggle.text:SetPoint("CENTER", 0, 1)
	b.toggle:Hide()

	b.label = Text(b, 13, nil, 0.72, 0.73, 0.78)
	b.label:SetPoint("LEFT", 8, 0)
	b.label:SetPoint("RIGHT", -38, 0)
	b.label:SetJustifyH("LEFT")
	if b.label.SetWordWrap then b.label:SetWordWrap(false) end

	b.count = Text(b, 11, nil, 0.50, 0.52, 0.58)
	b.count:SetPoint("RIGHT", -5, 0)

	function b:Sync()
		local item = self.data
		if not item then return end
		if item.kind == "separator" then
			self:Disable()
			self.label:SetText("")
			self.count:SetText("")
			self.toggle:Hide()
			self:SetBackdropColor(0.09, 0.09, 0.11, 0)
			self:SetBackdropBorderColor(0, 0, 0, 0)
			return
		end
		self:Enable()
		local active = UI.category == item.key
		local path = item.kind == "section" and UI.activeSectionKey == item.key and not active
		if active then
			self:SetBackdropColor(0.10, 0.29, 0.47, 1)
			self:SetBackdropBorderColor(0.22, 0.54, 0.82, 1)
			self.label:SetTextColor(0.94, 0.98, 1)
		elseif path then
			self:SetBackdropColor(0.07, 0.18, 0.28, 0.95)
			self:SetBackdropBorderColor(0.14, 0.38, 0.58, 0.95)
			self.label:SetTextColor(0.82, 0.91, 0.98)
		else
			self:SetBackdropColor(0.09, 0.09, 0.11, item.kind == "subgroup" and 0.34 or 0.58)
			self:SetBackdropBorderColor(0, 0, 0, 0)
			self.label:SetTextColor(item.kind == "subgroup" and 0.62 or 0.74, item.kind == "subgroup" and 0.69 or 0.75, item.kind == "subgroup" and 0.77 or 0.80)
		end

		self.label:SetFont(FONT, FS(item.kind == "subgroup" and 12 or 13), nil)
		self.count:SetFont(FONT, FS(11), nil)
		self.label:ClearAllPoints()
		if item.kind == "subgroup" then
			self.label:SetPoint("LEFT", 28, 0)
		else
			self.label:SetPoint("LEFT", item.hasChildren and 24 or 8, 0)
		end
		self.label:SetPoint("RIGHT", -38, 0)
		self.label:SetText(item.label or "")
		self.count:SetText(item.count or "")

		if item.hasChildren then
			self.toggle:Show()
			self.toggle.text:SetFont(FONT, FS(12), nil)
			self.toggle.text:SetText(ns.db.sidebarExpanded[item.key] == false and "+" or "-")
			self.toggle:SetBackdropColor(0.045, 0.055, 0.075, 1)
			self.toggle:SetBackdropBorderColor(0.25, 0.32, 0.40, 1)
		else
			self.toggle:Hide()
		end
	end

	b.toggle:SetScript("OnClick", function(self)
		local item = b.data
		if not item or not item.hasChildren then return end
		if ns.db.sidebarExpanded[item.key] == false then
			ns.db.sidebarExpanded[item.key] = nil
		else
			ns.db.sidebarExpanded[item.key] = false
		end
		GameTooltip:Hide()
		UI:UpdateSidebar()
	end)
	b.toggle:SetScript("OnEnter", function(self)
		local item = b.data
		if not item or not item.hasChildren then return end
		self:SetBackdropColor(0.10, 0.24, 0.36, 1)
		self:SetBackdropBorderColor(0.34, 0.70, 0.96, 1)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine((ns.db.sidebarExpanded[item.key] == false and L.EXPAND_SECTION or L.COLLAPSE_SECTION) .. ": " .. item.label, 1, 0.85, 0.4)
		GameTooltip:AddLine(L.SECTION_CONTROL_TIP, 0.70, 0.76, 0.84, true)
		GameTooltip:Show()
	end)
	b.toggle:SetScript("OnLeave", function(self)
		self:SetBackdropColor(0.045, 0.055, 0.075, 1)
		self:SetBackdropBorderColor(0.25, 0.32, 0.40, 1)
		GameTooltip:Hide()
	end)

	b:SetScript("OnClick", function(self)
		local item = self.data
		if not item or item.kind == "separator" then return end
		if ns.Info then ns.Info:Hide() end
		UI.category = item.key
		ns.db.category = item.key
		UI:ResetListScroll()
		UI:OnDataChanged()
	end)
	b:SetScript("OnEnter", function(self)
		local item = self.data
		if item and item.kind ~= "separator" and UI.category ~= item.key then self:SetBackdropColor(0.13, 0.16, 0.20, 1) end
	end)
	b:SetScript("OnLeave", function(self) self:Sync() end)
	return b
end

function UI:BuildSidebarItems()
	local favN, watchedN, warN = 0, 0, 0
	for i = 1, #Core.entries do
		local entry = Core.entries[i]
		if Core:IsFavorite(entry) then favN = favN + 1 end
		if entry.watched then watchedN = watchedN + 1 end
		if entry.atWar then warN = warN + 1 end
	end

	local items = {
		{ kind = "special", key = "__all", label = L.ALL, count = Core.stats.total },
		{ kind = "special", key = "__fav", label = L.FAVORITES, count = favN },
		{ kind = "special", key = "__watched", label = L.WATCHED, count = watchedN },
		{ kind = "special", key = "__war", label = L.AT_WAR, count = warN },
		{ kind = "separator", key = "__sep" },
	}

	for i = 1, #Core.sections do
		local section = Core.sections[i]
		items[#items + 1] = {
			kind = "section",
			key = section.key,
			label = section.name,
			count = #section.factions,
			hasChildren = #section.subgroups > 0,
		}
		if #section.subgroups > 0 and ns.db.sidebarExpanded[section.key] ~= false then
			for j = 1, #section.subgroups do
				local subgroup = section.subgroups[j]
				items[#items + 1] = {
					kind = "subgroup",
					key = subgroup.key,
					sectionKey = section.key,
					label = subgroup.name,
					count = #subgroup.factions,
				}
			end
		end
	end
	return items
end

function UI:UpdateSidebar()
	local items = self:BuildSidebarItems()
	local valid = self.category == "__all" or self.category == "__fav" or self.category == "__watched" or self.category == "__war"
	self.activeSectionKey = nil

	if not valid then
		local section = Core:GetSection(self.category)
		if section then
			valid = true
			self.activeSectionKey = section.key
		else
			local subgroup, parent = Core:GetSubgroup(self.category)
			if subgroup and parent then
				valid = true
				self.activeSectionKey = parent.key
			end
		end
	end

	if not valid then
		self.category = "__all"
		ns.db.category = "__all"
	end

	self.sidebarItems = items
	for i = 1, #items do
		local b = sideButtons[i]
		if not b then
			b = CreateSideButton(self.sideContent)
			sideButtons[i] = b
		end
		b:ClearAllPoints()
		b:SetPoint("TOPLEFT", 0, -(i - 1) * SIDE_ROW_H)
		b:SetPoint("TOPRIGHT", 0, -(i - 1) * SIDE_ROW_H)
		b.data = items[i]
		b:Sync()
		b:Show()
	end
	for i = #items + 1, #sideButtons do sideButtons[i]:Hide() end

	local contentH = math.max(1, #items * SIDE_ROW_H)
	self.sideContent:SetHeight(contentH)
	local maxScroll = math.max(0, contentH - (self.sideScroll:GetHeight() or 0))
	local current = self.sideScroll:GetVerticalScroll() or 0
	if current > maxScroll then self.sideScroll:SetVerticalScroll(maxScroll) end
end

function UI:ResetListScroll()
	if not self.scroll then return end
	FauxScrollFrame_SetOffset(self.scroll, 0)
	local sb = _G["SirusRepScrollScrollBar"]
	if sb then sb:SetValue(0) end
end

function UI:ClampListScroll()
	if not self.scroll then return end
	local n = #self.list
	local maxOffset = math.max(0, n - (self.visible or 1))
	local offset = FauxScrollFrame_GetOffset(self.scroll) or 0
	if offset > maxOffset then
		FauxScrollFrame_SetOffset(self.scroll, maxOffset)
		local sb = _G["SirusRepScrollScrollBar"]
		if sb then sb:SetValue(maxOffset * ROW_H) end
	end
end

function UI:HasActiveFilters()
	local db = ns.db
	return UI.search ~= ""
		or UI.category ~= "__all"
		or db.hideExalted
		or (tonumber(db.standingFilter) or 0) > 0
		or db.sort ~= "game"
end

function UI:ResetFilters()
	if self._resetting then return end
	local db = ns.db
	self._resetting = true
	db.hideExalted = false
	db.standingFilter = 0
	db.sort = "game"
	db.category = "__all"
	db.search = ""
	UI.category = "__all"
	UI.search = ""
	if self.standingMenu then self.standingMenu:Hide() end
	if self.edit and self.edit:GetText() ~= "" then self.edit:SetText("") end
	if ns.Info then ns.Info:Hide(false, true) end
	self:ResetListScroll()
	self._resetting = nil
	self:OnDataChanged()
end

function UI:SyncSearchState()
	if not self.searchBox then return end
	local active = UI.search ~= ""
	if active then
		self.searchBox:SetBackdropColor(0.12, 0.085, 0.025, 1)
		self.searchBox:SetBackdropBorderColor(0.95, 0.62, 0.12, 1)
		if self.searchIcon then self.searchIcon:SetVertexColor(1, 0.72, 0.18) end
	else
		self.searchBox:SetBackdropColor(0.03, 0.03, 0.045, 1)
		self.searchBox:SetBackdropBorderColor(0.22, 0.24, 0.30, 1)
		if self.searchIcon then self.searchIcon:SetVertexColor(0.55, 0.57, 0.62) end
	end
end

function UI:SyncControls()
	self:SyncSearchState()
	if self.sortBtn then self.sortBtn:Sync() end
	if self.standingBtn then self.standingBtn:Sync() end
	if self.resetBtn then self.resetBtn:Sync() end
	if self.toggles then for i = 1, #self.toggles do self.toggles[i]:Sync() end end
	if self.searchHint then self.searchHint:SetFont(FONT, FS(13), nil) end
	if self.edit then self.edit:SetFont(FONT, FS(14), nil) end
end

function UI:LayoutStats()
	local avail = (self.footer:GetWidth() or 600) - 100
	if avail < 120 then avail = 120 end
	local n = math.floor(avail / 88)
	if n < 3 then n = 3 end
	if n > 7 then n = 7 end
	self.statCount = n
	local bw = math.floor(avail / n)
	for i = 1, 7 do
		local blk = self.statBlocks[i]
		blk:ClearAllPoints()
		blk:SetPoint("LEFT", self.footer, "LEFT", 8 + (i - 1) * bw, 0)
		blk:SetWidth(bw)
	end
end

function UI:UpdateStats()
	local s = Core.stats
	local bs = s.byStanding or {}
	local function C(i) return bs[i] or 0 end
	local all = {
		{ L.FACTIONS, s.total or 0, 0.85, 0.86, 0.90 },
		{ Core:StandingLabel(8), C(8), Core:StandingColor(8) },
		{ Core:StandingLabel(7), C(7), Core:StandingColor(7) },
		{ Core:StandingLabel(6), C(6), Core:StandingColor(6) },
		{ Core:StandingLabel(5), C(5), Core:StandingColor(5) },
		{ Core:StandingLabel(4), C(4), Core:StandingColor(4) },
		{ L.PROGRESS_TOTAL, (s.progress or 0) .. "%", 0.98, 0.82, 0.35 },
	}
	local priority = { 1, 2, 7, 3, 4, 5, 6 }
	local keep = {}
	for i = 1, (self.statCount or 7) do keep[priority[i]] = true end
	local blocks = {}
	for i = 1, #all do if keep[i] then blocks[#blocks + 1] = all[i] end end
	for i = 1, #self.statBlocks do
		local blk = self.statBlocks[i]
		local d = blocks[i]
		if d then
			blk.caption:SetFont(FONT, FS(11), nil)
			blk.caption:SetText(d[1])
			blk.caption:SetTextColor(d[3], d[4], d[5])
			blk.value:SetFont(FONT, FS(18), nil)
			blk.value:SetText(d[2])
			blk.value:SetTextColor(d[3], d[4], d[5])
			blk:Show()
		else
			blk:Hide()
		end
	end
end

local function RawSpecialCategoryCount(category)
	local count = 0
	for i = 1, #Core.entries do
		local entry = Core.entries[i]
		if category == "__fav" and Core:IsFavorite(entry) then
			count = count + 1
		elseif category == "__watched" and entry.watched then
			count = count + 1
		elseif category == "__war" and entry.atWar then
			count = count + 1
		end
	end
	return count
end

function UI:Refresh()
	if not self.frame or not self.frame:IsShown() then return end
	local n = #self.list
	FauxScrollFrame_Update(self.scroll, n, self.visible, ROW_H)
	self:ClampListScroll()
	local offset = FauxScrollFrame_GetOffset(self.scroll) or 0
	for i = 1, #rows do
		local row = rows[i]
		if i <= self.visible then
			local item = self.list[i + offset]
			if item then row:SetItem(item, i + offset); row:Show() else row:Hide() end
		else
			row:Hide()
		end
	end
	if n == 0 then
		self.empty:SetFont(FONT, FS(14), nil)
		local emptyText = L.NO_FACTIONS
		if UI.search ~= "" then
			local rawSearch = (ns.db and ns.db.search) or ""
			emptyText = L.SEARCH_ACTIVE .. ': "' .. SearchPreview(rawSearch, 36) .. '". ' .. L.NOTHING_FOUND
		elseif UI.category == "__fav" then
			emptyText = RawSpecialCategoryCount("__fav") > 0 and L.HIDDEN_BY_FILTERS or L.NO_FAVORITES
		elseif UI.category == "__watched" then
			emptyText = RawSpecialCategoryCount("__watched") > 0 and L.HIDDEN_BY_FILTERS or L.NO_WATCHED
		elseif UI.category == "__war" then
			emptyText = RawSpecialCategoryCount("__war") > 0 and L.HIDDEN_BY_FILTERS or L.NO_AT_WAR
		end
		self.empty:SetText(emptyText)
		self.empty:Show()
	else
		self.empty:Hide()
	end
	self.subtitle:SetFont(FONT, FS(12), nil)
	local subtitle = Core.stats.total .. " " .. string.lower(L.FACTIONS)
	if UI.search ~= "" then
		subtitle = subtitle .. "  |cffffa51f" .. L.SEARCH_ACTIVE .. "|r"
	end
	self.subtitle:SetText(subtitle)
end

function UI:OnDataChanged()
	if not self.frame then return end
	self:SyncControls()
	self:LayoutStats()
	self:UpdateSidebar()
	self:BuildList()
	self:UpdateStats()
	self:Refresh()
	if ns.Info then ns.Info:RefreshCurrent() end
end

function UI:Relayout()
	if ns.Info then ns.Info:Reanchor() end
	self:LayoutStats()
	self:UpdateStats()
	local h = self.scroll:GetHeight() or 0
	local vis = self.visible or 8

	if h < ROW_H then
		if not self._relayoutPending then
			self._relayoutPending = true
			ns.Defer(function()
				UI._relayoutPending = nil
				if UI.frame and UI.frame:IsShown() then
					UI:Relayout()
					UI:Refresh()
				end
			end)
		end
	else
		vis = math.floor(h / ROW_H)
	end

	if vis < 1 then vis = 1 end
	if vis > 40 then vis = 40 end
	self.visible = vis
	for i = 1, vis do
		if not rows[i] then rows[i] = CreateRow(self.listArea) end
		local row = rows[i]
		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", self.scroll, "TOPLEFT", 0, -(i - 1) * ROW_H)
		row:SetPoint("TOPRIGHT", self.scroll, "TOPRIGHT", 0, -(i - 1) * ROW_H)
	end
	self:UpdateSidebar()
	self:Refresh()
end

function UI:Init()
	if self.frame then return end
	local db = ns.db
	self.category = db.category or "__all"
	self.search = Lower(db.search or "")
	db.standingFilter = tonumber(db.standingFilter) or 0
	if db.standingFilter < 0 or db.standingFilter > 8 then db.standingFilter = 0 end

	local f = CreateFrame("Frame", "SirusRepFrame", UIParent)
	self.frame = f
	f:SetSize(db.width, db.height)
	f:SetPoint(db.point, UIParent, db.point, db.x, db.y)
	f:SetFrameStrata("HIGH")
	f:SetToplevel(true)
	f:EnableMouse(true)
	f:SetMovable(true)
	f:SetResizable(true)
	if f.SetMinResize then f:SetMinResize(720, 440) end
	if f.SetMaxResize then f:SetMaxResize(1400, 1000) end
	Skin(f, 0.055, 0.058, 0.07, 0.97)
	f:Hide()
	tinsert(UISpecialFrames, "SirusRepFrame")

	local header = CreateFrame("Frame", nil, f)
	header:SetPoint("TOPLEFT", 1, -1)
	header:SetPoint("TOPRIGHT", -1, -1)
	header:SetHeight(40)
	Skin(header, 0.09, 0.11, 0.15, 1, 0.09, 0.11, 0.15)
	header:EnableMouse(true)
	header:RegisterForDrag("LeftButton")
	header:SetScript("OnMouseDown", function() f:StartMoving() end)
	header:SetScript("OnMouseUp", function()
		f:StopMovingOrSizing()
		local p, _, _, x, y = f:GetPoint()
		db.point, db.x, db.y = p, math.floor(x), math.floor(y)
		if ns.Info then ns.Info:Reanchor() end
	end)

	local title = Text(header, 17)
	title:SetPoint("LEFT", 14, 0)
	title:SetText("|cff1784d1SirusRep|r")
	self.title = title

	self.subtitle = Text(header, 12, nil, 0.55, 0.57, 0.63)
	self.subtitle:SetPoint("LEFT", title, "RIGHT", 10, 0)

	local close = CreateFrame("Button", nil, header, "UIPanelCloseButton")
	close:SetPoint("RIGHT", -4, 0)
	close:SetScript("OnClick", function() UI:Hide() end)

	local tool = CreateFrame("Frame", nil, f)
	tool:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 10, -8)
	tool:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", -10, -8)
	tool:SetHeight(26)

	local tool2 = CreateFrame("Frame", nil, f)
	tool2:SetPoint("TOPLEFT", tool, "BOTTOMLEFT", 0, -6)
	tool2:SetPoint("TOPRIGHT", tool, "BOTTOMRIGHT", 0, -6)
	tool2:SetHeight(26)

	local sortBtn = CreateFrame("Button", nil, tool)
	sortBtn:SetHeight(26)
	sortBtn:SetPoint("RIGHT", 0, 0)
	Skin(sortBtn, 0.11, 0.11, 0.14, 1)
	sortBtn.label = Text(sortBtn, 12, nil, 0.80, 0.82, 0.88)
	sortBtn.label:SetPoint("CENTER")
	function sortBtn:Sync()
		self.label:SetFont(FONT, FS(12), nil)
		self.label:SetText(L.SORT .. ": " .. (sortLabels[db.sort] or ""))
		self:SetWidth(self.label:GetStringWidth() + 24)
	end
	sortBtn:SetScript("OnClick", function(self)
		local idx = 1
		for i = 1, #sortOrder do if sortOrder[i] == db.sort then idx = i end end
		db.sort = sortOrder[(idx % #sortOrder) + 1]
		self:Sync()
		UI:OnDataChanged()
	end)
	sortBtn:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(0.45, 0.65, 0.9, 1) end)
	sortBtn:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(0.22, 0.24, 0.30, 1) end)
	sortBtn:Sync()
	self.sortBtn = sortBtn

	local grpBtn = MakeToggle(tool2, L.GROUPING,
		function() return db.grouping end,
		function() db.grouping = not db.grouping; UI:OnDataChanged() end)
	grpBtn:SetPoint("LEFT", 0, 0)

	local exBtn = MakeToggle(tool2, L.HIDE_EXALTED,
		function() return db.hideExalted end,
		function() db.hideExalted = not db.hideExalted; UI:OnDataChanged() end)
	exBtn:SetPoint("LEFT", grpBtn, "RIGHT", 6, 0)
	self.toggles = { grpBtn, exBtn }

	local standingBtn = CreateFrame("Button", nil, tool2)
	standingBtn:SetHeight(26)
	standingBtn:SetPoint("LEFT", exBtn, "RIGHT", 6, 0)
	Skin(standingBtn, 0.11, 0.11, 0.14, 1)
	standingBtn.label = Text(standingBtn, 12, nil, 0.80, 0.82, 0.88)
	standingBtn.label:SetPoint("CENTER")
	function standingBtn:Sync()
		local filter = tonumber(db.standingFilter) or 0
		local label = filter > 0 and Core:StandingLabel(filter) or L.STANDING_ALL
		self.label:SetFont(FONT, FS(12), nil)
		self.label:SetText(L.STANDING_FILTER .. ": " .. label)
		self:SetWidth(self.label:GetStringWidth() + 24)
		if filter > 0 then
			self:SetBackdropColor(0.09, 0.29, 0.47, 1)
			self:SetBackdropBorderColor(0.20, 0.52, 0.82, 1)
		else
			self:SetBackdropColor(0.11, 0.11, 0.14, 1)
			self:SetBackdropBorderColor(0.22, 0.24, 0.30, 1)
		end
	end
	standingBtn:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(0.45, 0.65, 0.9, 1) end)
	standingBtn:SetScript("OnLeave", function(self) self:Sync() end)
	standingBtn:Sync()
	self.standingBtn = standingBtn

	local standingMenu = CreateFrame("Frame", "SirusRepStandingMenu", f)
	standingMenu:SetWidth(190)
	standingMenu:SetHeight(206)
	standingMenu:SetPoint("TOPLEFT", standingBtn, "BOTTOMLEFT", 0, -3)
	standingMenu:SetFrameStrata("DIALOG")
	standingMenu:SetFrameLevel((f:GetFrameLevel() or 1) + 30)
	Skin(standingMenu, 0.045, 0.048, 0.06, 0.99)
	standingMenu:Hide()
	tinsert(UISpecialFrames, "SirusRepStandingMenu")
	self.standingMenu = standingMenu

	local standingOptions = { { value = 0, label = L.STANDING_ALL } }
	for i = 1, 8 do standingOptions[#standingOptions + 1] = { value = i, label = Core:StandingLabel(i) } end
	for i = 1, #standingOptions do
		local option = standingOptions[i]
		local value = option.value
		local b = CreateFrame("Button", nil, standingMenu)
		b:SetHeight(21)
		b:SetPoint("TOPLEFT", 4, -4 - (i - 1) * 22)
		b:SetPoint("TOPRIGHT", -4, -4 - (i - 1) * 22)
		b.bg = b:CreateTexture(nil, "BACKGROUND")
		b.bg:SetAllPoints()
		b.bg:SetTexture(WHITE)
		b.bg:SetVertexColor(1, 1, 1, 0)
		b.label = Text(b, 12)
		b.label:SetPoint("LEFT", 8, 0)
		b.label:SetPoint("RIGHT", -8, 0)
		b.label:SetJustifyH("LEFT")
		b.label:SetText(option.label)
		if value > 0 then
			local r, g, bb = Core:StandingColor(value)
			b.label:SetTextColor(r, g, bb)
		else
			b.label:SetTextColor(0.86, 0.87, 0.90)
		end
		b:SetScript("OnEnter", function(self) self.bg:SetVertexColor(0.22, 0.47, 0.70, 0.24) end)
		b:SetScript("OnLeave", function(self) self.bg:SetVertexColor(1, 1, 1, 0) end)
		b:SetScript("OnClick", function()
			db.standingFilter = value
			standingMenu:Hide()
			UI:OnDataChanged()
		end)
	end
	standingBtn:SetScript("OnClick", function()
		if standingMenu:IsShown() then standingMenu:Hide() else standingMenu:Show() end
	end)

	local resetBtn = CreateFrame("Button", nil, tool2)
	resetBtn:SetHeight(26)
	resetBtn:SetPoint("LEFT", standingBtn, "RIGHT", 6, 0)
	Skin(resetBtn, 0.11, 0.11, 0.14, 1)
	resetBtn.label = Text(resetBtn, 12, nil, 0.80, 0.82, 0.88)
	resetBtn.label:SetPoint("CENTER")
	function resetBtn:Sync()
		self.label:SetFont(FONT, FS(12), nil)
		self.label:SetText(L.RESET_FILTERS)
		self:SetWidth(self.label:GetStringWidth() + 24)
		self.hasActiveFilters = UI:HasActiveFilters()
		if self.hasActiveFilters then
			self:SetBackdropColor(0.11, 0.11, 0.14, 1)
			self:SetBackdropBorderColor(0.22, 0.24, 0.30, 1)
			self.label:SetTextColor(0.80, 0.82, 0.88)
		else
			self:SetBackdropColor(0.07, 0.07, 0.085, 1)
			self:SetBackdropBorderColor(0.14, 0.15, 0.18, 1)
			self.label:SetTextColor(0.42, 0.43, 0.47)
		end
	end
	resetBtn:SetScript("OnClick", function()
		if UI:HasActiveFilters() then UI:ResetFilters() end
	end)
	resetBtn:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
		GameTooltip:AddLine(L.RESET_FILTERS, 1, 0.85, 0.4)
		GameTooltip:AddLine(L.RESET_FILTERS_TIP, 0.70, 0.76, 0.84, true)
		GameTooltip:Show()
		if self.hasActiveFilters then self:SetBackdropBorderColor(0.45, 0.65, 0.9, 1) end
	end)
	resetBtn:SetScript("OnLeave", function(self)
		GameTooltip:Hide()
		if self.hasActiveFilters then
			self:SetBackdropBorderColor(0.22, 0.24, 0.30, 1)
		else
			self:SetBackdropBorderColor(0.14, 0.15, 0.18, 1)
		end
	end)
	resetBtn:Sync()
	self.resetBtn = resetBtn

	local searchBox = CreateFrame("Frame", nil, tool)
	searchBox:SetPoint("LEFT", 0, 0)
	searchBox:SetPoint("RIGHT", sortBtn, "LEFT", -8, 0)
	searchBox:SetHeight(26)
	Skin(searchBox, 0.03, 0.03, 0.045, 1)
	self.searchBox = searchBox

	local magn = searchBox:CreateTexture(nil, "ARTWORK")
	magn:SetSize(14, 14)
	magn:SetPoint("LEFT", 8, 0)
	magn:SetTexture("Interface\\Common\\UI-Searchbox-Icon")
	magn:SetVertexColor(0.55, 0.57, 0.62)
	self.searchIcon = magn

	local edit = CreateFrame("EditBox", nil, searchBox)
	edit:SetPoint("LEFT", 28, 0)
	edit:SetPoint("RIGHT", -26, 0)
	edit:SetHeight(24)
	edit:SetAutoFocus(false)
	edit:SetMaxLetters(80)
	edit:SetFont(FONT, FS(14), nil)
	edit:SetTextColor(0.95, 0.95, 0.95)
	self.edit = edit

	local hint = Text(searchBox, 13, nil, 0.42, 0.43, 0.48)
	hint:SetPoint("LEFT", 28, 0)
	hint:SetPoint("RIGHT", -26, 0)
	hint:SetJustifyH("LEFT")
	hint:SetText(L.SEARCH_HINT)
	self.searchHint = hint

	local clear = CreateFrame("Button", nil, searchBox, "UIPanelCloseButton")
	clear:SetSize(22, 22)
	clear:SetPoint("RIGHT", -2, 0)
	clear:SetScript("OnClick", function() edit:SetText(""); edit:ClearFocus() end)

	edit:SetScript("OnTextChanged", function(self)
		local t = self:GetText() or ""
		UI.search = Lower(t)
		db.search = t
		if t == "" then hint:Show(); clear:Hide() else hint:Hide(); clear:Show() end
		if UI._resetting then return end
		UI:BuildList()
		UI:SyncControls()
		FauxScrollFrame_SetOffset(UI.scroll, 0)
		local sb = _G["SirusRepScrollScrollBar"]
		if sb then sb:SetValue(0) end
		UI:Refresh()
	end)
	edit:SetScript("OnEscapePressed", function(self)
		if self:GetText() ~= "" then self:SetText("") end
		self:ClearFocus()
	end)
	edit:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
	clear:Hide()

	local footer = CreateFrame("Frame", nil, f)
	footer:SetPoint("BOTTOMLEFT", 10, 10)
	footer:SetPoint("BOTTOMRIGHT", -10, 10)
	footer:SetHeight(52)
	Skin(footer, 0.085, 0.088, 0.105, 1)
	self.footer = footer

	self.statBlocks = {}
	for i = 1, 7 do
		local blk = CreateFrame("Frame", nil, footer)
		blk:SetHeight(44)
		blk.caption = Text(blk, 11, nil, 0.6, 0.6, 0.65)
		blk.caption:SetPoint("TOP", 0, -4)
		blk.value = Text(blk, 18)
		blk.value:SetPoint("TOP", 0, -18)
		self.statBlocks[i] = blk
	end

	local chk = CreateFrame("CheckButton", "SirusRepReplaceChk", footer, "UICheckButtonTemplate")
	chk:SetSize(24, 24)
	chk:SetPoint("RIGHT", -8, 0)
	chk:SetChecked(db.replaceTab)
	chk:SetScript("OnClick", function(self) db.replaceTab = self:GetChecked() and true or false end)
	chk:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
		GameTooltip:AddLine(L.REPLACE_TAB, 1, 1, 1)
		GameTooltip:AddLine(L.REPLACE_TAB_TIP, 0.7, 0.7, 0.7, true)
		GameTooltip:Show()
	end)
	chk:SetScript("OnLeave", function() GameTooltip:Hide() end)

	local function TipButton(btn, tip)
		btn:SetScript("OnEnter", function(self)
			self:SetBackdropBorderColor(0.45, 0.65, 0.9, 1)
			GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
			GameTooltip:AddLine(tip, 1, 1, 1)
			GameTooltip:Show()
		end)
		btn:SetScript("OnLeave", function(self)
			self:SetBackdropBorderColor(0.22, 0.24, 0.30, 1)
			GameTooltip:Hide()
		end)
	end

	local plus = CreateFrame("Button", nil, footer)
	plus:SetSize(22, 22)
	plus:SetPoint("RIGHT", chk, "LEFT", -6, 0)
	Skin(plus, 0.12, 0.12, 0.15, 1)
	local pt = Text(plus, 14); pt:SetPoint("CENTER"); pt:SetText("+")
	TipButton(plus, L.FONT_BIGGER)

	local minus = CreateFrame("Button", nil, footer)
	minus:SetSize(22, 22)
	minus:SetPoint("RIGHT", plus, "LEFT", -4, 0)
	Skin(minus, 0.12, 0.12, 0.15, 1)
	local mt = Text(minus, 14); mt:SetPoint("CENTER"); mt:SetText("-")
	TipButton(minus, L.FONT_SMALLER)

	minus:SetScript("OnClick", function()
		db.fontScale = math.max(0.85, (db.fontScale or 1) - 0.05)
		UI:OnDataChanged()
	end)
	plus:SetScript("OnClick", function()
		db.fontScale = math.min(1.35, (db.fontScale or 1) + 0.05)
		UI:OnDataChanged()
	end)

	local side = CreateFrame("Frame", nil, f)
	side:SetPoint("TOPLEFT", tool2, "BOTTOMLEFT", 0, -8)
	side:SetPoint("BOTTOM", footer, "TOP", 0, 8)
	side:SetWidth(SIDE_W)
	Skin(side, 0.035, 0.037, 0.045, 0.55, 0.13, 0.14, 0.17)
	self.sidebar = side

	local sideScroll = CreateFrame("ScrollFrame", nil, side)
	sideScroll:SetPoint("TOPLEFT", 4, -4)
	sideScroll:SetPoint("BOTTOMRIGHT", -4, 4)
	sideScroll:EnableMouseWheel(true)
	self.sideScroll = sideScroll

	local sideContent = CreateFrame("Frame", nil, sideScroll)
	sideContent:SetWidth(SIDE_W - 10)
	sideContent:SetHeight(1)
	sideScroll:SetScrollChild(sideContent)
	self.sideContent = sideContent

	sideScroll:SetScript("OnMouseWheel", function(self, delta)
		local maxScroll = math.max(0, (sideContent:GetHeight() or 0) - (self:GetHeight() or 0))
		local value = (self:GetVerticalScroll() or 0) - delta * SIDE_ROW_H * 3
		if value < 0 then value = 0 end
		if value > maxScroll then value = maxScroll end
		self:SetVerticalScroll(value)
	end)

	local listArea = CreateFrame("Frame", nil, f)
	listArea:SetPoint("TOPLEFT", side, "TOPRIGHT", 8, 0)
	listArea:SetPoint("BOTTOMRIGHT", footer, "TOPRIGHT", 0, 8)
	Skin(listArea, 0.035, 0.037, 0.045, 1)
	self.listArea = listArea

	local scroll = CreateFrame("ScrollFrame", "SirusRepScroll", listArea, "FauxScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 4, -4)
	scroll:SetPoint("BOTTOMRIGHT", -26, 4)
	self.scroll = scroll
	scroll:SetScript("OnVerticalScroll", function(self, offset)
		FauxScrollFrame_OnVerticalScroll(self, offset, ROW_H, function() UI:Refresh() end)
	end)
	scroll:EnableMouseWheel(true)
	scroll:SetScript("OnMouseWheel", function(self, delta)
		local sb = _G["SirusRepScrollScrollBar"]
		if sb then sb:SetValue(sb:GetValue() - delta * ROW_H * 3) end
	end)
	scroll:SetScript("OnSizeChanged", function(self)
		local vis = math.floor((self:GetHeight() or 0) / ROW_H)
		if vis < 1 then vis = 1 end
		if vis ~= UI.visible then UI:Relayout() end
	end)

	self.empty = Text(listArea, 14, nil, 0.55, 0.56, 0.62)
	self.empty:SetPoint("LEFT", listArea, "LEFT", 24, 20)
	self.empty:SetPoint("RIGHT", listArea, "RIGHT", -24, 20)
	self.empty:SetJustifyH("CENTER")
	self.empty:SetJustifyV("MIDDLE")
	self.empty:SetWordWrap(true)
	self.empty:Hide()

	local grip = CreateFrame("Button", nil, f)
	grip:SetSize(16, 16)
	grip:SetPoint("BOTTOMRIGHT", -2, 2)
	grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
	grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
	grip:SetScript("OnMouseDown", function() f:StartSizing("BOTTOMRIGHT") end)
	grip:SetScript("OnMouseUp", function()
		f:StopMovingOrSizing()
		db.width, db.height = math.floor(f:GetWidth()), math.floor(f:GetHeight())
		UI:Relayout()
	end)

	f:SetScript("OnSizeChanged", function() UI:Relayout() end)
	f:SetScript("OnShow", function()
		UI:Relayout()
		UI:OnDataChanged()
		ns.Defer(function()
			if UI.frame and UI.frame:IsShown() then
				UI:Relayout()
				UI:OnDataChanged()
			end
		end)
	end)
	f:SetScript("OnHide", function()
		if ns.Info then ns.Info:Hide(true) end
		ns.RestoreCharacterTab()
	end)

	edit:SetText(db.search or "")
	self:SyncSearchState()
	edit:ClearFocus()
	self:Relayout()
end

function UI:Show()
	self:Init()
	if ReputationFrame then ReputationFrame:Hide() end
	if CharacterFrame and CharacterFrame:IsShown() then HideUIPanel(CharacterFrame) end
	Core:Scan()
	self.frame:Show()
	ns.Defer(function()
		if UI.frame and UI.frame:IsShown() then
			UI:Relayout()
			UI:OnDataChanged()
		end
	end)

	if ns.db.infoShown and SirusRepCharDB and ns.Info then
		local selected = Core:FindEntry(SirusRepCharDB.selectedFactionID, SirusRepCharDB.selectedFaction)
		if selected then ns.Defer(function() ns.Info:Show(selected) end) end
	end
	PlaySound("igCharacterInfoOpen")
end

function UI:Hide()
	if self.frame then
		self.frame:Hide()
		PlaySound("igCharacterInfoClose")
	end
end

function UI:Toggle()
	self:Init()
	if self.frame:IsShown() then self:Hide() else self:Show() end
end
