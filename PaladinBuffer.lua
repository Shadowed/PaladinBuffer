--[[ 
	Paladin Buffer, Mayen/Selari (Horde) from Illidan (US) PvP
]]

PaladinBuffer = LibStub("AceAddon-3.0"):NewAddon("PaladinBuffer", "AceEvent-3.0")

local L = PaladinBufferLocals
local playerName = UnitName("player")
local raidUnits, partyUnits, groupRoster, hasGroupRank, classList, talentData = {}, {}, {}, {}, {}, {}
local improved = {[GetSpellInfo(20244)] = {"wisdom", "gwisdom"}, [GetSpellInfo(20042)] = {"might", "gmight"}}
local blessingTypes = {["gmight"] = "greater", ["gwisdom"] = "greater", ["gkings"] = "greater", ["gsanct"] = "greater", ["might"] = "single", ["wisdom"] = "single", ["kings"] = "single", ["sanct"] = "single"}
local blessings = {["might"] = GetSpellInfo(56520), ["gmight"] = GetSpellInfo(48934), ["wisdom"] = GetSpellInfo(56521), ["gwisdom"] = GetSpellInfo(48938), ["sanct"] = GetSpellInfo(20911), ["gsanct"] = GetSpellInfo(25899), ["kings"] = GetSpellInfo(20217), ["gkings"] = GetSpellInfo(25898)}

function PaladinBuffer:OnInitialize()
	self.defaults = {
		profile = {
			ppSupport = true,
			scale = 1.0,
			blessings = {[playerName] = {}},
			assignments = {[playerName] = {}},
		},
	}
	
	-- Initialize the DB
	self.db = LibStub:GetLibrary("AceDB-3.0"):New("PaladinBufferDB", self.defaults)
	--self.db.RegisterCallback(self, "OnProfileChanged", "Reload")
	--self.db.RegisterCallback(self, "OnProfileCopied", "Reload")
	--self.db.RegisterCallback(self, "OnProfileReset", "Reload")

	self.revision = tonumber(string.match("$Revision$", "(%d+)") or 1)

	-- If they aren't a Paladin disable this mod
	if( select(2, UnitClass("player")) ~= "PALADIN" ) then
		PaladinBuffer.disabled = true
		if( not PaladinBuffer.db.profile.warned ) then
			PaladinBuffer.db.profile.warned = true
			PaladinBuffer:Print(L["Warning! Paladin Buffer has been disabled for this character as you are not a Paladin."])
		end
		return
	end
	
	self:RegisterEvent("RAID_ROSTER_UPDATE")
	self:RegisterEvent("PLAYER_ENTERING_WORLD")
	self:RegisterEvent("LEARNED_SPELL_IN_TAB", "ScanSpells")
	
	-- Load class list
	for classToken in pairs(RAID_CLASS_COLORS) do
		classList[classToken] = true

		-- Player should ALWAYS have a default assignment set
		self.defaults.profile.assignments[playerName][classToken] = "none"
	end
	
	self.classList = classList
	self.blessingTypes = blessingTypes
	self.improved = improved
	self.talentData = talentData
	self.raidUnits = raidUnits
	self.partyUnits = partyUnits
	
	-- Save a list of unitids
	for i=1, MAX_RAID_MEMBERS do
		raidUnits[i] = "raid" .. i
	end
	
	for i=1, MAX_PARTY_MEMBERS do
		partyUnits[i] = "party" .. i
	end
	
	-- Kings is still talented, so add the talent name as an improvement
	if( select(4, GetBuildInfo()) <= 30000 ) then
		improved[GetSpellInfo(59295)] = {"kings", "gkings"}
	end
end

-- Do they have permission to assign us something?
function PaladinBuffer:HasPermission(sender)
	-- Not sure how comfortable I am with anyone in the group to be able to do this, I'll uncomment the persmissions line if I change my mind
	--return sender and hasGroupRank[sender] or false
	return true
end

-- Reset the players blessing assignments
function PaladinBuffer:ClearAssignments(caster)
	if( self.db.profile.assignments[caster] ) then
		for assignment in pairs(self.db.profile.assignments[caster]) do
			if( classList[assignment] ) then
				self.db.profile.assignments[caster][assignment] = "none"
			else
				self.db.profile.assignments[caster][assignment] = nil
			end
		end
		
		self:SendMessage("PB_CLEARED_ASSIGNMENTS", caster)
	end
end

-- Assign a Paladin to a specific assignment
function PaladinBuffer:AssignBlessing(caster, spellToken, assignment)
	if( not self.db.profile.assignments[caster] ) then
		self.db.profile.assignments[caster] = {}

		for classToken in pairs(classList) do
			self.db.profile.assignments[caster][classToken] = "none"
		end
		
		self:SendMessage("PB_DISCOVERED_PLAYER", caster)
	end

	-- Check if the blessing was already assigned, if so cancel it for the other person
	if( spellToken ~= "none" ) then
		for name, assignments in pairs(PaladinBuffer.db.profile.assignments) do
			if( name ~= caster and assignments[assignment] == spellToken ) then
				assignments[assignment] = "none"
				self:SendMessage("PB_ASSIGNED_BLESSINGS", name, assignment, "none")
			end
		end
	end
	
	self.db.profile.assignments[caster][assignment] = spellToken
	self:SendMessage("PB_ASSIGNED_BLESSINGS", caster, assignment, spellToken)
