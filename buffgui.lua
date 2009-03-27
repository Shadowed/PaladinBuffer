if( not PaladinBuffer ) then return end

local Buff = PaladinBuffer:NewModule("BuffGUI", "AceEvent-3.0")
local L = PaladinBufferLocals
local blessings = {[GetSpellInfo(56520)] = "might", [GetSpellInfo(48934)] = "gmight", [GetSpellInfo(56521)] = "wisdom", [GetSpellInfo(48938)] = "gwisdom", [GetSpellInfo(20911)] = "sanct", [GetSpellInfo(25899)] = "gsanct", [GetSpellInfo(20217)] = "kings", [GetSpellInfo(25898)] = "gkings"}
local blessingIcons = {["gmight"] = select(3, GetSpellInfo(48934)), ["gwisdom"] = select(3, GetSpellInfo(48938)), ["gsanct"] = select(3, GetSpellInfo(25899)),["gkings"] = select(3, GetSpellInfo(25898)), ["might"] = select(3, GetSpellInfo(56520)), ["wisdom"] = select(3, GetSpellInfo(56521)), ["sanct"] = select(3, GetSpellInfo(20911)), ["kings"] = select(3, GetSpellInfo(20217))}
local classFrames, singleTimes, greaterTimes, singleTypes, greaterTypes = {}, {}, {}, {}, {}
local playerName = UnitName("player")
local inCombat

function Buff:Enable()
	if( PaladinBuffer.disabled ) then
		return
	end
	
	assignments = PaladinBuffer.db.profile.assignments[playerName]
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
	
	if( self.parent ) then
		self.parent:Hide()
	end
end

function Buff:UpdateFrame()
	if( not self.frame or not self.parent:IsVisible() ) then
		return
	end
	
	self:ScanGroup()
	self:UpdateAuraTimes()
	
	if( self.frame:IsVisible() ) then
		self:UpdateColorStatus(self.frame, self.frame.filter)
	end

	for _, frame in pairs(classFrames) do
		self:UpdateColorStatus(frame, frame.filter)
	end
end

function Buff:PLAYER_REGEN_DISABLED()
	inCombat = true
	
	if( self.frame ) then
		-- Fade out the icon to show we're in combat
		self.frame.icon:SetAlpha(0.50)
		-- Stop any buffing in combat regardless
		self.frame:SetAttribute("type", nil)
	end

	for _, frame in pairs(classFrames) do
		frame:SetAttribute("type", nil)
	end

	-- Supposed to keep this hidden in combat
	if( self.parent and PaladinBuffer.db.profile.frame.hideInCombat ) then
		self.parent:Hide()
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
		self.frame.icon:SetAlpha(1.0)
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
				if( IsSpellInRange(greaterBlessing, unit) == 1 ) then
					hasGreaterCast = true
				else
					hasGreaterOOR = true
				end

				-- Someone isn't visible, so out of range ( :( )
				--if( not UnitIsVisible(unit) ) then
				--	hasGreaterOOR = true
				--end

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
		frame:SetBackdropColor(PaladinBuffer.db.profile.frame.background.r, PaladinBuffer.db.profile.frame.background.g, PaladinBuffer.db.profile.frame.background.b, 1.0)
	elseif( ( needRecast == "greater" and hasGreaterCast and hasGreaterOOR ) or ( needRecast == "single" and hasSingleOOR ) ) then
		frame:SetBackdropColor(PaladinBuffer.db.profile.frame.cantRebuff.r, PaladinBuffer.db.profile.frame.cantRebuff.g, PaladinBuffer.db.profile.frame.cantRebuff.b, 1.0)
	else
		frame:SetBackdropColor(PaladinBuffer.db.profile.frame.needRebuff.r, PaladinBuffer.db.profile.frame.needRebuff.g, PaladinBuffer.db.profile.frame.needRebuff.b, 1.0)
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
		if( classToken == classFilter and ( PaladinBuffer.db.profile.offline or UnitIsConnected(unit) ) and not assignments[name] ) then
			classTotal = classTotal + 1
									
			-- Blessings are done using visible range, so if they are within 100 yards, we can bless them
			--if( UnitIsVisible(unit) and not UnitIsDeadOrGhost(unit) ) then
			--	visibleRange = visibleRange + 1
			--end
			
			-- However! We need an initial target, so we have to make sure at least one person is within range of us
			if( IsSpellInRange(blessingName, unit) == 1 and not UnitIsDeadOrGhost(unit) ) then
				visibleRange = visibleRange + 1
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
		if( spellToken and PaladinBuffer.classList[assignment] and ( filter == "ALL" or filter == assignment ) ) then
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
	
	if( lowestTime ) then
		lowestTime = lowestTime - GetTime()
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
	local lowestTime
	for name, endTime in pairs(singleTimes) do
		if( ( not lowestTime or lowestTime > endTime ) and UnitExists(name) ) then
			if( singleTypes[name] == assignments[name] and ( self.filter == "ALL" or self.filter == select(2, UnitClass(name)) ) ) then
				lowestTime = endTime
			end
		end
	end

	if( lowestTime and lowestTime >= time ) then
		Buff:FormatTime(self.singleText, lowestTime - time)
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
		Buff:FormatTime(self.greaterText, lowestTime - time)
	elseif( self.filter ~= "ALL" and not assignments[self.filter] ) then
		self.greaterText:SetText(L["None"])
	else
		self.greaterText:SetText("---")
	end
