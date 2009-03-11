if( not PaladinBuffer ) then return end

local Buff = PaladinBuffer:NewModule("BuffGUI", "AceEvent-3.0")
local L = PaladinBufferLocals
local blessings = {[GetSpellInfo(56520)] = "might", [GetSpellInfo(48934)] = "gmight", [GetSpellInfo(56521)] = "wisdom", [GetSpellInfo(48938)] = "gwisdom", [GetSpellInfo(20911)] = "sanct", [GetSpellInfo(25899)] = "gsanct", [GetSpellInfo(20217)] = "kings", [GetSpellInfo(25898)] = "gkings"}
local blessingIcons = {["gmight"] = select(3, GetSpellInfo(48934)), ["gwisdom"] = select(3, GetSpellInfo(48938)), ["gsanct"] = select(3, GetSpellInfo(25899)),["gkings"] = select(3, GetSpellInfo(25898)), ["might"] = select(3, GetSpellInfo(56520)), ["wisdom"] = select(3, GetSpellInfo(56521)), ["sanct"] = select(3, GetSpellInfo(20911)), ["kings"] = select(3, GetSpellInfo(20217))}
local auraUpdates, singleTimes, greaterTimes, singleTypes, greaterTypes = {}, {}, {}, {}, {}
local playerName = UnitName("player")
local inCombat

local GREATER_DURATION = 1800
local SINGLE_DURATION = 600

function Buff:Enable()
	if( PaladinBuffer.disabled ) then
		return
	end
	
	assignments = PaladinBuffer.db.profile.assignments[UnitName("player")]
	groupRoster = PaladinBuffer.groupRoster
	inCombat = InCombatLockdown()

	self:RegisterEvent("UNIT_AURA")
	self:RegisterEvent("PLAYER_REGEN_DISABLED")
	self:RegisterEvent("PLAYER_REGEN_ENABLED")
	
	self:RegisterMessage("PB_ROSTER_UPDATED", "UpdateClassFrames")
	self:RegisterMessage("PB_ASSIGNED_BLESSINGS", "UpdateFrame")
	self:RegisterMessage("PB_RESET_ASSIGNMENTS", "UpdateFrame")
	self:RegisterMessage("PB_CLEARED_ASSIGNMENTS", "UpdateFrame")
	
	self:ScanGroup()
	self:UpdateClassFrames()
end

function Buff:Disable()
	self:UnregisterAllEvents()
	self:UnregisterAllMessages()
	
	if( blessingTimers ) then
		for _, data in pairs(blessingTimers) do
			for k in pairs(data) do data[k] = nil end
		end
	end
	
	if( self.frame ) then
		self.frame:Hide()
	end
end

function Buff:UpdateFrame()
	if( self.frame and self.frame:IsVisible() ) then
		self:ScanGroup()
		self:UpdateAssignmentIcons()
		self:UpdateAuraTimes()
		self:UpdateColorStatus(self.frame, self.frame.filter)
		
		for _, frame in pairs(self.frame.classes) do
			self:UpdateColorStatus(frame, frame.filter)
		end
	end
end

function Buff:PLAYER_REGEN_DISABLED()
	inCombat = true
		
	if( self.frame ) then
		self.frame.icon:SetAlpha(0.50)
		
		if( PaladinBuffer.db.profile.frame.hideInCombat ) then
			self.frame:Hide()
		end
	end
end

function Buff:PLAYER_REGEN_ENABLED()
	inCombat = nil
	
	if( updateQueued ) then
		updateQueued = nil
		self:UpdateClassFrames()
	elseif( self.frame and PaladinBuffer.db.profile.frame.hideInCombat ) then
		self:UpdateClassFrames()
	end

	if( self.frame ) then
		self.frame.icon:SetAlpha(0.50)
		self.frame:Show()
	end
end

