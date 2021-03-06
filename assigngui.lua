if( not PaladinBuffer ) then return end

local Assign = PaladinBuffer:NewModule("AssignGUI", "AceEvent-3.0")
local L = PaladinBufferLocals

local MAX_GROUP_ROWS = 14
local ROW_HEIGHT = 17

local groupList, displayList, classTotals, blacklist
local classes = {"WARRIOR","ROGUE","PRIEST","DRUID","PALADIN","HUNTER","MAGE","WARLOCK","SHAMAN", "DEATHKNIGHT"}
local singleBlacklist = {["WARRIOR"] = "wisdom", ["ROGUE"] = "wisdom", ["PRIEST"] = "might", ["MAGE"] = "might", ["DEATHKNIGHT"] = "wisdom"}
local blessingOrder = {["gmight"] = 1, ["gwisdom"] = 2, ["gkings"] = 3, ["gsanct"] = 4, ["none"] = 5}
local blessings = {"gmight", "gwisdom", "gkings", "gsanct"}
local singleBlessings = {"might", "wisdom", "kings", "sanct"}
local blessingIcons = {["gmight"] = select(3, GetSpellInfo(48934)), ["gwisdom"] = select(3, GetSpellInfo(48938)), ["gsanct"] = select(3, GetSpellInfo(25899)),["gkings"] = select(3, GetSpellInfo(25898)), ["might"] = select(3, GetSpellInfo(56520)), ["wisdom"] = select(3, GetSpellInfo(56521)), ["sanct"] = select(3, GetSpellInfo(20911)), ["kings"] = select(3, GetSpellInfo(20217))}

local playerName = UnitName("player")

function Assign:OnInitialize()
	blacklist = PaladinBuffer.blacklist
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
	--[[
	for _, column in pairs(self.columns) do
		local text = ""
		for _, assignments in pairs(PaladinBuffer.db.profile.assignments) do
			if( assignments[column.classToken] ) then
				text = text .. string.format("|T%s:20:20:0:0|t ", blessingIcons[assignments[column.classToken] ])
			end
		end
		
		column.text:SetText(text or L["None"])
		column.text:ClearAllPoints()
		column.text:SetPoint("CENTER", column.icon, "CENTER", 0, -24)
	end
	]]
end

-- Sort the blessings on the left thingy showing what player has what
local function sortBlessings(a, b)
	return blessingOrder[a.spellToken] < blessingOrder[b.spellToken]
end

local function assignBlessing(self)
	-- Check if we should toggle the assignment off
	local spellToken = self.spellToken
	if( PaladinBuffer.db.profile.assignments[self.playerName] and PaladinBuffer.db.profile.assignments[self.playerName][self.classToken] == self.spellToken ) then
		spellToken = nil
	end
			
	if( not IsShiftKeyDown() ) then
		PaladinBuffer:AssignBlessing(self.playerName, spellToken, self.classToken)
	else
		PaladinBuffer:MassAssignBlessing(self.playerName, spellToken)
	end

	-- Stop others changing the assignments from messing ours up
	if( PaladinBuffer.db.profile.autoLock ) then
		Assign:LockAssignments()
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
			assignColumn:SetPoint("BOTTOMLEFT", column, "BOTTOMLEFT", -4, -60)
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
		local assignColumn = columns[rowID]
		if( assignColumn and assignData ) then
			assignColumn:Show()
			
			for _, icon in pairs(assignColumn.icons) do
				if( blessingData[icon.spellToken] and blacklist[icon.classToken] ~= icon.spellToken ) then
					SetDesaturation(icon:GetNormalTexture(), nil)
					
					-- Show their assignments, but don't allow them to be changed
					if( row.playerName == playerName or PaladinBuffer.freeAssign[row.playerName] or PaladinBuffer:HasPermission(playerName) ) then
						icon:EnableMouse(true)
					else
						icon:EnableMouse(false)
					end
					
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
			table.sort(assignColumn.icons, sortBlessingIcons)

			-- And reposition
			for iconID, icon in pairs(assignColumn.icons) do
				if( iconID == 3 ) then
					icon:SetPoint("TOPLEFT", assignColumn.icons[1], "BOTTOMLEFT", 0, -2)
				elseif( iconID > 1 ) then
					icon:SetPoint("TOPLEFT", assignColumn.icons[iconID - 1], "TOPRIGHT", 2, 0)
				else
					icon:SetPoint("TOPLEFT", assignColumn, "TOPLEFT")
				end
			end

		-- No more assignments for this person, so hide everything associated
		elseif( assignColumn ) then
			assignColumn:Hide()
		end
	end