end

-- Update all frame aura timers
function Buff:UpdateAuraTimes()
 	for _, frame in pairs(classFrames) do
		if( frame:IsVisible() ) then
			updateTimer(frame)
		end
	end
	
	if( self.frame and self.frame:IsVisible() ) then
		updateTimer(self.frame)
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

-- Figure out who to buff
local function PreClick(self, mouse)
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
end

function Buff:CreateSingleFrame(parent)
	self.backdrop = self.backdrop or {bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
		tile = false,
		edgeSize = 0.8,
		tileSize = 5,
		insets = {left = 0, right = 0, top = 0, bottom = 0}
	}

	local frame = CreateFrame("Button", nil, parent or UIParent, "SecureActionButtonTemplate")
	frame:SetFrameStrata("MEDIUM")
	frame:SetHeight(32)
	frame:SetWidth(65)
	frame:SetBackdrop(self.backdrop)
	frame:SetBackdropColor(PaladinBuffer.db.profile.frame.background.r, PaladinBuffer.db.profile.frame.background.g, PaladinBuffer.db.profile.frame.background.b, 1.0)
	frame:SetBackdropBorderColor(PaladinBuffer.db.profile.frame.border.r, PaladinBuffer.db.profile.frame.border.g, PaladinBuffer.db.profile.frame.border.b, 1.0)
	frame:SetScript("OnShow", updateTimer)
	frame:SetScript("OnUpdate", OnUpdate)
	frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 450, -100)
	frame:RegisterForClicks("AnyDown")
	frame.timeElapsed = 0
	frame.rangedElapsed = 0
	frame:Hide()
	
	frame:SetScript("PreClick", PreClick)
	
	frame.icon = frame:CreateTexture(nil, "ARTWORK")
	frame.icon:SetHeight(24)
	frame.icon:SetWidth(24)
	frame.icon:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -4)

	frame.greaterText = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	frame.greaterText:SetFont((GameFontHighlightSmall:GetFont()), 12)
	frame.greaterText:SetPoint("TOPLEFT", frame.icon, "TOPRIGHT", 2, 1)

	frame.singleText = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	frame.singleText:SetFont((GameFontHighlightSmall:GetFont()), 12)
	frame.singleText:SetPoint("TOPLEFT", frame.greaterText, "BOTTOMLEFT", 0, -2)
	
	return frame
end

-- Functions for the parent frame
local function positionParent(self)
	self:ClearAllPoints()
	
	if( PaladinBuffer.db.profile.frame.position ) then
		local scale = self:GetEffectiveScale()
		self:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", PaladinBuffer.db.profile.frame.position.x / scale, PaladinBuffer.db.profile.frame.position.y / scale)
	else
		self:SetPoint("CENTER", UIParent, "CENTER")
	end
end

local function OnShow(self)
	updateTimer(self)
	positionParent(self)
end

local function OnMouseDown(self)
	if( not self.isMoving and IsAltKeyDown() and not PaladinBuffer.db.profile.frame.locked ) then
		self.isMoving = true
		self:StartMoving()
	end
end

local function OnMouseUp(self)
	if( self.isMoving ) then
		local scale = self:GetEffectiveScale()

		self.isMoving = nil
		self:StopMovingOrSizing()

		PaladinBuffer.db.profile.frame.position = {x = self:GetLeft() * scale, y = self:GetTop() * scale}
	end
end

function Buff:SetParentFrame(frame)
	frame:SetScript("OnShow", OnShow)
	frame:SetScript("OnMouseDown", OnMouseDown)
	frame:SetScript("OnMouseUp", OnMouseUp)
	frame:SetScale(PaladinBuffer.db.profile.frame.scale)
	frame:SetParent(UIParent)
	frame:SetMovable(true)
	
	positionParent(frame)
	
	-- Set everything to this as a parent
	for _, class in pairs(classFrames) do
		if( class.filter ~= frame.filter ) then
			class:SetScale(1.0)
			class:SetParent(frame)
		end
	end
	
	self.parent = frame
