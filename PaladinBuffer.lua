--[[ 
	Paladin Buffer, Mayen/Selari (Horde) from Illidan (US) PvP
]]

PaladinBuffer = LibStub("AceAddon-3.0"):NewAddon("PaladinBuffer", "AceEvent-3.0")

local L = PaladinBufferLocals
local playerName = UnitName("player")
local raidUnits, partyUnits, groupRoster, hasGroupRank, classList, talentData, freeAssign = {}, {}, {}, {}, {}, {}, {}
local improved = {[GetSpellInfo(20244)] = {"wisdom", "gwisdom"}, [GetSpellInfo(20042)] = {"might", "gmight"}}
local blessingTypes = {["gmight"] = "greater", ["gwisdom"] = "greater", ["gkings"] = "greater", ["gsanct"] = "greater", ["might"] = "single", ["wisdom"] = "single", ["kings"] = "single", ["sanct"] = "single"}
local blessings = {["might"] = GetSpellInfo(56520), ["gmight"] = GetSpellInfo(48934), ["wisdom"] = GetSpellInfo(56521), ["gwisdom"] = GetSpellInfo(48938), ["sanct"] = GetSpellInfo(20911), ["gsanct"] = GetSpellInfo(25899), ["kings"] = GetSpellInfo(20217), ["gkings"] = GetSpellInfo(25898)}
local instanceType

function PaladinBuffer:OnInitialize()
	self.defaults = {
		profile = {
			ppSupport = true,
			requireLeader = true,
			greaterbinding = "CTRL-1",
			singleBinding = "CTRL-2",
			scale = 1.0,
			rangeThreshold = 1.0,
			singleThreshold = 5,
			greaterThreshold = 15,
			offline = false,
			blessings = {},
			assignments = {},
			inside = {["raid"] = true, ["party"] = true, ["none"] = true},
			frame = {
				enabled = true,
				classes = true,
				hideInCombat = true,
				locked = false,
				growUp = false,
				scale = 1.0,
				columns = 1,
			},
		},
	}
	
	-- Initialize the DB
	self.db = LibStub:GetLibrary("AceDB-3.0"):New("PaladinBufferDB", self.defaults)
	self.db.RegisterCallback(self, "OnProfileChanged", "Reload")
	self.db.RegisterCallback(self, "OnProfileCopied", "Reload")
	self.db.RegisterCallback(self, "OnProfileReset", "Reload")

	self.revision = tonumber(string.match("$Revision$", "(%d+)") or 1)

	-- If they aren't a Paladin disable this mod
	if( select(2, UnitClass("player")) ~= "PALADIN" ) then
		PaladinBuffer.disabled = true
	end
	
	self:RegisterEvent("RAID_ROSTER_UPDATE", "ScanGroup")
	self:RegisterEvent("PARTY_MEMBERS_CHANGED", "ScanGroup")
	self:RegisterEvent("PLAYER_ENTERING_WORLD")
	self:RegisterEvent("LEARNED_SPELL_IN_TAB", "ScanSpells")
	self:RegisterEvent("ZONE_CHANGED_NEW_AREA")
		
	-- Defaults
	local setup
	if( not self.disabled and not self.db.profile.assignments[playerName] ) then
		self.db.profile.assignments[playerName] = {}
		self.db.profile.blessings[playerName] = {}
		setup = true
	end
	
	-- Load class list
	for classToken in pairs(RAID_CLASS_COLORS) do
		classList[classToken] = true

		-- Player should ALWAYS have a default assignment set
		if( setup ) then
			self.db.profile.assignments[playerName][classToken] = "none"
		end
	end
	
	-- So modules can access this data
	self.classList = classList
	self.blessings = blessings
	self.blessingTypes = blessingTypes
	self.improved = improved
	self.talentData = talentData
	self.raidUnits = raidUnits
	self.partyUnits = partyUnits
	self.groupRoster = groupRoster
	self.freeAssign = freeAssign
	
	
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
function PaladinBuffer:HasPermission(name)
	if( not PaladinBuffer.db.profile.requireLeader ) then
		return true
	end
	
	return name and hasGroupRank[name] or false
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

-- Initialize the basic player data we need for them
local function setupPlayerData(caster)
	local self = PaladinBuffer
	local fire
	if( not self.db.profile.assignments[caster] ) then
		self.db.profile.assignments[caster] = {}

		for classToken in pairs(classList) do
			self.db.profile.assignments[caster][classToken] = "none"
		end

		fire = true
	end

	if( not self.db.profile.blessings[caster] ) then
		self.db.profile.blessings[caster] = {}
		fire = true
	end


	self:SendMessage("PB_DISCOVERED_PLAYER", caster)
end

-- Assign a Paladin to a specific assignment
function PaladinBuffer:AssignBlessing(caster, spellToken, assignment)
	setupPlayerData(caster)
	
	-- Check if the blessing was already assigned, if so cancel it for the other person
	if( spellToken ~= "none" and not classList[assignment] ) then
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
	setupPlayerData(caster)
	
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

-- Remove a single persons assignment
function PaladinBuffer:RemovePlayerData(caster)
	self.db.profile.assignments[caster] = nil
	self.db.profile.blessings[caster] = nil
	self:SendMessage("PB_RESET_ASSIGNMENTS", caster)
end