end

-- Create an icon listing of what blessings they have + talents
function Assign:UpdateBlessingInfo(rowID)
	local row = self.rows[rowID]
	
	-- Hide all blessings first
	for _, button in pairs(row.blessings) do
		button.spellToken = "none"
		button:ClearAllPoints()
		button:Hide()
	end
		
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
			button:Show()
		end
	end

	
	-- Sort it out
	table.sort(row.blessings, sortBlessings)

	-- Now position blessings
	if( row.blessings[1] and row.blessings[1]:IsVisible()) then
		row.blessings[1]:SetPoint("TOPLEFT", row, "BOTTOMLEFT", 0, -6)
		row.blessings[1]:Show()
	end

	if( row.blessings[2] and row.blessings[2]:IsVisible() ) then
		row.blessings[2]:SetPoint("TOPLEFT", row, "BOTTOMLEFT", 60, -6)
		row.blessings[2]:Show()
	end
	
	if( row.blessings[3] and row.blessings[3]:IsVisible()) then
		row.blessings[3]:SetPoint("TOPLEFT", row.blessings[1], "BOTTOMLEFT", 0, -2)
		row.blessings[3]:Show()
	end

	if( row.blessings[4] and row.blessings[4]:IsVisible()) then
		row.blessings[4]:SetPoint("TOPLEFT", row.blessings[2], "BOTTOMLEFT", 0, -2)
		row.blessings[4]:Show()
	end
end

-- Update player rows
local function sortPlayers(a, b)
	return a.playerName < b.playerName
end

function Assign:UpdatePlayerRows()
	-- Reset set name
	for _, row in pairs(self.rows) do row.playerName = "ZZZ" end
	
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
				row.grid:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, -48)
				row:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 4, -54)
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
	self.frame:SetHeight(49 + (rowID * 60))
	
	-- Now update the column grids height
	for _, column in pairs(self.columns) do
		column.grid:SetHeight(self.frame:GetHeight())
	end
end

-- Frame shown, so we want to be updating the UI
local function assignmentUpdate()
	Assign:UpdatePlayerRows()
	Assign:UpdateAssignments()

	if( Assign.singleFrame and Assign.singleFrame:IsVisible() ) then
		Assign:UpdateSingle()
	end
	
	if( Assign.choiceFrame and Assign.choiceFrame:IsVisible() ) then
		Assign:UpdateChoiceList()
	end
end

local function rosterUpdate(...)
	Assign:UpdatePermissions()
	
	if( Assign.singleFrame and Assign.singleFrame:IsVisible() ) then
		Assign:UpdateGroupList()
	end
end

function Assign:UpdatePermissions()
	Assign:UpdatePlayerRows()
	Assign:UpdateClassAssignments()
end

local function OnShow(self)
	if( not PaladinBuffer.foundSpells ) then
		PaladinBuffer:ScanSpells()
	end

	Assign:UpdatePlayerRows()
	Assign:UpdateAssignments()
	
	-- What blessings they can cast changed
	Assign:RegisterMessage("PB_SPELL_DATA", assignmentUpdate)

	-- Assignments changed in some way
	Assign:RegisterMessage("PB_ASSIGNMENTS_UPDATED", assignmentUpdate)
	Assign:RegisterMessage("PB_DATA_RECEIVED", assignmentUpdate)
	
	-- Roster/permissions changed, need to update permissions
	Assign:RegisterMessage("PB_PERMISSIONS_UPDATED", "UpdatePermissions")
	Assign:RegisterMessage("PB_ROSTER_UPDATED", "UpdatePermissions")
		
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
	self = Assign
	self:UnregisterAllMessages()
	self:UnlockAssignments()
	
	if( self.singleFrame ) then
		self.choiceFrame:Hide()
	end
end

-- Quick assign!
local function quickAssignBlessings()
	PaladinBuffer.modules.Assign:CalculateBlessings()
	PaladinBuffer.modules.Sync:SendAssignments()

	Assign:LockAssignments()
end

-- Reset everything
local function clearAllBlessings()
	PaladinBuffer:ClearAllAssignments()
	PaladinBuffer.modules.Sync:SendAssignmentReset()

	Assign:UnlockAssignments()
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

	Assign:UnlockAssignments()
end

-- Push blessings to the group
local function pushBlessings()
	PaladinBuffer.modules.Sync:SendAssignments()
	Assign:UnlockAssignments()
end

-- Show the single blessing UI
local function singleAssignBlessings()
	Assign:CreateSingleFrame()
	
	if( Assign.singleFrame:IsVisible() ) then
		Assign.choiceFrame:Hide()
	else
		Assign.choiceFrame:Show()
	end
