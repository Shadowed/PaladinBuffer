if( not PaladinBuffer ) then return end

local Assign = PaladinBuffer:NewModule("AssignGUI", "AceEvent-3.0")
local L = PaladinBufferLocals

local playerName = UnitName("player")
local groupList, displayList, classTotals
local MAX_GROUP_ROWS = 14
local ROW_HEIGHT = 17

function Assign:CreateTables()
	classes = {"WARRIOR","ROGUE","PRIEST","DRUID","PALADIN","HUNTER","MAGE","WARLOCK","SHAMAN", "DEATHKNIGHT"}
	blacklisted = {["WARRIOR"] = "gwisdom", ["ROGUE"] = "gwisdom", ["PRIEST"] = "gmight", ["MAGE"] = "gmight", ["DEATHKNIGHT"] = "gwisdom"}
	singleBlacklist = {["WARRIOR"] = "wisdom", ["ROGUE"] = "wisdom", ["PRIEST"] = "might", ["MAGE"] = "might", ["DEATHKNIGHT"] = "wisdom"}
	blessingOrder = {["gmight"] = 1, ["gwisdom"] = 2, ["gkings"] = 3, ["gsanct"] = 4}
	blessings = {"gmight", "gwisdom", "gkings", "gsanct"}
	singleBlessings = {"might", "wisdom", "kings", "sanct"}
	blessingIcons = {["gmight"] = select(3, GetSpellInfo(48934)), ["gwisdom"] = select(3, GetSpellInfo(48938)), ["gsanct"] = select(3, GetSpellInfo(25899)),["gkings"] = select(3, GetSpellInfo(25898)), ["might"] = select(3, GetSpellInfo(56520)), ["wisdom"] = select(3, GetSpellInfo(56521)), ["sanct"] = select(3, GetSpellInfo(20911)), ["kings"] = select(3, GetSpellInfo(20217))}
end

-- Message fired so we should update the visible blessings
function Assign:UpdateAssignments(event, caster, target)
	for id, row in pairs(self.rows) do
		if( row:IsVisible() and ( not caster or row.playerName == caster ) ) then
			self:UpdateAssignmentButtons(id)
		end
	end
	
	self:UpdateClassAssignments()

	-- Update single blessings frame if needed
	if( Assign.singleFrame and Assign.singleFrame:IsVisible() ) then
		self:UpdateSingle()
	end
end

-- Update the text below the class icon that shows what blessings are currently assigned to them
function Assign:UpdateClassAssignments()
	for _, column in pairs(self.columns) do
		local text
		for _, assignments in pairs(PaladinBuffer.db.profile.assignments) do
			if( assignments[column.classToken] ~= "none" ) then
				if( text ) then
					text = text .. "," .. L[assignments[column.classToken]]
				else
					text = L[assignments[column.classToken]]
				end
			end
		end
		
		column.text:SetText(text or L["None"])
		column.text:ClearAllPoints()
		column.text:SetPoint("CENTER", column.icon, "CENTER", 0, -24)
	end
end

-- Sort the blessings on the left thingy showing what player has what
local function sortBlessings(a, b)
	return blessingOrder[a.spellToken] < blessingOrder[b.spellToken]
end

local function assignBlessing(self)
	-- Check if we should toggle the assignment off
	local spellToken = self.spellToken
	if( PaladinBuffer.db.profile.assignments[self.playerName] and PaladinBuffer.db.profile.assignments[self.playerName][self.classToken] == self.spellToken ) then
		spellToken = "none"
	end
			
	if( IsShiftKeyDown() ) then
		for _, classToken in pairs(classes) do
			if( blacklisted[classToken] ~= spellToken ) then
				PaladinBuffer:AssignBlessing(self.playerName, spellToken, classToken)
			end
		end
	else
		PaladinBuffer:AssignBlessing(self.playerName, spellToken, self.classToken)
	end
end