-- Update if we have people in or out of range
function Buff:UpdateColorStatus(frame, filter)
	local hasSingleOOR, lowestSingle, hasSingleMissing
	local hasGreaterCast, hasGreaterOOR, lowestGreater, hasGreaterMissing	
	
	for name, unit in pairs(groupRoster) do
		local classToken = select(2, UnitClass(unit))
		if( ( classToken == filter or filter == "ALL" ) and ( PaladinBuffer.db.profile.offline or UnitIsConnected(unit) ) ) then
			local greaterBlessing = PaladinBuffer.blessings[assignments[classToken]]
			
			-- Are we assigned to cast a single on this person?
			if( assignments[name] ) then
				-- Unlike greater blessings, we have to enforce the 30 yard range on singles :(
				if( IsSpellInRange(PaladinBuffer.blessings[assignments[name]], unit) ~= 1 ) then
					hasSingleOOR = true
				end
				
				local buffTime = singleTimes[name]
				if( not buffTime or singleTypes[name] ~= assignments[name] ) then
					hasSingleMissing = true
				elseif( not lowestSingle or lowestSingle > buffTime ) then
					lowestSingle = buffTime
				end
			
			-- Nope, a greater!
			elseif( greaterBlessing ) then
				-- Check if we have someone we can cast this initially on
				if( not hasGreaterCast and IsSpellInRange(greaterBlessing, unit) == 1 ) then
					hasGreaterCast = true
				end

				-- Someone isn't visible, so out of range ( :( )
				if( not UnitIsVisible(unit) ) then
					hasGreaterOOR = true
				end

				-- Find the lowest buff time + does someone have a buff missing
				local buffTime = greaterTimes[name]
				if( not buffTime or greaterTypes[name] ~= assignments[classToken] ) then
					hasGreaterMissing = true
				elseif( not lowestGreater or lowestGreater > buffTime ) then
					lowestGreater = buffTime
				end
			end
		end
	end
	
	local needRecast
	local time = GetTime()
	if( hasGreaterMissing ) then
		needRecast = "greater"
	elseif( hasSingleMissing ) then
		needRecast = "single"
	elseif( lowestSingle and ((lowestSingle - time) / 60) < PaladinBuffer.db.profile.singleThreshold ) then
		needRecast = "single"
	elseif( lowestGreater and ((lowestGreater - time) / 60) < PaladinBuffer.db.profile.greaterThreshold ) then
		needRecast = "greater"		
	end
		
	if( not needRecast ) then
		frame:SetBackdropColor(0, 0, 0, 1.0)
	elseif( needRecast == "greater" ) then
		if( hasGreaterCast and hasGreaterOOR ) then
			frame:SetBackdropColor(0.80, 0.80, 0.10, 1.0)
		else
			frame:SetBackdropColor(0.70, 0.10, 0.10, 1.0)
		end
	elseif( needRecast == "single" ) then
		if( hasSingleOOR ) then
			frame:SetBackdropColor(0.80, 0.80, 0.10, 1.0)
		else
			frame:SetBackdropColor(0.70, 0.10, 0.10, 1.0)
		end
	end
end

-- Figure out who we're going to be casting this one
function Buff:FindLowestTime(classFilter, blessingName)
	local classTotal = 0
	local hasBuff = 0
	local visibleRange = 0
	local totalOnline = 0
	local lowestTime, inSpellRange, spellDuration
	
	for name, unit in pairs(groupRoster) do
		local classToken = select(2, UnitClass(unit))
		if( classToken == classFilter and ( PaladinBuffer.db.profile.offline or UnitIsConnected(unit) ) ) then
			classTotal = classTotal + 1
						
			-- Are they online?
			--if( UnitIsConnected(unit) ) then
			--	totalOnline = totalOnline + 1
			--end
			
			-- Blessings are done using visible range, so if they are within 100 yards, we can bless them
			if( UnitIsVisible(unit) ) then
				visibleRange = visibleRange + 1
			end
			
			-- However! We need an initial target, so we have to make sure at least one person is within range of us
			if( IsSpellInRange(blessingName, unit) == 1 ) then
				inSpellRange = unit
			end
		
			-- Check if they have the buff
			local buffID = 1
			while( true ) do
				local buffName, rank, texture, count, debuffType, duration, endTime, isMine, isStealable = UnitAura(unit, buffID, "PLAYER")
				if( not buffName ) then break end
				
				if( blessingName == buffName ) then
					hasBuff = hasBuff + 1
					
					if( not lowestTime or lowestTime > endTime ) then
						spellDuration = duration
						lowestTime = endTime
					end
					break
				end
				
				
				buffID = buffID + 1
			end
		end
	end
	
	-- Nobody of this class is even in the raid
	if( classTotal == 0 ) then
		return "none"	
	end
	
	-- Either nobody is in range for the initial spell, or the total people we have visible is below the threshold
	-- regardless show that we can't hit them due to range.
	if( not inSpellRange or (visibleRange / classTotal) < PaladinBuffer.db.profile.rangeThreshold ) then
		return "oor"
	end
	
	-- Convert it from time into seconds left
	if( lowestTime ) then
		lowestTime = lowestTime - GetTime()
	end

	-- Either we don't have this buff on the class yet, or we do but the time is below the threshold percent
	local timeType = "singleThreshold"
	if( PaladinBuffer.blessingTypes[blessings[blessingName]] == "greater" ) then
		timeType = "greaterThreshold"
	end

	if( hasBuff < visibleRange or not lowestTime or (lowestTime / 60) < PaladinBuffer.db.profile[timeType] ) then
		return "cast", inSpellRange, (lowestTime or 0)
	end
	
	return "nil"
end

-- Return info for auto buffing on the lowest greater
function Buff:AutoBuffLowestGreater(filter)
	local castSpellOn, castSpell, lowestTime
	for assignment, spellToken in pairs(assignments) do
		if( spellToken ~= "none" and PaladinBuffer.classList[assignment] and ( filter == "ALL" or filter == assignment ) ) then
			local status, spellTarget, timeLeft = self:FindLowestTime(assignment, PaladinBuffer.blessings[spellToken])
			if( status == "cast" ) then
				if( not lowestTime or lowestTime > timeLeft ) then
					castSpell = PaladinBuffer.blessings[spellToken]
					castSpellOn = spellTarget
					lowestTime = timeLeft
				end
			end
		end
	end
	
	if( castSpellOn ) then
		return "spell", castSpellOn, castSpell
	end
	
	return nil
end

-- Return info on auto buffing the lowest single
function Buff:AutoBuffLowestSingle(filter)
	local lowestTime, castSpell, castSpellOn
	
	-- Find the lowest single blessing we cast, or the first missing one
	for assignment, spellToken in pairs(assignments) do
		local unit = groupRoster[assignment]
		if( unit and ( filter == "ALL" or filter == select(2, UnitClass(unit)) ) ) then
			local blessingName = PaladinBuffer.blessings[spellToken]
			
			if( IsSpellInRange(blessingName, unit) == 1 ) then
				local buffID = 1
				local foundBuff
				while( true ) do
					local buffName, rank, texture, count, debuffType, duration, endTime, isMine, isStealable = UnitAura(unit, buffID, "PLAYER")
					if( not buffName ) then break end

					if( buffName == blessingName ) then
						foundBuff = true
						
						if( not lowestTime or lowestTime >= endTime ) then
							lowestTime = endTime
							castSpell = blessingName
							castSpellOn = unit
						end
					end
					
					buffID = buffID + 1
				end
				
				-- They should have a buff up, but they don't, bad!
				if( not foundBuff ) then
					castSpell = blessingName
					castSpellOn = unit
					break
				end
			end
		end
	end
	
	-- Everyone has the buff, so check if the lowest is below the threshold
	if( not lowestTime and castSpell and castSpellOn ) then
		return "spell", castSpellOn, castSpell
	elseif( lowestTime and (lowestTime / 60) < PaladinBuffer.db.profile.singleThreshold ) then
		return "spell", castSpellOn, castSpell
	else
		return nil, nil, nil
	end
end

-- Does an initial scan to get us our "base line" of time left on everything
function Buff:ScanGroup()
	self:ScanAuras("player")
	
	for i=1, GetNumRaidMembers() do
		self:ScanAuras(PaladinBuffer.raidUnits[i])
	end
	
	if( GetNumRaidMembers() == 0 ) then
		for i=1, GetNumPartyMembers() do
			self:ScanAuras(PaladinBuffer.partyUnits[i])
		end
	end
	
	self:UpdateAuraTimes()
end

-- Scan auras for the time left on the blessing
function Buff:ScanAuras(unit)
	if( UnitCreatureFamily(unit) ) then return end

	local class = select(2, UnitClass(unit))
	local name = UnitName(unit)
	
	-- Remove the blessing timers we had for them last update
	singleTimes[name] = nil
	singleTypes[name] = nil
	
	greaterTimes[name] = nil	
	greaterTypes[name] = nil
	
	local id = 1
	while( true ) do
		local buffName, rank, texture, count, debuffType, duration, endTime, isMine, isStealable = UnitAura(unit, id, "PLAYER")
		if( not buffName ) then break end
		
		-- Store the lowest single and greater blessing we cast on them, if it was assigned for them
		local spellToken = blessings[buffName]
		if( spellToken and ( assignments[class] == spellToken or assignments[name] == spellToken ) ) then
			local category = PaladinBuffer.blessingTypes[spellToken]
			if( category == "single" and ( not singleTimes[name] or singleTimes[name] > endTime ) ) then
				singleTimes[name] = endTime
				singleTypes[name] = spellToken
			elseif( category == "greater" and ( not greaterTimes[name] or greaterTimes[name] > endTime ) ) then
				greaterTimes[name] = endTime
				greaterTypes[name] = spellToken
			end
		end
		
		id = id + 1
	end
end

function Buff:UNIT_AURA(event, unit)
	if( not UnitIsEnemy("player", unit) ) then
		self:ScanAuras(unit)
		self:UpdateAuraTimes()
	end
end

-- Update buff timers on this frame
local function updateTimer(self)
	local time = GetTime()
		
	-- Find the lowest single blessing timer (if any)
	if( self.singleIcon ) then
		local lowestTime
		for name, endTime in pairs(singleTimes) do
			if( ( not lowestTime or lowestTime > endTime ) and UnitExists(name) ) then
				if( singleTypes[name] == assignments[name] and ( self.filter == "ALL" or self.filter == select(2, UnitClass(name)) ) ) then
					lowestTime = endTime
				end
			end
		end

		if( lowestTime and lowestTime >= time ) then
			Buff:FormatTime(self.singleText, self.singleIcon, lowestTime - time)
		else
			self.singleText:SetFormattedText("|T%s:19:19:0:0|t %s", self.singleIcon, "---")
		end
	else
		self.singleText:SetText("")
	end

	-- Find the lowest greater blessing timer (if any)
	local lowestTime
	for name, endTime in pairs(greaterTimes) do
		if( ( not lowestTime or lowestTime > endTime ) and UnitExists(name) ) then
			local classToken = select(2, UnitClass(name))
			if( greaterTypes[name] == assignments[classToken] and ( self.filter == "ALL" or self.filter == classToken ) ) then
				lowestTime = endTime
			end
		end
	end
		
	if( lowestTime and lowestTime >= time ) then
		Buff:FormatTime(self.greaterText, self.greaterIcon, lowestTime - time)
	elseif( self.filter ~= "ALL" and assignments[self.filter] == "none" ) then
		self.greaterText:SetFormattedText("|T%s:19:19:0:0|t %s", self.greaterIcon, L["None"])
	else
		self.greaterText:SetFormattedText("|T%s:19:19:0:0|t %s", self.greaterIcon, "---")
	end
end

-- Update all frame aura timers
function Buff:UpdateAuraTimes()
 	for frame in pairs(auraUpdates) do
		if( frame:IsVisible() ) then
			updateTimer(frame)
		end
	end
end

-- Update the timer every 10 seconds
local function OnUpdate(self, elapsed)
	self.timeElapsed = self.timeElapsed + elapsed
	if( self.timeElapsed >= 5 ) then
		self.timeElapsed = 0
		updateTimer(self)
	end
	
	if( not inCombat ) then
		self.rangedElapsed = self.rangedElapsed + elapsed
		if( self.rangedElapsed >= 0.50 ) then
			self.rangedElapsed = 0
			Buff:UpdateColorStatus(self, self.filter)
		end
	end
end

function Buff:CreateSingleFrame(parent)
	local frame = CreateFrame("Button", nil, parent, "SecureActionButtonTemplate")
	frame:SetFrameStrata("MEDIUM")
	frame:SetHeight(32)
	frame:SetWidth(85)
	frame:SetBackdrop(self.backdrop)
	frame:SetBackdropColor(0.0, 0.0, 0.0, 1.0)
	frame:SetBackdropBorderColor(0.75, 0.75, 0.75, 0.90)
	frame:SetScript("OnShow", updateTimer)
	frame:SetScript("OnUpdate", OnUpdate)
	frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 450, -100)
	frame:RegisterForClicks("AnyDown")
	frame.timeElapsed = 0
	frame.rangedElapsed = 0
	frame:Hide()
	
	frame:SetScript("PreClick", function(self, mouse)
		if( inCombat ) then
			return
		end
		
		if( mouse == "LeftButton" ) then
			local type, unit, spell = Buff:AutoBuffLowestGreater(self.filter)
			self:SetAttribute("type1", type)
			self:SetAttribute("unit1", unit)
			self:SetAttribute("spell1", spell)
		
		elseif( mouse == "RightButton" ) then
			local type, unit, spell = Buff:AutoBuffLowestSingle(self.filter)
			self:SetAttribute("type2", type)
			self:SetAttribute("unit2", unit)
			self:SetAttribute("spell2", spell)
		end
	end)
	
	--frame.title = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	--frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -2)

	frame.icon = frame:CreateTexture(nil, "ARTWORK")
	frame.icon:SetHeight(24)
	frame.icon:SetWidth(24)
	frame.icon:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -4)

	frame.greaterText = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	frame.greaterText:SetFont((GameFontHighlightSmall:GetFont()), 11)
	frame.greaterText:SetPoint("TOPLEFT", frame.icon, "TOPRIGHT", 2, 1)

	frame.singleText = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	frame.singleText:SetFont((GameFontHighlightSmall:GetFont()), 11)
	frame.singleText:SetPoint("TOPLEFT", frame.greaterText, "BOTTOMLEFT", 0, -2)

	frame.greaterIcon = ""
	frame.singleIcon = "Interface\\Icons\\Spell_Holy_ProclaimChampion"
	
	auraUpdates[frame] = true
	
	return frame