end

-- Tooltips
local function showTooltip(self)
	if( self.tooltip ) then
		GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
		GameTooltip:SetText(self.tooltip, nil, nil, nil, nil, true)
		GameTooltip:Show()
	end
end

local function hideTooltip(self)
	GameTooltip:Hide()
end

function Assign:CreateFrame()
	if( self.frame ) then
		return
	end
	
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
	self.frame:SetWidth(669)
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
	button:SetPoint("TOPRIGHT", 5, 5)
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
	push:SetWidth(55)
	push:SetText(L["Push"])
	push:SetScript("OnEnter", showTooltip)
	push:SetScript("OnLeave", hideTooltip)
	push:SetScript("OnClick", pushBlessings)
	push:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 3, -4)
	push.tooltip = L["Push blessing assignments for Paladins."]
	
	self.frame.push = push

	local lock = CreateFrame("Button", nil, self.frame, "UIPanelButtonGrayTemplate")
	lock:SetNormalFontObject(GameFontHighlightSmall)
	lock:SetHighlightFontObject(GameFontHighlightSmall)
	lock:SetHeight(18)
	lock:SetWidth(55)
	lock:SetText(L["Lock"])
	lock:SetScript("OnEnter", showTooltip)
	lock:SetScript("OnLeave", hideTooltip)
	lock:SetScript("OnClick", function()
		if( Assign.assignmentsLocked ) then
			Assign:UnlockAssignments()
		else
			Assign:LockAssignments()
		end
	end)
	lock:SetPoint("TOPLEFT", push, "TOPRIGHT", 2, 0)
	lock.tooltip = L["Ignores all changes to assignments made by other people until you manually uncheck this, push assignments, clear or manually refresh them."]
	
	self.frame.lock = lock

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

	local quickAssign = CreateFrame("Button", nil, self.titleFrame, "GameMenuButtonTemplate")
	quickAssign:SetFrameStrata("MEDIUM")
	quickAssign:SetNormalFontObject(GameFontHighlightSmall)
	quickAssign:SetHighlightFontObject(GameFontHighlightSmall)
	quickAssign:SetHeight(18)
	quickAssign:SetWidth(80)
	quickAssign:SetText(L["Quick assign"])
	quickAssign:SetScript("OnClick", quickAssignBlessings)
	quickAssign:SetPoint("TOPLEFT", singleAssign, "TOPRIGHT", 15, 0)
	
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
		column.grid:SetWidth(56)
		
		if( id > 1 ) then
			column.grid:SetPoint("TOPLEFT", self.columns[id - 1].grid, "TOPRIGHT", -1, 0)
			column:SetPoint("TOPLEFT", self.columns[id - 1], "TOPRIGHT", 25, 0)   
		else
			column.grid:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 118, 0)
			column:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 130, -6)
		end

		self.columns[id] = column 
	end

	self.assignColumns = {}
	self.rows = {}
end

