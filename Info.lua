local _, ns = ...
local L, Core = ns.L, ns.Core

local Info = {}
ns.Info = Info

local FONT  = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
local WHITE = "Interface\\Buttons\\WHITE8X8"
local WIDTH = 350

local function Skin(f, r, g, b, a, er, eg, eb)
	f:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
	f:SetBackdropColor(r or 0.055, g or 0.058, b or 0.07, a or 0.97)
	f:SetBackdropBorderColor(er or 0.22, eg or 0.24, eb or 0.30, 1)
end

local function Text(parent, size, r, g, b)
	local fs = parent:CreateFontString(nil, "OVERLAY")
	fs:SetFont(FONT, size, nil)
	fs:SetTextColor(r or 0.88, g or 0.88, b or 0.90)
	fs:SetJustifyH("LEFT")
	fs:SetJustifyV("TOP")
	return fs
end

local function FS(size)
	return math.floor(size * ((ns.db and ns.db.fontScale) or 1) + 0.5)
end

local SECTIONS = { "desc", "where", "dailies", "turnin", "rewards", "tip" }
local TITLES

local function MakeButton(parent, w, onClick)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(w, 26)
	Skin(b, 0.11, 0.11, 0.14, 1)
	b.label = Text(b, 12, 0.80, 0.82, 0.88)
	b.label:SetPoint("CENTER")
	b.label:SetJustifyH("CENTER")
	b:SetScript("OnClick", onClick)
	b:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(0.45, 0.65, 0.9, 1) end)
	b:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(0.22, 0.24, 0.30, 1) end)
	return b
end