end

function Buff:CreateFrame()
	if( self.frame ) then
		return
	end
	
	self.backdrop = {bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
		tile = false,
		edgeSize = 0.8,
		tileSize = 5,
		insets = {left = 0, right = 0, top = 0, bottom = 0}
	}

	-- Functions for the main container frame
	local OnShow = function(self)
		updateTimer(self)
		
		if( PaladinBuffer.db.profile.frame.position ) then
			local scale = self:GetEffectiveScale()
			self:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", PaladinBuffer.db.profile.frame.position.x / scale, PaladinBuffer.db.profile.frame.position.y / scale)
		else
			self:SetPoint("CENTER", UIParent, "CENTER")
		end
	end
	
	local OnMouseDown = function(self)
		if( not self.isMoving and IsAltKeyDown() and not PaladinBuffer.db.profile.frame.locked ) then
			self.isMoving = true
			self:StartMoving()
		end
	end
	
	local OnMouseUp = function(self)
		if( self.isMoving ) then
			local scale = self:GetEffectiveScale()

			self.isMoving = nil
			self:StopMovingOrSizing()

			PaladinBuffer.db.profile.frame.position = {x = self:GetLeft() * scale, y = self:GetTop() * scale}
		end
	end
	
	-- Create it all!
	self.frame = self:CreateSingleFrame(UIParent)
	self.frame.singleIcon = "Interface\\Icons\\Spell_Holy_ProclaimChampion"
	self.frame.greaterIcon = "Interface\\Icons\\Spell_Holy_ProclaimChampion_02"
	self.frame.filter = "ALL"
	self.frame.icon:SetTexture("Interface\\Icons\\Spell_Holy_Aspiration")
	self.frame:SetScale(PaladinBuffer.db.profile.frame.scale)
	self.frame.classes = {}
	self.frame:SetScript("OnShow", OnShow)
	self.frame:SetScript("OnMouseDown", OnMouseDown)
	self.frame:SetScript("OnMouseUp", OnMouseUp)
	self.frame:SetMovable(true)
	self.frame:Show()
