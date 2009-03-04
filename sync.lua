if( not PaladinBuffer ) then return end

local Sync = PaladinBuffer:NewModule("Sync", "AceEvent-3.0", "AceComm-3.0")
local classList
local playerName = UnitName("player")

function Sync:OnInitialize()
	self:RegisterEvent("CHAT_MSG_ADDON")
	self.RegisterComm(self, "PALB")

	classList = PaladinBuffer.classList
end

--[[
Paladin Buffer sync format

REQUEST
 Give me data on assignments
 
ASSIGN: <name 1>:<assignment 1>:<skill 1>;<name 2>:<assignment 2>:<skill 3>
 Assign someone to cast that <skill> on <assignment> which means it can either be a class or player

MYASSIGN: <spell 1>,<rank 1>:<spell 2>,<rank 2>;<class 1>,<spell 1>:<target 1>,<spell 1>
 Sends data about the spells you have, if they are improved.
 What classes you are assigned to
 As well as the single blessings you were assigned

I honestly can't see myself using these last two, but it's easier to remove comm code than add it.

SYMREQUEST
 Request total number of Symbols
 
SYMBOLS: #
 Total number of Symbols you have
  
CLEAR
 Clears the assignments
]]

-- SENDING SYNC DATA
function Sync:SendPersonalAssignment()
	-- Compile the list of what we have trained/talented
	local talentList
	for spellToken, rank in pairs(PaladinBuffer.db.profile.blessings[playerName]) do
		if( talentList ) then
			talentList = string.format("%s:%s,%s", talentList, spellToken, rank)
		else
			talentList = string.format("%s,%s", spellToken, rank)
		end
	end
	
	-- Compile a list of our assignments (If any)
	local assignList
	for assignment, spellToken in pairs(PaladinBuffer.db.profile.assignments[playerName]) do
		if( assignList ) then
			assignList = string.format("%s:%s,%s", assignList, assignment, spellToken)
		else
			assignList = string.format("%s,%s", assignment, spellToken)
		end
	end
	
	-- Send it off
	self:SendMessage(string.format("%s;%s", talentList or "", assignList or ""))
end

-- PARSING SYNC DATA
function Sync:ParseTalents(sender, ...)
	for i=1, select("#", ...) do
		local spell, rank = string.split(",", (select(i, ...)))
		rank = tonumber(rank)

		if( spell and rank and PaladinBuffer:GetBlessingType(spell) ) then
			PaladinBuffer:SetBlessingsData(sender, spell, rank)	
		end
	end
end

function Sync:ParseAssignments(sender, ...)
	for i=1, select("#", ...) do
		local assignment, spell = string.split(",", (select(i, ...)))
		if( assignment and spell and PaladinBuffer:GetBlessingType(spell) ) then
			PaladinBuffer:AssignBlessing(sender, spell, assignment)
		end
	end
end

-- RECEIVED SYNC DATA
function Sync:OnCommReceived(prefix, msg, type, sender)
	local cmd, arg = string.match(msg, "([a-zA-Z+]): (.+)")
	if( not cmd or not arg ) then
		cmd = msg
	elseif( arg ) then
		arg = string.trim(arg)
	end
	
	-- Request our assignment data
	if( cmd == "REQUEST" and PaladinBuffer:HasPermission(sender) ) then
		PaladinBuffer:SendPersonalAssignment()
	
	-- Assignment for people
	elseif( cmd == "ASSIGN" and arg --[[and playerName ~= sender]] and PaladinBuffer:HasPermission(sender) ) then
		self:ParseAssignments(sender, string.split(":", arg))
		
	-- We got this persons assignments
	elseif( cmd == "MYASSIGN" and arg --[[and playerName ~= sender]] ) then
		local talents, assignments = string.split(";", arg)
		if( talents and assignments ) then
			self:ParseTalents(sender, string.split(":", talents))
			self:ParseAssignments(sender, string.format(":", assignments))
		end
		
	-- Requesting symbol totals
	elseif( cmd == "SYMREQUEST" and arg and PaladinBuffer:HasPermission(sender) ) then
		self:SendMessage(string.format("SYMBOLS: %d", GetItemCount("item:21177")))
	
	-- Clear assignments from people
	elseif( cmd == "CLEAR" and PaladinBuffer:HasPermission(sender) ) then
		PaladinBuffer:ClearAssignments()
		
	-- Symbol total received
	--elseif( cmd == "SYMBOLS" ) then
	end