function Info:Init()
	if self.frame then return end

	TITLES = {
		desc    = L.INFO_DESC,
		where   = L.INFO_WHERE,
		dailies = L.INFO_DAILIES,
		turnin  = L.INFO_TURNIN,
		rewards = L.INFO_REWARDS,
		tip     = L.INFO_TIP,
	}

	local f = CreateFrame("Frame", "SirusRepInfoFrame", ns.UI.frame)
	self.frame = f
	f:SetWidth(WIDTH)
	f:SetFrameStrata("HIGH")
	f:SetFrameLevel((ns.UI.frame:GetFrameLevel() or 1) + 10)
	f:EnableMouse(true)
	Skin(f)
	f:Hide()

	local header = CreateFrame("Frame", nil, f)
	header:SetPoint("TOPLEFT", 1, -1)
	header:SetPoint("TOPRIGHT", -1, -1)
	header:SetHeight(40)
	Skin(header, 0.09, 0.11, 0.15, 1, 0.09, 0.11, 0.15)

	self.title = Text(header, 15, 1, 0.85, 0.40)
	self.title:SetPoint("LEFT", 12, 6)
	self.title:SetPoint("RIGHT", -30, 6)
	self.title:SetJustifyV("MIDDLE")

	self.standing = Text(header, 12, 0.7, 0.72, 0.78)
	self.standing:SetPoint("TOPLEFT", 12, -22)
	self.standing:SetPoint("TOPRIGHT", -30, -22)

	local close = CreateFrame("Button", nil, header, "UIPanelCloseButton")
	close:SetSize(24, 24)
	close:SetPoint("TOPRIGHT", -2, -2)
	close:SetScript("OnClick", function() Info:Hide() end)

	local barBG = CreateFrame("Frame", nil, f)
	barBG:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 10, -8)
	barBG:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", -10, -8)
	barBG:SetHeight(14)
	Skin(barBG, 0.03, 0.03, 0.04, 1, 0.16, 0.17, 0.20)
	self.barBG = barBG

	local bar = CreateFrame("StatusBar", nil, barBG)
	bar:SetPoint("TOPLEFT", 1, -1)
	bar:SetPoint("BOTTOMRIGHT", -1, 1)
	bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
	bar:SetMinMaxValues(0, 1)
	self.bar = bar

	self.barText = Text(f, 12, 0.66, 0.68, 0.72)
	self.barText:SetPoint("TOPLEFT", barBG, "BOTTOMLEFT", 0, -5)
	self.barText:SetPoint("TOPRIGHT", barBG, "BOTTOMRIGHT", 0, -5)

	local btnRow = CreateFrame("Frame", nil, f)
	btnRow:SetPoint("BOTTOMLEFT", 10, 10)
	btnRow:SetPoint("BOTTOMRIGHT", -10, 10)
	btnRow:SetHeight(26)

	self.btnWatch = MakeButton(btnRow, 1, function()
		if Info.current then Core:ToggleWatch(Info.current) end
	end)
	self.btnWatch:SetPoint("LEFT", 0, 0)

	self.btnFav = MakeButton(btnRow, 1, function()
		if Info.current then Core:ToggleFavorite(Info.current) end
	end)
	self.btnFav:SetPoint("CENTER", 0, 0)

	self.btnWar = MakeButton(btnRow, 1, function()
		if Info.current then Core:ToggleWar(Info.current) end
	end)
	self.btnWar:SetPoint("RIGHT", 0, 0)

	self.btnRow = btnRow

	local btnEdit = MakeButton(f, 1, function()
		if Info.current then Info:OpenEditor(Info.current) end
	end)
	btnEdit:ClearAllPoints()
	btnEdit:SetPoint("BOTTOMLEFT", 10, 42)
	btnEdit:SetPoint("BOTTOMRIGHT", -10, 42)
	self.btnEdit = btnEdit

	local scroll = CreateFrame("ScrollFrame", "SirusRepInfoScroll", f, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", self.barText, "BOTTOMLEFT", 0, -10)
	scroll:SetPoint("BOTTOMRIGHT", btnEdit, "TOPRIGHT", -24, 8)
	self.scroll = scroll

	local content = CreateFrame("Frame", nil, scroll)
	content:SetSize(WIDTH - 46, 10)
	scroll:SetScrollChild(content)
	self.content = content

	self.sections = {}
	for i = 1, #SECTIONS do
		local key = SECTIONS[i]
		local s = {}
		s.title = Text(content, 13, 0.36, 0.65, 0.92)
		s.body  = Text(content, 13, 0.82, 0.83, 0.86)
		self.sections[key] = s
	end

	self.empty = Text(content, 13, 0.55, 0.56, 0.62)
	self.note  = Text(content, 12, 0.50, 0.52, 0.58)
end

function Info:Reanchor()
	local f, main = self.frame, ns.UI.frame
	if not f or not main then return end

	local screenW = UIParent:GetWidth() or 1024
	local right = main:GetRight()
	local left  = main:GetLeft()
	if not right or not left then return end

	f:ClearAllPoints()
	if right + WIDTH + 6 <= screenW then
		f:SetPoint("TOPLEFT", main, "TOPRIGHT", 6, 0)
		f:SetPoint("BOTTOMLEFT", main, "BOTTOMRIGHT", 6, 0)
	elseif left - WIDTH - 6 >= 0 then
		f:SetPoint("TOPRIGHT", main, "TOPLEFT", -6, 0)
		f:SetPoint("BOTTOMRIGHT", main, "BOTTOMLEFT", -6, 0)
	else
		f:SetPoint("TOPRIGHT", main, "TOPRIGHT", -8, -8)
		f:SetPoint("BOTTOMRIGHT", main, "BOTTOMRIGHT", -8, 8)
	end
end

local function SetSectionText(s, titleText, bodyText, width)
	s.title:SetFont(FONT, FS(13), nil)
	s.title:SetText(titleText)
	s.title:SetWidth(width)
	s.body:SetFont(FONT, FS(13), nil)
	s.body:SetText(bodyText)
	s.body:SetWidth(width)
end

function Info:Render()
	local item = self.current
	if not item then return end

	local width = self.content:GetWidth()
	if width < 50 then width = WIDTH - 46 end

	self.title:SetFont(FONT, FS(15), nil)
	self.title:SetText(item.name)

	local r, g, b = Core:StandingColor(item.standing)
	self.standing:SetFont(FONT, FS(12), nil)
	self.standing:SetText(Core:StandingLabel(item.standing))
	self.standing:SetTextColor(r, g, b)

	self.bar:SetStatusBarColor(r, g, b, 0.9)
	self.bar:SetValue(item.exalted and 1 or item.pct)

	self.barText:SetFont(FONT, FS(12), nil)
	if item.exalted then
		self.barText:SetText(ns.Sep(item.max) .. " / " .. ns.Sep(item.max) .. "  -  " .. L.MAXED)
	else
		self.barText:SetText(ns.Sep(item.cur) .. " / " .. ns.Sep(item.max)
			.. "  -  " .. math.floor(item.pct * 100 + 0.5) .. "%"
			.. "  -  " .. L.LEFT .. " " .. ns.Sep(item.remain))
	end

	local guide, fromGroup = ns.GetGuide(item.name, item.group)
	local data = {
		desc    = (item.desc and item.desc ~= "") and item.desc or nil,
		where   = guide and guide.where or nil,
		dailies = guide and guide.dailies or nil,
		turnin  = guide and guide.turnin or nil,
		rewards = guide and guide.rewards or nil,
		tip     = guide and guide.tip or nil,
	}

	local y = -4
	for i = 1, #SECTIONS do
		local key = SECTIONS[i]
		local s = self.sections[key]
		local body = data[key]
		if body then
			SetSectionText(s, TITLES[key], body, width)
			s.title:ClearAllPoints()
			s.title:SetPoint("TOPLEFT", 0, y)
			y = y - s.title:GetStringHeight() - 4
			s.body:ClearAllPoints()
			s.body:SetPoint("TOPLEFT", 0, y)
			y = y - s.body:GetStringHeight() - 14
			s.title:Show(); s.body:Show()
		else
			s.title:Hide(); s.body:Hide()
		end
	end

	self.note:SetFont(FONT, FS(12), nil)
	self.note:SetWidth(width)
	if guide and fromGroup then
		self.note:ClearAllPoints()
		self.note:SetPoint("TOPLEFT", 0, y)
		self.note:SetText(L.INFO_FROM_GROUP .. " " .. (item.group or ""))
		self.note:Show()
		y = y - self.note:GetStringHeight() - 10
	else
		self.note:Hide()
	end

	self.empty:SetFont(FONT, FS(13), nil)
	self.empty:SetWidth(width)
	if not guide then
		self.empty:ClearAllPoints()
		self.empty:SetPoint("TOPLEFT", 0, y)
		self.empty:SetText(L.INFO_NODATA .. "\n\n" .. L.INFO_EXACT_NAME .. " \"" .. item.name .. "\"")
		self.empty:Show()
		y = y - self.empty:GetStringHeight() - 10
		any = true
	else
		self.empty:Hide()
	end

	self.content:SetHeight(math.max(10, -y))

	local w = math.floor((self.btnRow:GetWidth() - 12) / 3)
	if w < 40 then w = 40 end
	self.btnWatch:SetWidth(w)
	self.btnFav:SetWidth(w)
	self.btnWar:SetWidth(w)

	self.btnWatch.label:SetFont(FONT, FS(12), nil)
	self.btnWatch.label:SetText(item.watched and L.BTN_UNWATCH or L.BTN_WATCH)

	self.btnFav.label:SetFont(FONT, FS(12), nil)
	self.btnFav.label:SetText(Core:IsFavorite(item) and L.BTN_UNFAV or L.BTN_FAV)

	self.btnEdit.label:SetFont(FONT, FS(12), nil)
	self.btnEdit.label:SetText(guide and L.BTN_EDIT or L.BTN_EDIT_NEW)

	self.btnWar.label:SetFont(FONT, FS(12), nil)
	self.btnWar.label:SetText(item.atWar and L.BTN_PEACE or L.BTN_WAR)
	if item.canWar then
		self.btnWar:Enable()
		self.btnWar.label:SetTextColor(0.80, 0.82, 0.88)
	else
		self.btnWar:Disable()
		self.btnWar.label:SetTextColor(0.40, 0.40, 0.44)
	end
end

function Info:Show(item)
	if not ns.UI.frame then return end
	self:Init()
	self.current = item
	if SirusRepCharDB then SirusRepCharDB.selectedFaction = item.name; SirusRepCharDB.selectedFactionID = (type(item.factionID) == "number" and item.factionID > 0) and item.factionID or nil end
	self:Reanchor()
	self.frame:Show()
	self:Render()
	if ns.db then ns.db.infoShown = true end
	if ns.UI and ns.UI.Refresh then ns.UI:Refresh() end
end

function Info:Hide(preserveState, skipRefresh)
	if self.frame then self.frame:Hide() end
	if not preserveState then
		self.current = nil
		if ns.db then ns.db.infoShown = false end
		if ns.UI and ns.UI.ClearSelectedFaction then ns.UI:ClearSelectedFaction() end
	end
	if not skipRefresh and ns.UI and ns.UI.Refresh then ns.UI:Refresh() end
end

function Info:RefreshCurrent()
	if not self.frame or not self.frame:IsShown() or not self.current then return end
	local fresh = Core:FindEntry(self.current.factionID, self.current.name)
	if fresh then self.current = fresh end
	self:Render()
end

local EDIT_FIELDS = { "where", "dailies", "turnin", "rewards", "tip" }

function Info:OpenEditor(item)
	local ed = self.editor
	if not ed then
		ed = CreateFrame("Frame", "SirusRepEditFrame", UIParent)
		self.editor = ed
		ed:SetSize(620, 610)
		ed:SetPoint("CENTER")
		ed:SetFrameStrata("DIALOG")
		ed:EnableMouse(true)
		ed:SetMovable(true)
		Skin(ed, 0.055, 0.058, 0.07, 0.98)
		tinsert(UISpecialFrames, "SirusRepEditFrame")

		local head = CreateFrame("Frame", nil, ed)
		head:SetPoint("TOPLEFT", 1, -1)
		head:SetPoint("TOPRIGHT", -1, -1)
		head:SetHeight(34)
		Skin(head, 0.09, 0.11, 0.15, 1, 0.09, 0.11, 0.15)
		head:EnableMouse(true)
		head:SetScript("OnMouseDown", function() ed:StartMoving() end)
		head:SetScript("OnMouseUp", function() ed:StopMovingOrSizing() end)

		ed.title = Text(head, 14, 1, 0.85, 0.40)
		ed.title:SetPoint("LEFT", 12, 0)
		ed.title:SetPoint("RIGHT", -30, 0)
		ed.title:SetJustifyV("MIDDLE")

		local close = CreateFrame("Button", nil, head, "UIPanelCloseButton")
		close:SetPoint("RIGHT", -2, 0)
		close:SetScript("OnClick", function() ed:Hide() end)

		ed.fields = {}
		local prev
		for i = 1, #EDIT_FIELDS do
			local key = EDIT_FIELDS[i]
			local label = Text(ed, 12, 0.36, 0.65, 0.92)
			if prev then
				label:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -10)
			else
				label:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 12, -12)
			end
			label:SetPoint("RIGHT", ed, "RIGHT", -12, 0)

			local box = CreateFrame("Frame", nil, ed)
			box:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -3)
			box:SetPoint("RIGHT", ed, "RIGHT", -12, 0)
			box:SetHeight(70)
			Skin(box, 0.03, 0.03, 0.045, 1)

			local e = CreateFrame("EditBox", nil, box)
			e:SetPoint("TOPLEFT", 8, -6)
			e:SetPoint("BOTTOMRIGHT", -8, 6)
			e:SetMultiLine(true)
			e:SetAutoFocus(false)
			e:SetJustifyH("LEFT")
			e:SetJustifyV("TOP")
			e:SetTextColor(0.95, 0.95, 0.95)
			e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

			ed.fields[key] = { label = label, box = box, edit = e }
			prev = box
		end

		ed.hint = Text(ed, 11, 0.55, 0.57, 0.63)
		ed.hint:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -12)
		ed.hint:SetPoint("RIGHT", ed, "RIGHT", -12, 0)

		local save = MakeButton(ed, 150, function() Info:SaveEditor() end)
		save:SetPoint("BOTTOMRIGHT", -12, 12)
		ed.save = save

		local del = MakeButton(ed, 150, function() Info:DeleteEditor() end)
		del:SetPoint("BOTTOMLEFT", 12, 12)
		ed.del = del
	end

	ed.editing = item.name
	ed.title:SetFont(FONT, FS(14), nil)
	ed.title:SetText(L.EDIT_TITLE .. ": " .. item.name)
	ed.hint:SetFont(FONT, FS(11), nil)
	ed.hint:SetText(L.EDIT_HINT)
	ed.save.label:SetFont(FONT, FS(12), nil)
	ed.save.label:SetText(L.EDIT_SAVE)
	ed.del.label:SetFont(FONT, FS(12), nil)
	ed.del.label:SetText(L.EDIT_DELETE)

	local titles = {
		where = L.INFO_WHERE, dailies = L.INFO_DAILIES,
		turnin = L.INFO_TURNIN, rewards = L.INFO_REWARDS, tip = L.INFO_TIP,
	}
	local guide = ns.GetGuide(item.name)
	for i = 1, #EDIT_FIELDS do
		local key = EDIT_FIELDS[i]
		local f = ed.fields[key]
		f.label:SetFont(FONT, FS(12), nil)
		f.label:SetText(titles[key])
		f.edit:SetFont(FONT, FS(12), nil)
		f.edit:SetText(guide and guide[key] or "")
		f.edit:SetCursorPosition(0)
	end

	ed:Show()
	ed.fields.where.edit:SetFocus()