end

function Buff:ResetParentFrame(frame)
	frame:SetScript("OnShow", updateTimer)
	frame:SetScript("OnMouseDown", nil)
	frame:SetScript("OnMouseUp", nil)
	frame:SetMovable(false)
	frame:SetParent(self.frame)
end

function Buff:CreateFrame()
	if( self.frame ) then
		return
	end
		
	-- Create it all!
	self.frame = self:CreateSingleFrame()
	self.frame.filter = "ALL"
	self.frame.icon:SetTexture("Interface\\Icons\\Spell_Holy_Aspiration")
	self.frame:Show()
	
	-- This frame is supposed to be shown, so it can be the parent
	if( PaladinBuffer.db.profile.frame.enabled ) then
		self:SetParentFrame(self.frame)
	end
end

-- Create the necessary class frames if we have to
function Buff:UpdateClassFrames()
	-- Not grouped, don't show it
	if( ( GetNumRaidMembers() == 0 and GetNumPartyMembers() == 0 and PaladinBuffer.db.profile.frame.locked ) or ( not PaladinBuffer.db.profile.frame.enabled and not PaladinBuffer.db.profile.frame.classes ) ) then
		if( self.parent ) then
			self.parent:Hide()
		end
		return
	end

	-- In combat, update when we leave
	if( inCombat ) then
		updateQueued = true
		return
	end
	
	-- Create our main anchor
	self:CreateFrame()

	if( PaladinBuffer.db.profile.frame.enabled ) then
		self.frame:Show()
	else
		self.frame:Hide()
	end
	
	-- Class frames are disabled
	if( not PaladinBuffer.db.profile.frame.classes ) then
		return
	end	
	
	-- Flag it as we haven't updated
	for _, frame in pairs(classFrames) do frame.wasUpdated = nil end
	
	-- Now scan the group and create/update any frames if needed
	for _, unit in pairs(groupRoster) do
		local class, classToken = UnitClass(unit)
		if( class and classToken ) then
			local frame = classFrames[classToken]
			if( not frame ) then
				frame = self:CreateSingleFrame(self.parent)
				frame.filter = classToken
				
				local coords = CLASS_BUTTONS[classToken]
				frame.icon:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes")
				frame.icon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
				
				classFrames[classToken] = frame
			end
			
			-- No parent was set yet, because it's supposed to only show the class frames, soo set the first frame as the parent
			if( not self.parent ) then
				self:SetParentFrame(frame)
			end

			frame.wasUpdated = true
		end
	end
	
	-- The frame wasn't updated this go around, so we can hide it as the class is gone
	for _, frame in pairs(classFrames) do
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
	local columnStart, previousRow = self.parent, self.parent

	for classToken, frame in pairs(classFrames) do
		if( frame:IsVisible() and frame.filter ~= self.parent.filter ) then
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
	positionParent(self.parent)
	
end

function Buff:Reload()
	if( self.parent ) then
		-- Current parent is not the overall frame but it should be
		if( self.parent.filter ~= "ALL" and PaladinBuffer.db.profile.frame.enabled ) then
			self:ResetParentFrame(self.parent)
			self:SetParentFrame(self.frame)
		-- Current parent is the overall frame, but it shouldn't be
		elseif( self.parent.filter == "ALL" and not PaladinBuffer.db.profile.frame.enabled ) then
			self.parent = nil
			self.frame:Hide()
			
			self:UpdateClassFrames()
		end
		
		-- Update parent scaling annd reposition
		if( self.parent ) then
			self.parent:SetScale(PaladinBuffer.db.profile.frame.scale)
		end
		
		-- Update colors
		self.frame:SetBackdropBorderColor(PaladinBuffer.db.profile.frame.border.r, PaladinBuffer.db.profile.frame.border.g, PaladinBuffer.db.profile.frame.border.b, 1.0)
		
		for _, frame in pairs(classFrames) do
			frame:SetBackdropBorderColor(PaladinBuffer.db.profile.frame.border.r, PaladinBuffer.db.profile.frame.border.g, PaladinBuffer.db.profile.frame.border.b, 1.0)
		end
		
		self:PositionClassFrames()
	end
end

-- Format seconds into 50s/30m/etc
function Buff:FormatTime(text, timeLeft)
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
		text:SetFormattedText("%dh", hours)
	elseif( minutes > 0 ) then
		text:SetFormattedText("%dm", minutes)
	else
		text:SetFormattedText("%02ds", timeLeft > 0 and timeLeft or 0)
	end
end