-- SINGLE ASSIGNMENT UI
-- Load various info into the table
function Assign:LoadUnit(unit)
	-- Make sure the unit doesn't exist, also don't double load the player
	if( not UnitExists(unit) or UnitControllingVehicle(unit) or ( unit ~= "player" and UnitIsUnit(unit, "player") ) ) then
		return
	-- Load the units pet
	elseif( UnitIsPlayer(unit) ) then
		self:LoadUnit(unit .. "pet")
	end
	
	table.insert(groupList, {})
	
	local row = groupList[#(groupList)]
	row.class = select(2, UnitClass(unit))
	
	if( UnitCreatureFamily(unit) ) then
		row.class = UnitCreatureFamily(unit)
	elseif( not PaladinBuffer.classList[row.class] ) then
		row.class = nil
		return
	end
	
	row.enabled = true
	row.type = "PLAYER"
	row.name = UnitName(unit)
	row.id = row.class == "PET" and string.format("PET.%s", row.text) or row.text
	
	classTotals[row.class] = (classTotals[row.class] or 0) + 1
end

function Assign:LoadClass(classToken)
	table.insert(groupList, {})

	local row = groupList[#(groupList)]
	row.enabled = true
	row.type = "HEADER"
	row.name = L[classToken]
	row.classTotal = classTotals[classToken]
	row.class = classToken
	
	-- Add the class header
	table.insert(displayList, #(groupList))
	
	-- Now add all of the players
	for id, row in pairs(groupList) do
		if( row.enabled and row.type == "PLAYER" and row.class == classToken ) then
			table.insert(displayList, id)
		end
	end
end

local function sortGroup(a, b)
	return a.name > b.name
end

function Assign:UpdateGroupList()
	for i=#(displayList), 1, -1 do table.remove(displayList, i) end
	for k in pairs(groupList) do groupList[k] = nil end
	for k in pairs(classTotals) do classTotals[k] = nil end
	
	-- Load player
	self:LoadUnit("player")
	
	-- Load raid
	for i=1, GetNumRaidMembers() do
		self:LoadUnit(PaladinBuffer.raidUnits[i])
	end
	
	-- Load party if not in a raid
	if( GetNumRaidMembers() == 0 ) then
		for i=1, GetNumPartyMembers() do
			self:LoadUnit(PaladinBuffer.partyUnits[i])
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

-- Selecting a Paladin to assign singles to
local function sortByName(a, b)
	return a.name < b.name
end

function Assign:UpdateChoiceList()
	for _, row in pairs(self.choiceFrame.rows) do row.name = "ZZ"; row:Hide() end
	
	local id = 0
	for name in pairs(PaladinBuffer.db.profile.blessings) do
		id = id + 1
		self.choiceFrame.rows[id].name = name
		self.choiceFrame.rows[id]:Show()
	end
	
	table.sort(self.choiceFrame.rows, sortByName)
	for id, row in pairs(self.choiceFrame.rows) do
		row:ClearAllPoints()
		
		if( row:IsVisible() ) then
			-- Color name if it was selected
			if( self.choiceFrame.selectedName == row.name ) then
				row.text:SetTextColor(1.0, 0.81, 0.0)
			else
				row.text:SetTextColor(1.0, 1.0, 1.0)
			end

			-- Update blessing icons
			for _, blessing in pairs(row.blessings) do
				if( PaladinBuffer.modules.Assign:IsBlessingAvailable(blessing.spellToken, row.name) ) then
					local total = PaladinBuffer.modules.Assign:TotalSingleAssigns(blessing.spellToken, row.name)
					blessing.count:SetText(total > 0 and total or "")
					blessing:Show()
				else
					blessing:Hide()
				end
			end

			-- Position
			if( id > 1 ) then
				row:SetPoint("TOPLEFT", self.choiceFrame.rows[id - 1], "BOTTOMLEFT", 0, -4)
			else
				row:SetPoint("TOPLEFT", self.choiceFrame, "TOPLEFT", 4, -8)
			end

			row.text:SetText(row.name)
		end
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
			if( groupData.type == "PLAYER" ) then
				-- Setup the single blessing icons
				for _, blessing in pairs(row.blessings) do
					if( singleBlacklist[groupData.class] ~= blessing.spellToken and PaladinBuffer.modules.Assign:IsBlessingAvailable(blessing.spellToken, self.choiceFrame.selectedName) ) then
						SetDesaturation(blessing:GetNormalTexture(), nil)
						
						blessing:EnableMouse(true)
						blessing:SetAlpha(0.40)
						blessing.playerName = groupData.name
						blessing.playerClass = groupData.class
						
						if( self.choiceFrame.selectedName ) then
							if( PaladinBuffer.db.profile.assignments[self.choiceFrame.selectedName][groupData.name] == blessing.spellToken ) then
								blessing:SetAlpha(1.0)
							end
						else
							for _, data in pairs(PaladinBuffer.db.profile.assignments) do
								if( data[groupData.name] == blessing.spellToken ) then
									blessing:SetAlpha(1.0)
									break
								end
							end
						end
					else
						SetDesaturation(blessing:GetNormalTexture(), true)
						
						blessing:EnableMouse(false)
						blessing:SetAlpha(0.10)
					end
					
					blessing:Show()
				end
				
				row.text:SetText(groupData.name)
				row:Show()
				
			elseif( groupData.type == "HEADER" ) then
				if( RAID_CLASS_COLORS[groupData.class] ) then
					row.text:SetFormattedText("|cff%02x%02x%02x%s|r (%d)", 255 * RAID_CLASS_COLORS[groupData.class].r, 255 * RAID_CLASS_COLORS[groupData.class].g, 255 * RAID_CLASS_COLORS[groupData.class].b, groupData.name, groupData.classTotal)
				else
					row.text:SetFormattedText("|cff%02x%02x%02x%s|r (%d)", 255 * 1.0, 255 * 0.81, 0, groupData.name, groupData.classTotal)
				end
				
				row:Show()
			end
		end
	end
end

-- Assign a single blessing to the player
local function assignSingleBlessing(self)
	-- Find who is the best for this
	local caster = Assign.choiceFrame.selectedName or PaladinBuffer.modules.Assign:FindSingleBlesser(self.spellToken)
	local spellToken = self.spellToken
	
	-- Already assigned, unassign
	if( PaladinBuffer.db.profile.assignments[caster][self.playerName] == self.spellToken ) then
		spellToken = nil
	end
	
	if( not IsShiftKeyDown() ) then
		PaladinBuffer:AssignBlessing(caster, spellToken, self.playerName)
	else
		for _, groupData in pairs(groupList) do
			if( groupData.type == "PLAYER" and groupData.class == self.playerClass ) then
				PaladinBuffer:AssignBlessing(caster, spellToken, groupData.name)
			end
		end
	end
end

-- Set a single player to assign this set of blessings
local function setSingleAssigner(self)
	if( MouseIsOver(self) ) then
		if( Assign.choiceFrame.selectedName == self.name ) then
			Assign.choiceFrame.selectedName = nil
		else
			Assign.choiceFrame.selectedName = self.name
		end

		Assign:UpdateChoiceList()
	end
end

function Assign:LockAssignments()
	self.assignmentsLocked = true
	
	if( self.frame and self.frame.lock ) then
		self.frame.lock:SetText(L["Unlock"])
	end

	PaladinBuffer.modules.Sync:Lock()
end

function Assign:UnlockAssignments()
	self.assignmentsLocked = false

	if( self.frame and self.frame.lock ) then
		self.frame.lock:SetText(L["Lock"])
	end

	PaladinBuffer.modules.Sync:Unlock()
end

-- Create the single assignment UI
function Assign:CreateSingleFrame()
	if( self.singleFrame ) then
		return
	end
	
	groupList = {}
	displayList = {}
	classTotals = {}
	
	-- Choosing a Paladin to assign singles
	self.choiceFrame = CreateFrame("Frame", nil, self.frame)
	self.choiceFrame:SetFrameStrata("HIGH")
	self.choiceFrame:SetHeight(300)
	self.choiceFrame:SetWidth(170)
	self.choiceFrame:SetBackdrop(self.backdrop)
	self.choiceFrame:SetBackdropColor(0.0, 0.0, 0.0, 1.0)
	self.choiceFrame:SetBackdropBorderColor(0.90, 0.90, 0.90, 0.95)
	self.choiceFrame:SetPoint("TOPLEFT", self.frame.push, "TOPRIGHT", 60, 4)
	self.choiceFrame:Hide()
	self.choiceFrame:SetScript("OnShow", function()
		Assign:UpdateChoiceList()	
		Assign:UpdateGroupList()
		Assign:UpdateSingle()
	end)
	
	self.choiceFrame.rows = {}
	
	for i=1, 11 do
		local row = CreateFrame("Frame", nil, self.choiceFrame)
		row:SetWidth(165)
		row:SetHeight(16)
		row:SetScript("OnMouseUp", setSingleAssigner)
		row:EnableMouse(true)
		row:Hide()
		
		row.text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
		row.text:SetPoint("TOPLEFT", row, "TOPLEFT")
		row.text:SetJustifyH("LEFT")
		row.text:SetWidth(85)
		row.text:SetHeight(16)

		row.blessings = {}
		for bID, spellToken in pairs(singleBlessings) do
			local button = CreateFrame("Button", nil, row)
			button:SetNormalTexture(blessingIcons[spellToken])
			button:SetHeight(16)
			button:SetWidth(16)
			button.spellToken = spellToken

			button.count = button:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
			button.count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT")

			if( bID > 1 ) then
				button:SetPoint("TOPLEFT", row.blessings[bID - 1], "TOPRIGHT", 2, 0)
			else
				button:SetPoint("TOPLEFT", row, "TOPRIGHT", -75, 1)
			end

			row.blessings[bID] = button
		end

		self.choiceFrame.rows[i] = row
	end

	-- Assigning singles to players
	self.singleFrame = CreateFrame("Frame", nil, self.choiceFrame)
	self.singleFrame:SetFrameStrata("HIGH")
	self.singleFrame:SetHeight(300)
	self.singleFrame:SetWidth(245)
	self.singleFrame:SetBackdrop(self.backdrop)
	self.singleFrame:SetBackdropColor(0.0, 0.0, 0.0, 1.0)
	self.singleFrame:SetBackdropBorderColor(0.90, 0.90, 0.90, 0.95)
	self.singleFrame:SetPoint("TOPLEFT", self.choiceFrame, "TOPRIGHT", 3, 0)

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

function Assign:Reload()
	if( self.frame ) then
		self.frame:SetScale(PaladinBuffer.db.profile.scale)
	end
end