end

function Info:SaveEditor()
	local ed = self.editor
	if not ed or not ed.editing then return end

	local rec, any = { name = ed.editing }, false
	for i = 1, #EDIT_FIELDS do
		local key = EDIT_FIELDS[i]
		local v = ed.fields[key].edit:GetText() or ""
		v = string.gsub(v, "^%s*(.-)%s*$", "%1")
		if v ~= "" then rec[key] = v; any = true end
	end

	local db = ns.db
	db.customGuides = db.customGuides or {}
	local k = ns.Lower(ed.editing)
	db.customGuides[k] = any and rec or nil

	ed:Hide()
	if ns.UI then ns.UI:OnDataChanged() end
	DEFAULT_CHAT_FRAME:AddMessage("|cff1784d1SirusRep|r: "
		.. (any and L.EDIT_SAVED or L.EDIT_REMOVED) .. " " .. ed.editing)
end

function Info:DeleteEditor()
	local ed = self.editor
	if not ed or not ed.editing then return end
	local db = ns.db
	if db.customGuides then db.customGuides[ns.Lower(ed.editing)] = nil end
	ed:Hide()
	if ns.UI then ns.UI:OnDataChanged() end
	DEFAULT_CHAT_FRAME:AddMessage("|cff1784d1SirusRep|r: "
		.. L.EDIT_REMOVED .. " " .. ed.editing)
end
