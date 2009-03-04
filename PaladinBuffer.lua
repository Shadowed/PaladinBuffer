--[[ 
	Paladin Buffer, Mayen/Selari (Horde) from Illidan (US) PvP
]]

PaladinBuffer = LibStub("AceAddon-3.0"):NewAddon("PaladinBuffer", "AceEvent-3.0")

local L = PaladinBufferLocals
local playerName = UnitName("player")
local raidUnits, partyUnits, groupRoster, hasGroupRank, classList = {}, {}, {}, {}, {}
local improved = {[GetSpellInfo(20244)] = {"wisdom", "gwisdom"}, [GetSpellInfo(20042)] = {"might", "gmight"}}
local blessingTypes = {["gmight"] = "greater", ["gwisdom"] = "greater", ["gkings"] = "greater", ["gsanct"] = "greater", ["might"] = "single", ["wisdom"] = "single", ["kings"] = "single", ["sanct"] = "single"}
local blessings = {["might"] = GetSpellInfo(56520), ["gmight"] = GetSpellInfo(48934), ["wisdom"] = GetSpellInfo(56521), ["gwisdom"] = GetSpellInfo(48938), ["sanct"] = GetSpellInfo(20911), ["gsanct"] = GetSpellInfo(25899), ["kings"] = GetSpellInfo(20217), ["gkings"] = GetSpellInfo(25898)}

function PaladinBuffer:OnInitialize()
	self.defaults = {
		profile = {
			ppSupport = true,
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
	
	self:RegisterEvent("RAID_ROSTER_UPDATE")
	self:RegisterEvent("PLAYER_ENTERING_WORLD")
	self:RegisterEvent("LEARNED_SPELL_IN_TAB", "ScanSpells")
	
	-- Load class list
	classList["PET"] = true
	
	for classToken in pairs(RAID_CLASS_COLORS) do
		classList[classToken] = true
	end
	
	self.classList = classList
	
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
	return sender and hasGroupRank[sender] or false
end

function PaladinBuffer:GetBlessingType(blessing)
	return blessing and blessingTypes[blessing] or false
end

-- Assign a Paladin to a specific assignment
function PaladinBuffer:AssignBlessing(caster, spellToken, assignment)
	if( not self.db.profile.assignments[caster] ) then
		self.db.profile.assignments[caster] = {}
	end
	
	self.db.profile.assignments[caster][assignment] = spellToken
end

-- Set someone as having an improved blessing
function PaladinBuffer:SetBlessingsData(name, spellToken, rank)
	if( not self.db.profile.assignments[caster] ) then
		self.db.profile.assignments[caster] = {}
	end
	
	self.db.profile.blessings[caster][spellToken] = rank
end

-- Clear assignments to people having none
function PaladinBuffer:ClearAssignments()
	for name, data in pairs(self.db.profile.assignments) do
		for target, val in pairs(data) do
			data[target] = nil
		end
	end
end

-- Remove the table completely, remove all assignments
function PaladinBuffer:ResetAssignments()
	for name in pairs(self.db.profile.assignments) do
		self.db.profile.blessings[name] = nil
		self.db.profile.assignments[name] = nil
	end
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
		end
	end
	
	-- Now scan talents for improvements
	for tree=1, MAX_TALENT_TABS do
		for talent=1, GetNumTalents(tree) do
			local name, _, _, _, points = GetTalentInfo(tree, talent)
			if( improved[name] ) then
				for _, spellToken in pairs(improved[name]) do
					-- This means, Rank 5 Greater Blessing of Wisdom with 2/2 Improved Blessing of Wisdom is 5.2
					-- meaning we can do a direct compare out of this table to find who has the highest rank + improvements
					-- AND if we have to we can string split by the decimal and get the rank/improved! win/win
					self.db.profile.blessings[playerName][spellToken] = self.db.profile.blessings[playerName][spellToken] + (points / 10)
				end
			end
		end
	end
end

--[[
REQUEST
 Give me data on assignments
 
ASSIGN: <name 1>:<class 1>:<skill 1>;<name 2>:<class 2>:<skill 3>
 Assign someone to cast that <skill> on <class>

SINGLEASSIGN: <name 1>:<spell 1>:<target 1>;<name 2>:<spell 2>:<target 2>
 Assign a single Paladin to cast a <spell token> on the <target name>

MYASSIGN: <spell 1>,<rank 1>:<spell 2>,<rank 2>;<class 1>,<spell 1>:<target 1>,<spell 1>
 Sends data about the spells you have, if they are improved.
 What classes you are assigned to
 As well as the single blessings you were assigned
]]

-- Raid roster was updated, reload it
function PaladinBuffer:RAID_ROSTER_UPDATE()
	for k in pairs(groupRoster) do groupRoster[k] = nil end
	for k in pairs(hasGroupRank) do hasGroupRank[k] = nil end
	
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