end

-- Create the necessary class frames if we have to
function Buff:UpdateClassFrames()
	-- All frame things are disabled
	if( not PaladinBuffer.db.profile.frame.enabled or ( GetNumRaidMembers() == 0 and GetNumPartyMembers() == 0 ) ) then
		if( self.frame ) then
			self.frame:Hide()
		end
		return
	end
	
	if( inCombat ) then
		updateQueued = true
		return
	end
	
	-- Create our main anchor
	self:CreateFrame()
	self.frame:Show()
	
	-- Class frames are disabled
	if( not PaladinBuffer.db.profile.frame.classes ) then
		return
	end	
	
	-- Flag it as we haven't updated
	for _, frame in pairs(self.frame.classes) do frame.wasUpdated = nil end
	
	-- Now scan the group and create/update any frames if needed
	for _, unit in pairs(groupRoster) do
		local class, classToken = UnitClass(unit)
		if( class and classToken ) then
			local frame = self.frame.classes[classToken]
			if( not frame ) then
				frame = self:CreateSingleFrame(self.frame)
				frame.filter = classToken
				
				local coords = CLASS_BUTTONS[classToken]
				frame.icon:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes")
				frame.icon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
				
				self.frame.classes[classToken] = frame
			end

			frame.wasUpdated = true
		end
	end
	
	-- Update assignment icons for the timer things
	self:UpdateAssignmentIcons()

	-- The frame wasn't updated this go around, so we can hide it as the class is gone
	for _, frame in pairs(self.frame.classes) do
		if( not frame.wasUpdated ) then
			frame:Hide()
		else
			frame:Show()
		end
	end
	
	-- Reposition
	self:PositionClassFrames()