-- Remove the table completely, remove all assignments
function PaladinBuffer:ResetAllAssignments()
	for name, assignments in pairs(self.db.profile.assignments) do
		if( name ~= playerName ) then
			self.db.profile.assignments[name] = nil
			self.db.profile.blessings[name] = nil
		else
			for target in pairs(assignments) do
				if( classList[target] ) then
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
	if( PaladinBuffer.disabled ) then
		return
	end
	
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
			self.db.profile.blessings[playerName][spellToken] = nil
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
function PaladinBuffer:ScanGroup()
	-- Reset data from previous scan
	for k in pairs(groupRoster) do groupRoster[k] = nil end
	for k in pairs(hasGroupRank) do hasGroupRank[k] = nil end

	-- Left raid :(
	if( GetNumRaidMembers() == 0 and GetNumPartyMembers() == 0 ) then
		self:ResetAllAssignments()
		self:SendMessage("PB_ROSTER_UPDATED")
		return
	end
	
	-- Scan raid
	for i=1, GetNumRaidMembers() do
		local name = UnitName(raidUnits[i])
		if( select(2, GetRaidRosterInfo(i)) > 0 ) then
			hasGroupRank[name] = true
		end
		
		groupRoster[name] = raidUnits[i]
	end

	-- Not in a raid, so scan party
	if( GetNumRaidMembers() == 0 ) then
		groupRoster[playerName] = "player"
		hasGroupRank[playerName] = true
		
		for i=1, GetNumPartyMembers() do
			local name = UnitName(partyUnits[i])
			hasGroupRank[name] = true
			groupRoster[name] = partyUnits[i]
		end
	end
	
	-- Remove data if the person left the raid
	for name in pairs(PaladinBuffer.db.profile.blessings) do
		if( not groupRoster[name] and name ~= playerName ) then
			PaladinBuffer.db.profile.blessings[name] = nil
			PaladinBuffer.db.profile.assignments[name] = nil

			self:SendMessage("PB_RESET_ASSIGNMENTS", name)
		end
	end
	
	-- Trigger that the roster list was updated
	self:SendMessage("PB_ROSTER_UPDATED")
end

-- Entering the world for the first time, might need to do some setup
function PaladinBuffer:PLAYER_ENTERING_WORLD()
	self:UnregisterEvent("PLAYER_ENTERING_WORLD")

	if( GetNumRaidMembers() > 0 or GetNumPartyMembers() > 0 ) then
		self:ScanGroup()
	end
	
	self:ScanSpells()
	self:ZONE_CHANGED_NEW_AREA()
	self:UpdateKeyBindings()
end

function PaladinBuffer:ZONE_CHANGED_NEW_AREA()
	local type = select(2, IsInInstance())
	if( type ~= instanceType ) then
		if( self.db.profile.inside[type] ) then
			self.isEnabled = true
			for _, module in pairs(self.modules) do
				if( module.Enable ) then
					module:Enable()
				end
			end
		else
			self.isEnabled = nil
			for _, module in pairs(self.modules) do
				if( module.Disable ) then
					module:Disable()
				end
			end
		end
	end
	
	instanceType = type
end

-- We had a key binding update queued
function PaladinBuffer:PLAYER_REGEN_ENABLED()
	self:UpdateKeyBindings()
	self:UnregisterEvent("PLAYER_REGEN_ENABLED")
end

-- Update key bindings for the auto buffing
function PaladinBuffer:UpdateKeyBindings()
	if( InCombatLockdown() ) then
		self:RegisterEvent("PLAYER_REGEN_ENABLED")
		return
	end
	
	-- Greater smart buffing
	if( not self.smartGreaterButton ) then
		self.smartGreaterButton = CreateFrame("Button", "PBSmartGreaterButton", nil, "SecureActionButtonTemplate")
		self.smartGreaterButton:SetScript("PreClick", function(self)
			if( not InCombatLockdown() and PaladinBuffer.isEnabled ) then
				local type, unit, spell = PaladinBuffer.modules.BuffGUI:AutoBuffLowestGreater("ALL")
				self:SetAttribute("type", type)
				self:SetAttribute("unit", unit)
				self:SetAttribute("spell", spell)
			end
		end)
	end
	
	if( self.db.profile.greaterBinding and self.db.profile.greaterBinding ~= "" ) then
		SetOverrideBindingClick(self.smartGreaterButton, false, self.db.profile.greaterBinding, self.smartGreaterButton:GetName())	
	else
		ClearOverrideBindings(self.smartGreaterButton)
	end
	
	-- Single smart buffing
	if( not self.smartSingleButton ) then
		self.smartSingleButton = CreateFrame("Button", "PBSmartSingleButton", nil, "SecureActionButtonTemplate")
		self.smartSingleButton:SetScript("PreClick", function(self)
			if( not InCombatLockdown() and PaladinBuffer.isEnabled ) then
				local type, unit, spell = PaladinBuffer.modules.BuffGUI:AutoBuffLowestSingle("ALL")
				self:SetAttribute("type", type)
				self:SetAttribute("unit", unit)
				self:SetAttribute("spell", spell)
			end
		end)
	end
	
	if( self.db.profile.singleBinding and self.db.profile.singleBinding ~= "" ) then
		SetOverrideBindingClick(self.smartSingleButton, false, self.db.profile.singleBinding, self.smartSingleButton:GetName())	
	else
		ClearOverrideBindings(self.smartSingleButton)
	end
end

-- Random misc
function PaladinBuffer:Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99Paladin Buffer|r: " .. msg)
end

function PaladinBuffer:Echo(msg)
	DEFAULT_CHAT_FRAME:AddMessage(msg)
end

local sentRequirements
function PaladinBuffer:Reload()
	instanceType = nil
	self:ZONE_CHANGED_NEW_AREA()	
	self:UpdateKeyBindings()
	
	-- No sense in sending our leadership requirements if they didn't change
	if( sentRequirements ~= PaladinBuffer.db.profile.requireLeader ) then
		self.modules.Sync:SendLeaderRequirements()
		sentRequires = PaladinBuffer.db.profile.requireLeader
	end

	-- Reload modules if needed
	for _, module in pairs(self.modules) do
		if( module.Reload ) then
			module:Reload()
		end
	end
end