-- Assignment buttons for each class
function Assign:CreateAssignmentButtons(rowID)
	-- Now create there rows in the class columns for assignments
	local ICON_SIZE = 18
	for columnID, column in pairs(self.columns) do
		if( not self.assignColumns[columnID] ) then
			self.assignColumns[columnID] = {}
		end

		local assignColumn = CreateFrame("Frame", nil, column)
		assignColumn:SetHeight(ICON_SIZE * 2)
		assignColumn:SetWidth(ICON_SIZE * 2)
		assignColumn.icons = {}

		self.assignColumns[columnID][rowID] = assignColumn

		if( rowID > 1 ) then
			assignColumn:SetPoint("BOTTOMLEFT", self.assignColumns[columnID][rowID - 1], "BOTTOMLEFT", 0, -60)
		else
			assignColumn:SetPoint("BOTTOMLEFT", column, "BOTTOMLEFT", -4, -65)
		end

		-- Now create the icons in the counter frame
		for iconID, spellToken in pairs(blessings) do
			local icon = CreateFrame("Button", nil, assignColumn)
			icon:SetHeight(ICON_SIZE)
			icon:SetWidth(ICON_SIZE)
			icon:SetNormalTexture(blessingIcons[spellToken])
			icon:SetScript("OnClick", assignBlessing)
			icon:RegisterForClicks("AnyUp")
			icon.spellToken = spellToken
			icon.classToken = column.classToken

			assignColumn.icons[iconID] = icon
		end
	end
end

-- Sort blessing icons so they are consistent but don't have weird spacing if something is disabled
local function sortBlessingIcons(a, b)
	if( a.disabled and b.disabled ) then
		return a.spellToken > b.spellToken
	elseif( a.disabled ) then
		return false
	elseif( b.disabled ) then
		return true
	end
	
	return a.spellToken < b.spellToken
end

function Assign:UpdateAssignmentButtons(rowID)
	local row = self.rows[rowID]
	local blessingData = PaladinBuffer.db.profile.blessings[row.playerName]
	local assignData = PaladinBuffer.db.profile.assignments[row.playerName]
	
	for _, columns in pairs(self.assignColumns) do
		if( columns[rowID] and assignData ) then
			columns[rowID]:Show()
			
			for _, icon in pairs(columns[rowID].icons) do
				if( ( row.playerName == playerName or PaladinBuffer.freeAssign[row.playerName] or PaladinBuffer:HasPermission(playerName) ) and blessingData[icon.spellToken] and blacklisted[icon.classToken] ~= icon.spellToken ) then
					SetDesaturation(icon:GetNormalTexture(), nil)

					icon:EnableMouse(true)
					icon:SetAlpha(assignData[icon.classToken] ~= icon.spellToken and 0.40 or 1.0)
					icon.playerName = row.playerName
					icon.disabled = nil
					icon:Show()
				else
					SetDesaturation(icon:GetNormalTexture(), true)

					icon:EnableMouse(false)
					icon:SetAlpha(0.80)
					icon.disabled = true
					icon:Show()
				end
			end

			-- Sort so that disabled are last
			table.sort(columns[rowID].icons, sortBlessingIcons)

			-- And reposition
			for iconID, icon in pairs(columns[rowID].icons) do
				if( iconID == 3 ) then
					icon:SetPoint("TOPLEFT", columns[rowID].icons[1], "BOTTOMLEFT", 0, -2)
				elseif( iconID > 1 ) then
					icon:SetPoint("TOPLEFT", columns[rowID].icons[iconID - 1], "TOPRIGHT", 2, 0)
				else
					icon:SetPoint("TOPLEFT", columns[rowID], "TOPLEFT")
				end
			end

		-- No more assignments for this person, so hide everything associated
		elseif( columns[rowID] ) then
			columns[rowID]:Hide()
		end
	end
end