end

-- Reset the talent data we have for them
function PaladinBuffer:ResetBlessingData(caster)
	if( self.db.profile.blessings[caster] ) then
		for k in pairs(self.db.profile.blessings[caster]) do
			self.db.profile.blessings[caster][k] = nil
		end
		
		self:SendMessage("PB_RESET_SPELLS", caster)
	end
end

-- Set someone as having an improved blessing
function PaladinBuffer:SetBlessingData(caster, spellToken, rank)
	if( not self.db.profile.blessings[caster] ) then
		self.db.profile.blessings[caster] = {}
	end
	
	self.db.profile.blessings[caster][spellToken] = rank
	self:SendMessage("PB_SPELL_DATA", caster, spellToken, rank)
end

-- Clear assignments to people having none
function PaladinBuffer:ClearAllAssignments()
	for name, data in pairs(self.db.profile.assignments) do
		for target, val in pairs(data) do
			if( classList[target] ) then
				data[target] = "none"
			else
				data[target] = nil
			end
		end
		
		self:SendMessage("PB_CLEARED_ASSIGNMENTS")
	end
end

-- Remove the table completely, remove all assignments
function PaladinBuffer:ResetAllAssignments()
	for name, assignments in pairs(self.db.profile.assignments) do
		if( name ~= playerName ) then
			self.db.profile.assignments[name] = nil
			self.db.profile.blessings[name] = nil
		else
			for target in pairs(assignments) do
				if( classList[data] ) then
					assignments[target] = "none"
				else
					assignments[target] = nil
				end
			end
		end
	end

	self:SendMessage("PB_RESET_ASSIGNMENTS")
end

-- Scan what spells the player has
function PaladinBuffer:ScanSpells()
	-- Reset what we have
	for token in pairs(self.db.profile.blessings[playerName]) do
		self.db.profile.blessings[playerName][token] = nil
	end

	-- Figure out what we know
	for spellToken, spellName in pairs(blessings) do
		local rank = select(2, GetSpellInfo(spellName))
		if( rank ) then
			rank = rank == "" and 1 or tonumber(string.match(rank, L["Rank ([0-9]+)"]))
			self.db.profile.blessings[playerName][spellToken] = rank
		else
			self.db.profile.blessings[playerName][spellToken] = "none"
		end
	end
	
	-- Now scan talents for improvements
	for tree=1, MAX_TALENT_TABS do
		for talent=1, GetNumTalents(tree) do
			local name, _, _, _, points, maxPoints = GetTalentInfo(tree, talent)
			if( improved[name] ) then
				for _, spellToken in pairs(improved[name]) do
					talentData[spellToken] = maxPoints
					
					-- This means, Rank 5 Greater Blessing of Wisdom with 2/2 Improved Blessing of Wisdom is 5.2
					-- meaning we can do a direct compare out of this table to find who has the highest rank + improvements
					-- AND if we have to we can string split by the decimal and get the rank/improved! win/win
					if( type(self.db.profile.blessings[playerName][spellToken]) == "number" ) then
						self.db.profile.blessings[playerName][spellToken] = self.db.profile.blessings[playerName][spellToken] + (points / 10)
					end
				end
			end
		end
	end
		
	self:SendMessage("PB_SPELLS_SCANNED")
end

-- Raid roster was updated, reload it
function PaladinBuffer:RAID_ROSTER_UPDATE()
	for k in pairs(groupRoster) do groupRoster[k] = nil end
	for k in pairs(hasGroupRank) do hasGroupRank[k] = nil end

	if( GetNumRaidMembers() == 0 ) then
		PaladinBuffer:ResetAllAssignments()
		return
	end
	
	for i=1, GetNumRaidMembers() do
		local name = UnitName(raidUnits[i])
		if( select(2, GetRaidRosterInfo(i)) ) then
			hasGroupRank[name] = true
		end
		
		groupRoster[name] = raidUnits[i]
	end

	for i=1, GetNumPartyMembers() do
		local name = UnitName(partyUnits[i])
		if( UnitIsPartyLeader(partyUnits[i]) ) then
			hasGroupRank[name] = true
		end
	
		groupRoster[name] = partyUnits[i]
	end
end

-- Entering the world for the first time, might need to do some setup
function PaladinBuffer:PLAYER_ENTERING_WORLD()
	if( GetNumRaidMembers() > 0 ) then
		self:RAID_ROSTER_UPDATE()
	end
	
	self:ScanSpells()
	self:UnregisterEvent("PLAYER_ENTERING_WORLD")
end

-- Random misc
function PaladinBuffer:Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99Paladin Buffer|r: " .. msg)
end

function PaladinBuffer:Reload()
end