end

function Buff:PositionClassFrames()
	local id, inColumn = 1, 1
	local columnStart, previousRow = self.frame, self.frame

	for classToken, frame in pairs(self.frame.classes) do
		if( frame:IsVisible() ) then
			if( inColumn == PaladinBuffer.db.profile.frame.columns ) then
				frame:ClearAllPoints()
				
				if( PaladinBuffer.db.profile.frame.growUp ) then
					frame:SetPoint("BOTTOMLEFT", columnStart, "TOPLEFT", 0, 1)
				else
					frame:SetPoint("TOPLEFT", columnStart, "BOTTOMLEFT", 0, -1)
				end

				columnStart = frame
				inColumn = 0
			else
				frame:ClearAllPoints()
				
				if( PaladinBuffer.db.profile.frame.growUp ) then
					frame:SetPoint("BOTTOMLEFT", previousRow, "BOTTOMRIGHT", 2, 0)    
				else
					frame:SetPoint("TOPLEFT", previousRow, "TOPRIGHT", 2, 0)    
				end
			end

			previousRow = frame
			inColumn = inColumn + 1
			id = id + 1
		end
	end
	
	-- Reposition the main frame as well
	self.frame:ClearAllPoints()

	if( PaladinBuffer.db.profile.frame.position ) then
		local scale = self.frame:GetEffectiveScale()
		self.frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", PaladinBuffer.db.profile.frame.position.x / scale, PaladinBuffer.db.profile.frame.position.y / scale)
	else
		self.frame:SetPoint("CENTER", UIParent, "CENTER")
	end
	