end

function Sync:SendMessage(msg)
	self:SendCommMessage(msg, "RAID")
end

--[[
Pally Power sync format

REQ
 Give me data about your assignments/free assignments/what skills I have/etc

ASSIGN <name> <class #> <skill #>
 Assign a specific person to a class as well as the spell they are assigned

NASSIGN <target> <class> <casterName> <skill ID>
 Assign a specific person to a player for casting a single buff

MASSIGN <name> <skill #>
 Mass assigns the player to use that skill on everyone

SYMCOUNT #
 Total amount of symbols they have (Stupid)
 
CLEAR
 Reset assignments

FREEASSIGN YES/NO
 Allow assignments by people who aren't assist or leader

SELF <spell data>@<assignments>
SELF <wisdom rank><improved wisdom><might rank><improved might><king points><improved kings><sanct points><improved sanc???>@<class #><skill #>
SELF 525214nn@12 = Wisdom Rank 5 + 2 points in imp, Might Rank 5 + 2 points in imp, Kings + 4 points in imp, no Sanct / Giving Warriors Might

Usage of "n" is basically as a no/nil/etc, nothings supposed to be there.
Order of the spell data is Wisdom, Might,  Kings, Sanc
]]

-- Pally Power -> Paladin Buffer conversions
local singleConversions = {[1] = "wisdom", [2] = "might", [3] = "kings", [4] = "sanct", ["wisdom"] = 1, ["might"] = 2, ["kings"] = 3, ["sanct"] = 4}
local greaterConversions = {[1] = "gwisdom", [2] = "gmight", [3] = "gkings", [4] = "gsanct", ["gwisdom"] = 1, ["gmight"] = 2, ["gkings"] = 3, ["gsanct"] = 4}
local classConversions = {[1] = "WARRIOR", [2] = "ROGUE", [3] = "PRIEST", [4] = "DRUID", [5] = "PALADIN", [6] = "HUNTER", [7] = "MAGE", [8] = "WARLOCK", [9] = "SHAMAN", [10] = "DEATHKNIGHT", [11] = "PET", ["WARRIOR"] = 1, ["ROGUE"] = 2, ["PRIEST"] = 3, ["DRUID"] = 4, ["PALADIN"] = 5, ["HUNTER"] = 6, ["MAGE"] = 7, ["WARLOCK"] = 8, ["SHAMAN"] = 9, ["DEATHKNIGHT"] = 10, ["PET"] = 11}
local singleMaxRanks = {["might"] = 10, ["wisdom"] = 9, ["kings"] = 1, ["sanct"] = 1}

function Sync:SendTerribleFormat()
	-- Compile the list of what we have trained/talented
	local spellList = ""
	for id, spellToken in pairs(spellIDToToken) do
		if( PaladinBuffer.db.profile.blessings[playerName] ) then
			local rank, points = string.split(".", PaladinBuffer.db.profile.blessings[playerName])
			points = points or "n"
			
			spellList = string.format("%s%s%s", rank, points == "" and "n" or points)
		else
			spellList = string.format("%snn", spellList)
		end
	end
	
	-- Compile a list of our assignments (If any)
	local assignList = ""
	for assignment, spellToken in pairs(PaladinBuffer.db.profile.assignments[playerName]) do
		if( classConversions[assignment] ) then
			assignList = string.format("%s%s%s", assignList, classConversions[assignment], greaterConversions[spellToken])
		end
	end
	
	-- Send it off
	SendAddonMessage("PLPWR", string.format("%s@%s", spellList, assignList), "RAID")
end

function Sync:ParseBlessingData(singleType, greaterType, rank, improved)
	if( not rank ) then
		return
	end
	
	improved = improved or 0
	
	-- We have to fake the rank for singles, as PP only passes the highest
	local fraction = improved / 10
	PaladinBuffer:SetBlessingData(sender, singleType, singleMaxRanks[singletype] + fraction)
	PaladinBuffer:SetBlessingData(sender, greaterType, rank + fraction)