-- Create an icon listing of what blessings they have + talents
function Assign:UpdateBlessingInfo(rowID)
	local row = self.rows[rowID]
		
	local bID = 0
	for spellToken, rank in pairs(PaladinBuffer.db.profile.blessings[row.playerName]) do
		if( PaladinBuffer.blessingTypes[spellToken] == "greater" ) then
			bID = bID + 1

			-- Grab the rank of blessing + how improved it is
			local rank, improved = string.split(".", rank)
			improved = tonumber(improved) or 0
			rank = tonumber(rank)

			-- Improved text
			local button = row.blessings[bID]
			if( not button ) then
				button = CreateFrame("Button", nil, row)
				button:SetHeight(16)
				button:SetWidth(16)

				button.text = button:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
				button.text:SetPoint("TOPLEFT", button, "TOPRIGHT", 2, -2)
	
				row.blessings[bID] = button
			end

			-- Only show how improved it is, if it's actually improved
			if( improved > 0 ) then
				button.text:SetFormattedText("%d (%d)", rank, improved)
			else
				button.text:SetFormattedText("%d", rank)
			end

			button.spellToken = spellToken
			button:SetNormalTexture(blessingIcons[spellToken])
			button:ClearAllPoints()
			button:Show()
		end
	end

	-- Sort it out
	table.sort(row.blessings, sortBlessings)

	-- Now position blessings
	if( row.blessings[2] ) then
		row.blessings[2]:SetPoint("TOPLEFT", row, "BOTTOMLEFT", 60, -6)
		row.blessings[2]:Show()
	end
	
	if( row.blessings[1] ) then
		row.blessings[1]:SetPoint("TOPLEFT", row, "BOTTOMLEFT", 0, -6)
		row.blessings[1]:Show()
	end

	if( row.blessings[4] ) then
		row.blessings[4]:SetPoint("TOPLEFT", row.blessings[2], "BOTTOMLEFT", 0, -2)
		row.blessings[4]:Show()
	end
	
	if( row.blessings[3] ) then
		row.blessings[3]:SetPoint("TOPLEFT", row.blessings[1], "BOTTOMLEFT", 0, -2)
		row.blessings[3]:Show()
	end
end

-- Update player rows
local function sortPlayers(a, b)
	return a.playerName < b.playerName
end

function Assign:UpdatePlayerRows()
	-- Create each users row
	local rowID = 0
	for name, data in pairs(PaladinBuffer.db.profile.blessings) do
		rowID = rowID + 1

		-- Create the Paladins name
		local row = self.rows[rowID]
		if( not row ) then
			row = CreateFrame("Frame", nil, self.frame)
			row:SetHeight(10)
			row:SetWidth(50)
			row.blessings = {}
			row.playerName = ""

			row.text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
			row.text:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)

			row.grid = CreateFrame("Frame", nil, row)
			row.grid:SetBackdrop(self.gridBackdrop)
			row.grid:SetBackdropColor(0.0, 0.0, 0.0, 0.0)
			row.grid:SetBackdropBorderColor(0.75, 0.75, 0.75, 1.0)
			row.grid:SetHeight(61)
			row.grid:SetWidth(self.frame:GetWidth())

			self.rows[rowID] = row
			
			self:CreateAssignmentButtons(rowID)
		end
		
		if( name ~= playerName and not PaladinBuffer.freeAssign[name] and not PaladinBuffer:HasPermission(playerName) ) then
			row.text:SetFormattedText("%s%s|r", RED_FONT_COLOR_CODE, name)
		else
			row.text:SetText(name)
		end

		row.playerName = name
		row:Show()
	end
	
	table.sort(self.rows, sortPlayers)
	
	-- Now position/update
	for id, row in pairs(self.rows) do
		for _, blessing in pairs(row.blessings) do
			blessing:Hide()
		end

		if( id <= rowID ) then
			if( id > 1 ) then
				row.grid:SetPoint("TOPLEFT", self.rows[id - 1].grid, "BOTTOMLEFT", 0, 1)
				row:SetPoint("TOPLEFT", self.rows[id - 1], "BOTTOMLEFT", 0, -50)
			else
				row.grid:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, -60)
				row:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 4, -63)
			end
			
			self:UpdateBlessingInfo(id)
			self:UpdateAssignmentButtons(id)
		else
			for _, columns in pairs(self.assignColumns) do
				columns[id]:Hide()
			end
			
			row:Hide()
		end
	end
	
	-- Update frame height
	self.frame:SetHeight(60 + (rowID * 60))
	
	-- Now update the column grids height
	for _, column in pairs(self.columns) do
		column.grid:SetHeight(self.frame:GetHeight())
	end
end