end

function Buff:Reload()
	if( self.frame ) then
		self.frame:SetScale(PaladinBuffer.db.profile.frame.scale)
		self:PositionClassFrames()
	end
end

-- Update the display icon for assignments
function Buff:UpdateAssignmentIcons()
	-- Now set the greater blessing icon + a single one if needed
	for assignment, spellToken in pairs(assignments) do
		if( PaladinBuffer.classList[assignment] ) then
			local frame = self.frame.classes[assignment]
			if( frame ) then
				frame.greaterIcon = blessingIcons[spellToken] or self.frame.greaterIcon
			end
		end
	end
end

-- Format seconds into 50s/30m/etc
function Buff:FormatTime(text, icon, timeLeft)
	local hours, minutes, seconds = 0, 0, 0
	if( timeLeft >= 3600 ) then
		hours = floor(timeLeft / 3600)
		timeLeft = mod(timeLeft, 3600)
	end

	if( timeLeft >= 60 ) then
		minutes = floor(timeLeft / 60)
		timeLeft = mod(timeLeft, 60)
	end

	if( hours > 0 ) then
		text:SetFormattedText("|T%s:20:20:0:0|t %dh", icon, hours)
	elseif( minutes > 0 ) then
		text:SetFormattedText("|T%s:20:20:0:0|t %dm", icon, minutes)
	else
		text:SetFormattedText("|T%s:20:20:0:0|t %02ds", icon, timeLeft > 0 and timeLeft or 0)
	end
end