end

function Sync:CHAT_MSG_ADDON(event, prefix, msg, type, sender)
	if( not PaladinBuffer.db.profile.ppSupport or prefix ~= "PLPWR" or type ~= "PARTY" or type ~= "RAID" ) then
		return
	end
	
	local cmd, arg = string.match(msg, "([a-zA-Z+]) (.+)")
	if( not cmd or not arg ) then
		cmd = msg
	elseif( arg ) then
		arg = string.trim(arg)
	end
	
	-- Request our data
	if( cmd == "REQ" and arg and PaladinBuffer:HasPermission(sender) ) then
		self:SendTerribleFormat()
		
	-- Someone was assigned a specific spell to a specific class
	elseif( cmd == "ASSIGN" and arg --[[and playerName ~= sender]] and PaladinBuffer:HasPermission(sender) ) then
		local name, classID, spellID = string.split(" ", arg)
		classID = tonumber(string.trim(classID))
		spellID = tonumber(string.trim(spellID)) or ""
		
		if( name and classID and spellID ) then
			PaladinBuffer:AssignBlessing(name, greaterConversions[spellID], classConversions[classID])	
		end
		
	-- Someone was assigned to a single blessing
	elseif( cmd == "NASSIGN" and arg --[[and playerName ~= sender]] and PaladinBuffer:HasPermission(sender) ) then
		local target, _, casterName, spellID = string.split(" ", arg)
		spellID = tonumber(string.trim(spellID)) or ""
		
		if( target and casterName and spellID ) then
			PaladinBuffer:AssignBlessing(casterName, singleConversions[spellID], target)
		end
		
	-- Someone was assigned to the same blessing on every class
	elseif( cmd == "MASSIGN" and arg --[[and playerName ~= sender]] and PaladinBuffer:HasPermission(sender) ) then
		local name, spellID = string.split(" ", arg)
		spellID = tonumber(string.trim(spellID)) or ""
		
		if( name ) then
			for classToken in pairs(classList) do
				PaladinBuffer:AssignBlessing(name, greaterConversions[spellID], classToken)
			end
		end
	
	-- We got data on someones assignments
	elseif( cmd == "SELF" and arg and PaladinBuffer:HasPermission(sender) ) then
		local talents, assignments = string.split("@", arg)
		if( talents and assignments ) then
			-- Parse talents/etc, we don't do the below parsing type because it's an ordered list
			talents = string.trim(talents)
			
			local wisdomRank, wisdomImproved, mightRank, mightImproved, kingsRank, kingsImproved, sanctRank, sanctImproved = string.match(talents, "([0-9])([0-9])([0-9])([0-9])([0-9])([0-9])([0-9])([0-9])")
			self:ParseBlessingData("wisdom", "gwisdom", tonumber(wisdomRank), tonumber(wisdomImproved))
			self:ParseBlessingData("might", "gmight", tonumber(mightRank), tonumber(mightImproved))
			self:ParseBlessingData("kings", "gkings", tonumber(kingsRank), tonumber(kingsImproved))
			self:ParseBlessingData("sanct", "gsanct", tonumber(sanctRank), tonumber(sanctImproved))
			
			-- Parse assignments
			assignments = string.trim(assignments)
			
			local offset = 0
			local length = string.len(assignments)
			while( offset <= length ) do
				local classID = string.sub(talents, offset, offset)
				local spellID = string.sub(talents, offset + 1, offset + 1)
				
				if( classID and spellID ) then
					classID = tonumber(classID)
					spellID = tonumber(spellID) or ""
					
					if( classID and spellID ) then
						PaladinBuffer:AssignBlessing(name, greaterConversions[spellId], classConversions[classID])
					end
				end
				
				offset = offset + 2
			end
			
		end
	
	-- Should I support this, I guess so?
	elseif( cmd == "FREEASSIGN" ) then
	
	-- Clear requested data
	elseif( cmd == "CLEAR" and PaladinBuffer:HasPermission(sender) ) then
		PaladinBuffer:ClearAssignments()
	end
end