-- Load various info into the table
function Assign:LoadUnit(unit)
	if( not UnitExists(unit) or ( unit ~= "player" and UnitIsUnit(unit, "player") ) ) then
		return
	end
	
	local row
	-- Find a table we can use if none exists
	for _, groupRow in pairs(groupList) do
		if( not groupRow.enabled ) then
			row = groupRow
			break
		end
	end
	
	if( not row ) then
		table.insert(groupList, {})
		row = groupList[#(groupList)]
	end
	
	row.class = select(2, UnitClass(unit))
	if( UnitCreatureFamily(unit) ) then
		row.class = UnitCreatureFamily(unit)
	elseif( not PaladinBuffer.classList[row.class] ) then
		row.class = nil
		return
	end
	
	row.text = UnitName(unit)
	row.id = row.class == "PET" and string.format("PET.%s", row.text) or row.text
	row.enabled = true
	
	classTotals[row.class] = (classTotals[row.class] or 0) + 1
end

function Assign:LoadClass(classToken)
	local row
	-- Recycle a table if we can
	for _, groupRow in pairs(groupList) do
		if( not groupRow.enabled ) then
			row = groupRow
			break
		end
	end
	
	if( not row ) then
		table.insert(groupList, {})
		row = groupList[#(groupList)]
	end
	
	row.text = string.format(L["CLASSES"][classToken], classTotals[classToken])
	row.class = "HEADER"
	row.id = nil
	row.enabled = true
	
	table.insert(displayList, #(groupList))
	
	for id, row in pairs(groupList) do
		if( row.class == classToken and row.enabled ) then
			table.insert(displayList, id)
		end
	end
end

local function sortGroup(a, b)
	return a.text > b.text
end

function Assign:UpdateGroupList()
	for _, row in pairs(groupList) do row.enabled = nil row.class = nil row.text = "" end
	for i=#(displayList), 1, -1 do table.remove(displayList, i) end
	for k in pairs(classTotals) do classTotals[k] = nil end
	
	-- Load player
	self:LoadUnit("player")
	
	-- Load raid
	for i=1, GetNumRaidMembers() do
		self:LoadUnit(PaladinBuffer.raidUnits[i])

		if( not UnitControllingVehicle(PaladinBuffer.raidUnits[i]) ) then
			self:LoadUnit(PaladinBuffer.raidUnits[i] .. "pet")
		end
	end
	
	-- Load party if not in a raid
	if( GetNumRaidMembers() == 0 ) then
		for i=1, GetNumPartyMembers() do
			self:LoadUnit(PaladinBuffer.partyUnits[i])
	
			if( not UnitControllingVehicle(PaladinBuffer.partyUnits[i]) ) then
				self:LoadUnit(PaladinBuffer.partyUnits[i] .. "pet")
			end
		end
	end
	
	table.sort(groupList, sortGroup)
	
	-- Now create the class headers
	for _, classToken in pairs(classes) do
		local total = classTotals[classToken]
		if( total ) then
			self:LoadClass(classToken)
		end
	end
	
	if( classTotals["PET"] ) then
		self:LoadClass("PET")
	end
end

-- Update listing
function Assign:UpdateSingle()
	local self = Assign
	
	for _, row in pairs(self.singleFrame.rows) do
		for _, blessing in pairs(row.blessings) do blessing:Hide() end
		row:Hide()
	end

	FauxScrollFrame_Update(self.singleFrame.scroll, #(displayList), MAX_GROUP_ROWS - 1, ROW_HEIGHT)
	
	local offset = FauxScrollFrame_GetOffset(self.singleFrame.scroll)
	local displayed = 0
	
	for index, dataID in pairs(displayList) do
		if( index >= offset and displayed < MAX_GROUP_ROWS ) then
			displayed = displayed + 1
			local row = self.singleFrame.rows[displayed]
			local groupData = groupList[dataID]
			
			if( groupData.class ~= "HEADER" ) then
				for _, blessing in pairs(row.blessings) do
					if( singleBlacklist[groupData.class] ~= blessing.spellToken and not PaladinBuffer.modules.Assign:IsGreaterAssigned(groupData.class, blessing.spellToken) and PaladinBuffer.modules.Assign:IsBlessingAvailable(groupData.id, blessing.spellToken) ) then
						SetDesaturation(blessing:GetNormalTexture(), nil)
						
						blessing:EnableMouse(true)
						blessing:SetAlpha(0.40)
						blessing.playerName = groupData.id
						
						for _, data in pairs(PaladinBuffer.db.profile.assignments) do
							if( data[groupData.id] == blessing.spellToken ) then
								blessing:SetAlpha(1.0)
								break
							end
						end
					else
						SetDesaturation(blessing:GetNormalTexture(), true)
						
						blessing:EnableMouse(false)
						blessing:SetAlpha(0.10)
					end
					
					blessing:Show()
				end
				
				if( RAID_CLASS_COLORS[groupData.class] ) then
					row.text:SetFormattedText("|cff%02x%02x%02x%s|r", 255 * RAID_CLASS_COLORS[groupData.class].r, 255 * RAID_CLASS_COLORS[groupData.class].g, 255 * RAID_CLASS_COLORS[groupData.class].b, groupData.text)
				else
					row.text:SetText(groupData.text)
				end
			else
				row.text:SetText(groupData.text)
			end
			
			row:Show()
		end
	end
end

-- Assign a single blessing to the player
local function assignSingleBlessing(self)
	-- Find who is the best for this
	local caster = PaladinBuffer.modules.Assign:FindSingleBlesser(self.spellToken)
	-- This should *never* happen, if the blessing is unavailable the button should be grayed out
	if( not caster ) then
		return
	end
	
	if( PaladinBuffer.db.profile.assignments[caster][self.playerName] == self.spellToken ) then
		PaladinBuffer:AssignBlessing(caster, nil, self.playerName)
		return
	end
	
	PaladinBuffer:AssignBlessing(caster, self.spellToken, self.playerName)
end

-- Create the single assignment UI
function Assign:CreateSingleFrame()
	if( self.singleFrame ) then
		return
	end
	
	groupList = {}
	displayList = {}
	classTotals = {}
	
	-- Create the container frame
	self.singleFrame = CreateFrame("Frame", nil, self.frame)
	self.singleFrame:SetFrameStrata("HIGH")
	self.singleFrame:SetHeight(300)
	self.singleFrame:SetWidth(245)
	self.singleFrame:SetBackdrop(self.backdrop)
	self.singleFrame:SetBackdropColor(0.0, 0.0, 0.0, 1.0)
	self.singleFrame:SetBackdropBorderColor(0.90, 0.90, 0.90, 0.95)
	self.singleFrame:SetPoint("TOPLEFT", self.frame.push, "TOPRIGHT", 3, 10)
	self.singleFrame:SetScript("OnShow", function()
		Assign:RegisterMessage("PB_ROSTER_UPDATED", "UpdateGroupList")
		Assign:UpdateGroupList()
		Assign:UpdateSingle()
	end)
	self.singleFrame:SetScript("OnHide", function()
		Assign:UnregisterMessage("PB_ROSTER_UPDATED")
	end)
	self.singleFrame:Hide()

	self.singleFrame.scroll = CreateFrame("ScrollFrame", "PaladinBufferSingleFrame", self.singleFrame, "FauxScrollFrameTemplate")
	self.singleFrame.scroll:SetPoint("TOPLEFT", self.singleFrame, "TOPLEFT", 0, -4)
	self.singleFrame.scroll:SetPoint("BOTTOMRIGHT", self.singleFrame, "BOTTOMRIGHT", -26, 3)
	self.singleFrame.scroll:SetScript("OnVerticalScroll", function(self, value) FauxScrollFrame_OnVerticalScroll(self, value, ROW_HEIGHT, Assign.UpdateSingle) end)

	self.singleFrame.rows = {}
	
	for i=1, MAX_GROUP_ROWS do
		local row = CreateFrame("Frame", nil, self.singleFrame)
		row:SetWidth(140)
		row:SetHeight(ROW_HEIGHT)
		row.blessings = {}
		
		row.text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
		row.text:SetPoint("TOPLEFT", row, "TOPLEFT")
		
		if( i > 1 ) then
			row:SetPoint("TOPLEFT", self.singleFrame.rows[i - 1], "BOTTOMLEFT", 0, -4)
		else
			row:SetPoint("TOPLEFT", self.singleFrame, "TOPLEFT", 4, -8)
		end
		
		for bID, spellToken in pairs(singleBlessings) do
			local button = CreateFrame("Button", nil, row)
			button:SetNormalTexture(blessingIcons[spellToken])
			button:SetHeight(16)
			button:SetWidth(16)
			button:SetScript("OnClick", assignSingleBlessing)
			button.spellToken = spellToken
			
			if( bID > 1 ) then
				button:SetPoint("TOPLEFT", row.blessings[bID - 1], "TOPRIGHT", 2, 0)
			else
				button:SetPoint("TOPLEFT", row, "TOPRIGHT", 0, 1)
			end
		
			row.blessings[bID] = button
		end

		self.singleFrame.rows[i] = row
	end
end

-- Frame shown, so we want to be updating the UI
local function assignmentUpdate(...)
	Assign:UpdatePlayerRows()
	Assign:UpdateAssignments(...)

	if( Assign.singleFrame and Assign.singleFrame:IsVisible() ) then
		Assign:UpdateSingle()
	end
end

local function updatePermissions()
	Assign:UpdatePlayerRows()
	Assign:UpdateClassAssignments()
end

local function OnShow(self)
	Assign:UpdatePlayerRows()
	Assign:UpdateAssignments()
	
	-- New player found, will need to update rows
	Assign:RegisterMessage("PB_DISCOVERED_PLAYER", assignmentUpdate)

	-- All assignments reset, so we can hide most of the UI
	Assign:RegisterMessage("PB_RESET_ASSIGNMENTS", assignmentUpdate)

	-- What blessings they were assigned changed
	Assign:RegisterMessage("PB_CLEARED_ASSIGNMENTS", "UpdateAssignments")
	Assign:RegisterMessage("PB_ASSIGNED_BLESSINGS", "UpdateAssignments")
	
	-- Roster/permissions changed, need to update permissions
	Assign:RegisterMessage("PB_PERMISSIONS_UPDATED", updatePermissions)
	Assign:RegisterMessage("PB_ROSTER_UPDATED", updatePermissions)
	
	-- What blessings they can cast changed
	Assign:RegisterMessage("PB_RESET_SPELLS", "UpdateAssignments")
	Assign:RegisterMessage("PB_SPELL_DATA", "UpdateAssignments")
	
	-- Position
	if( PaladinBuffer.db.profile.position ) then
		local scale = self:GetEffectiveScale()

		self:ClearAllPoints()
		self:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", PaladinBuffer.db.profile.position.x / scale, PaladinBuffer.db.profile.position.y / scale)
	else
		self:SetPoint("CENTER", UIParent, "CENTER")
	end
end

-- No longer need events for this
local function OnHide(self)
	Assign:UnregisterAllMessages()
	
	if( Assign.singleFrame ) then
		Assign.singleFrame:Hide()
	end
end

-- Quick assign!
local function quickAssignBlessings()
	PaladinBuffer.modules.Assign:SetHighestBlessers()
	PaladinBuffer.modules.Assign:CalculateBlessings()
	PaladinBuffer.modules.Sync:SendAssignments()
end

-- Reset everything
local function clearAllBlessings()
	PaladinBuffer:ClearAllAssignments()
	PaladinBuffer.modules.Sync:SendAssignmentReset()
end

-- Refresh blessing data
local timeElapsed = 0
local function throttleUpdate(self, elapsed)
	timeElapsed = timeElapsed - elapsed
	if( timeElapsed <= 0 ) then
		self:Enable()
		self:SetScript("OnUpdate", nil)
	end
end

local function refreshBlessingData(self)
	timeElapsed = 5
	self:Disable()
	self:SetScript("OnUpdate", throttleUpdate)
	
	PaladinBuffer.modules.Sync:RequestData()
end

-- Push blessings to the group
local function pushBlessings()
	PaladinBuffer.modules.Sync:SendAssignments()
end

-- Show the single blessing UI
local function singleAssignBlessings()
	Assign:CreateSingleFrame()
	
	if( Assign.singleFrame:IsVisible() ) then
		Assign.singleFrame:Hide()
	else
		Assign.singleFrame:Show()
	end
end

function Assign:CreateFrame()
	if( self.frame ) then
		return
	end
	
	-- Ceaste our tables for holding things!
	self:CreateTables()
	
	self.backdrop = {bgFile = "Interface\\CharacterFrame\\UI-Party-Background",
			edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
			tile = false,
			edgeSize = 1,
			tileSize = 5,
			insets = {left = 1, right = 1, top = 1, bottom = 1}
	}

	self.gridBackdrop = {bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
		tile = false,
		edgeSize = 1.1,
		tileSize = 5,
		insets = {left = 0, right = 0, top = 1, bottom = 1}
	}

	-- Create it all!
	self.frame = CreateFrame("Frame", "PaladinBufferFrame", UIParent)
	self.frame:SetFrameStrata("MEDIUM")
	self.frame:SetHeight(65)
	self.frame:SetWidth(731)
	self.frame:SetBackdrop(self.backdrop)
	self.frame:SetBackdropColor(0.0, 0.0, 0.0, 1.0)
	self.frame:SetBackdropBorderColor(0.75, 0.75, 0.75, 0.90)
	self.frame:SetScript("OnShow", OnShow)
	self.frame:SetScript("OnHide", OnHide)
	self.frame:SetMovable(true)
	self.frame:SetScale(PaladinBuffer.db.profile.scale)
	self.frame:Hide()
	
	table.insert(UISpecialFrames, "PaladinBufferFrame")

	-- Title bar thing
	self.titleFrame = CreateFrame("Frame", nil, self.frame)
	self.titleFrame:SetHeight(22)
	self.titleFrame:SetPoint("TOPLEFT", self.frame, 0, self.titleFrame:GetHeight() + 5)
	self.titleFrame:SetPoint("TOPRIGHT", self.frame)
	self.titleFrame:SetBackdrop(self.backdrop)
	self.titleFrame:SetBackdropColor(0.0, 0.0, 0.0, 0.90)
	self.titleFrame:SetBackdropBorderColor(0.75, 0.75, 0.75, 1.0)

	-- Close button
	local button = CreateFrame("Button", nil, self.titleFrame, "UIPanelCloseButton")
	button:SetHeight(30)
	button:SetWidth(30)
	button:SetPoint("TOPRIGHT", 6, 5)
	button:SetScript("OnClick", function()
		HideUIPanel(Assign.frame)
	end)
	
	self.titleFrame.close = button

	-- Frame mover
	local mover = CreateFrame("Button", nil, self.titleFrame)
	mover:SetFrameStrata("LOW")
	mover:SetAllPoints(self.titleFrame)
	mover:SetHeight(10)
	mover:SetWidth(10)
	mover:SetMovable(true)
	mover:SetScript("OnMouseUp", function(self)
		if( self.isMoving ) then
			local parent = Assign.frame
			local scale = parent:GetEffectiveScale()

			self.isMoving = nil
			parent:StopMovingOrSizing()

			PaladinBuffer.db.profile.position = {x = parent:GetLeft() * scale, y = parent:GetTop() * scale}
		end
	end)
	mover:SetScript("OnMouseDown", function(self, mouse)
		if( IsAltKeyDown() and mouse == "LeftButton" ) then
			self.isMoving = true
			Assign.frame:StartMoving()
		elseif( mouse == "RightButton" ) then
			Assign.frame:ClearAllPoints()
			Assign.frame:SetPoint("CENTER", UIParent, "CENTER")
			
			PaladinBuffer.db.profile.position = nil
		end
	end)
	

	-- Management buttons
	local push = CreateFrame("Button", nil, self.frame, "UIPanelButtonGrayTemplate")
	push:SetNormalFontObject(GameFontHighlightSmall)
	push:SetHighlightFontObject(GameFontHighlightSmall)
	push:SetHeight(18)
	push:SetWidth(113)
	push:SetText(L["Push assignments"])
	push:SetScript("OnClick", pushBlessings)
	push:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 4, -10)
	
	self.frame.push = push

	local resetAll = CreateFrame("Button", nil, self.frame, "UIPanelButtonGrayTemplate")
	resetAll:SetNormalFontObject(GameFontHighlightSmall)
	resetAll:SetHighlightFontObject(GameFontHighlightSmall)
	resetAll:SetHeight(18)
	resetAll:SetWidth(55)
	resetAll:SetText(L["Clear"])
	resetAll:SetScript("OnClick", clearAllBlessings)
	resetAll:SetPoint("TOPLEFT", push, "BOTTOMLEFT", 0, -2)

	self.frame.resetAll = resetAll

	local refresh = CreateFrame("Button", nil, self.frame, "UIPanelButtonGrayTemplate")
	refresh:SetNormalFontObject(GameFontHighlightSmall)
	refresh:SetHighlightFontObject(GameFontHighlightSmall)
	refresh:SetDisabledFontObject(GameFontDisableSmall)
	refresh:SetHeight(18)
	refresh:SetWidth(55)
	refresh:SetText(L["Refresh"])
	refresh:SetScript("OnClick", refreshBlessingData)
	refresh:SetPoint("TOPLEFT", resetAll, "TOPRIGHT", 2, 0)

	self.frame.refresh = refresh

	local singleAssign = CreateFrame("Button", nil, self.titleFrame, "UIPanelButtonGrayTemplate")
	singleAssign:SetFrameStrata("MEDIUM")
	singleAssign:SetNormalFontObject(GameFontHighlightSmall)
	singleAssign:SetHighlightFontObject(GameFontHighlightSmall)
	singleAssign:SetHeight(18)
	singleAssign:SetWidth(120)
	singleAssign:SetText(L["Single assignments"])
	singleAssign:SetScript("OnClick", singleAssignBlessings)
	singleAssign:SetPoint("TOPLEFT", self.titleFrame, "TOPLEFT", 4, -2)
	
	self.titleFrame.singleAssign = singleAssign

	local quickAssign = CreateFrame("Button", nil, self.titleFrame, "UIPanelButtonGrayTemplate")
	quickAssign:SetFrameStrata("MEDIUM")
	quickAssign:SetNormalFontObject(GameFontHighlightSmall)
	quickAssign:SetHighlightFontObject(GameFontHighlightSmall)
	quickAssign:SetHeight(18)
	quickAssign:SetWidth(80)
	quickAssign:SetText(L["Quick assign"])
	quickAssign:SetScript("OnClick", quickAssignBlessings)
	quickAssign:SetPoint("TOPLEFT", singleAssign, "TOPRIGHT", 4, 0)
	
	self.titleFrame.quickAssign = quickAssign

	-- Build the class columns
	self.columns = {}
	for id, classToken in pairs(classes) do
		local column = CreateFrame("Frame", nil, self.frame)
		column:SetHeight(30)
		column:SetWidth(30)
		column.classToken = classToken
		
		-- Create the actual class button
		local coords = CLASS_BUTTONS[classToken]
		column.icon = column:CreateTexture(nil, "ARTWORK")
		column.icon:SetHeight(30)
		column.icon:SetWidth(30)
		column.icon:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes")
		column.icon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
		column.icon:SetPoint("CENTER", column, "CENTER")
		
		-- Text showing whats assigned to them so far
		column.text = column:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		column.text:SetPoint("CENTER", column.icon, "CENTER", 0, -24)
		
		-- Now create the borders for each of these
		column.grid = CreateFrame("Frame", nil, column)
		column.grid:SetBackdrop(self.gridBackdrop)
		column.grid:SetBackdropColor(0.0, 0.0, 0.0, 0.0)
		column.grid:SetBackdropBorderColor(0.75, 0.75, 0.75, 1.0)
		column.grid:SetHeight(self.frame:GetHeight())
		column.grid:SetWidth(62)
		
		if( id > 1 ) then
			column.grid:SetPoint("TOPLEFT", self.columns[id - 1].grid, "TOPRIGHT", -1, 0)
			column:SetPoint("TOPLEFT", self.columns[id - 1], "TOPRIGHT", 31, 0)   
		else
			column.grid:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 120, 0)
			column:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 135, -10)
		end

		self.columns[id] = column 
	end

	self.assignColumns = {}
	self.rows = {}
end

function Assign:Reload()
	if( self.frame ) then
		self.frame:SetScale(PaladinBuffer.db.profile.scale)
	end
end
