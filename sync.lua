if( not PaladinBuffer ) then return end

local Sync = PaladinBuffer:NewModule("Sync", "AceEvent-3.0", "AceComm-3.0")
local classList, timerFrame, freeAssign
local supportsPP, requestThrottle = {}, {}
local playerName = UnitName("player")
local THROTTLE_TIME = 5

function Sync:OnEnable()
	self:RegisterEvent("CHAT_MSG_ADDON")
	self.RegisterComm(self, "PALB")

	classList = PaladinBuffer.classList
	freeAssign = PaladinBuffer.freeAssign
end

function Sync:OnDisable()
	self:UnregisterEvent("CHAT_MSG_ADDON")
	self:UnregisterAllComm()
end

function Sync:SendAssignmentReset()
	self:SendAddonMessage("CLEAR")
	
	if( PaladinBuffer.db.profile.ppSupport ) then
		self:SendAddonMessage("CLEAR", "PLPWR")
	end
end

function Sync:RequestData()
	-- Request data from PaladinBuffer users
	self:SendAddonMessage("REQUEST: " .. tostring(PaladinBuffer.db.profile.ppSupport))
	
	-- Request data from Pally Power users
	-- will do a small 0.5 delay so that PB users will see that they should ignore any syncs that are sent as compats
	if( PaladinBuffer.db.profile.ppSupport ) then
		local timeElapsed = 0
		if( not timerFrame ) then
			timerFrame = CreateFrame("Frame")
			timerFrame:SetScript("OnUpdate", function(self, elapsed)
				timeElapsed = timeElapsed - elapsed
				
				if( timeElapsed <= 0 ) then
					Sync:SendAddonMessage("REQ", "PLPWR")
					self:Hide()
				end
			end)
		end
		
		timeElapsed = 0.5
		timerFrame:Show()
	end
end

-- SENDING SYNC DATA
function Sync:SendAssignments()
	-- RASSIGN: Selari~WARRIOR,gmight:PRIEST,gkings:Distomia,wisdom;Distomia~WARRIOR,gkings:PRIEST,gwisdom	local assignText
	local assignText
	for name, assignments in pairs(PaladinBuffer.db.profile.assignments) do
		local text
		for target, spellToken in pairs(assignments) do
			if( text ) then	
				text = string.format("%s:%s,%s", text, target, spellToken)
			else
				text = string.format("%s,%s", target, spellToken)
			end
		end
		
		if( text ) then
			if( assignText ) then
				assignText = string.format("%s;%s~%s", assignText, name, text)
			else
				assignText = string.format("%s~%s", name, text)
			end
		end
	end
	
	-- Off we go!
	if( assignText ) then
		self:SendAddonMessage(string.format("RASSIGN: %s", assignText))
	end
	
	-- Send assignments out in a PP format
	if( PaladinBuffer.db.profile.ppSupport ) then
		self:SendPPAssignments()
	end
end

function Sync:SendPersonalAssignment()
	if( PaladinBuffer.disabled ) then
		return
	end
	
	if( not PaladinBuffer.foundSpells ) then
		PaladinBuffer:ScanSpells()
	end
	
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
	self:SendAddonMessage(string.format("MYDATA: %s;%s;%s", (talentList or ""), (assignList or ""), PaladinBuffer.db.profile.requireLeader and "true" or "false"))
end

function Sync:SendBlessingData()
	if( PaladinBuffer.disabled ) then
		return
	end
	
	if( not PaladinBuffer.foundSpells ) then
		PaladinBuffer:ScanSpells()
	end
	
	-- Compile the list of what we have trained/talented
	local talentList
	for spellToken, rank in pairs(PaladinBuffer.db.profile.blessings[playerName]) do
		if( talentList ) then
			talentList = string.format("%s:%s,%s", talentList, spellToken, rank)
		else
			talentList = string.format("%s,%s", spellToken, rank)
		end
	end
		
	-- Send it off
	self:SendAddonMessage(string.format("BLESSINGS: %s", talentList))
end

function Sync:SendLeaderRequirements()
	self:SendAddonMessage(string.format("FREEASSIGN %s", PaladinBuffer.db.profile.requireLeader and "NO" or "YES"), "PLPWR")
	self:SendAddonMessage(string.format("LEADER: %s", PaladinBuffer.db.profile.requireLeader and "true" or "false"))
end

-- PARSING SYNC DATA
function Sync:ParseTalents(sender, ...)
	for i=1, select("#", ...) do
		local spell, rank = string.split(",", (select(i, ...)))
		rank = tonumber(rank)
		
		if( spell and rank and PaladinBuffer.blessingTypes[spell] ) then
			PaladinBuffer:SetBlessingData(sender, spell, rank)	
		end
	end
end

function Sync:ParseAssignments(sender, ...)
	for i=1, select("#", ...) do
		local assignment, spell = string.split(",", (select(i, ...)))
		if( assignment and spell ) then
			-- Nones are just nils now
			if( spell == "none" ) then
				spell = nil
			end
			
			-- Validate it, don't let a player get assigned a greater blessing and don't let a class be assigned a single blessing
			if( not spell or ( classList[assignment] and PaladinBuffer.blessingTypes[spell] == "greater" ) or ( not classList[assignment] and PaladinBuffer.blessingTypes[spell] == "single" ) ) then
				PaladinBuffer:AssignBlessing(sender, spell, assignment)
			end
		end
	end
end

-- RASSIGN: Selari~WARRIOR,gmight:PRIEST,gkings:Distomia,wisdom;Distomia~WARRIOR,gkings:PRIEST,gwisdom
function Sync:ParsePlayerAssignments(reset, ...)
	for i=1, select("#", ...) do
		local name, assignments = string.split("~", (select(i, ...)))
		if( name and assignments ) then
			if( reset ) then
				PaladinBuffer:ClearAssignments(name)
			end
			
			self:ParseAssignments(name, string.split(":", assignments))
		end
	end
end

-- RECEIVED SYNC DATA
function Sync:OnCommReceived(prefix, msg, type, sender)
	if( sender == playerName ) then
		return
	end
	
	local cmd, arg = string.match(msg, "([a-zA-Z+]+): (.+)")
	if( not cmd or not arg ) then
		cmd = msg
	elseif( arg ) then
		arg = string.trim(arg)
	end
	
	-- Request our assignment data
	if( cmd == "REQUEST" ) then
		-- We already got a request from this person, and it's still throttled
		if( requestThrottle[sender] and requestThrottle[sender] >= GetTime() ) then
			return
		end
		
		requestThrottle[sender] = GetTime() + THROTTLE_TIME
		
		-- This lets us know that the person has Pally Power support on, so any of there comms using Pally Power data
		-- should be ignored, as they will be sending data in our real format as well
		supportsPP[sender] = arg == "true"
		
		self:SendPersonalAssignment()
	
	-- Blessing data
	elseif( cmd == "BLESSINGS" ) then
		PaladinBuffer:ResetBlessingData(sender)
		self:ParseTalents(sender, string.split(":", arg))
			
	-- Reset + Assign, this implies that any data not present is there because they aren't assigned it
	elseif( cmd == "RASSIGN" and arg and playerName ~= sender and PaladinBuffer:HasPermission(sender) ) then
		self:ParsePlayerAssignments(true, string.split(";", arg))
		
	-- Assign, this implies that the data is partially sent, meaning it might be multiple ASSIGNs to get all of them done
	-- I'm using RASSIGN for this, ASSIGN is "just in case"
	elseif( cmd == "ASSIGN" and arg and playerName ~= sender and PaladinBuffer:HasPermission(sender) ) then
		self:ParsePlayerAssignments(false, string.split(";", arg))
		
	-- We got this persons assignments
	elseif( cmd == "MYDATA" and arg and playerName ~= sender ) then
		local talents, assignments, leaderRequired = string.split(";", arg)
		if( talents and assignments ) then
			-- You need assist or leader to change there assignments
			freeAssign[sender] = (leaderRequired == "true") and false or true
			self:SendMessage("PB_PERMISSIONS_UPDATED", sender)

			-- It's implied that if the information wasn't sent in this that they aren't assigned to it
			-- we basically trade a trivial amount of CPU (resetting two tables) for less comm data sent through the addon channels
			PaladinBuffer:ResetBlessingData(sender)
			self:ParseTalents(sender, string.split(":", talents))
			
			PaladinBuffer:ClearAssignments(sender)
			self:ParseAssignments(sender, string.split(":", assignments))
		end
	
	-- Leadership required?
	elseif( cmd == "LEADER" and arg and playerName ~= sender ) then
		freeAssign[sender] = (leaderRequired == "true") and false or true
		self:SendMessage("PB_PERMISSIONS_UPDATED", sender)
	
	-- Clear assignments from people
	elseif( cmd == "CLEAR" and PaladinBuffer:HasPermission(sender) ) then
		PaladinBuffer:ClearAllAssignments()
	end
end

function Sync:SendAddonMessage(msg, prefix)
	self:SendCommMessage(prefix or "PALB", msg, "RAID")
end
 

--[[
Pally Power sync format

REQ
 Give me data about your assignments/free assignments/what skills I have/etc

ASSIGN <name> <class #> <skill #>
 Assign a specific person to a class as well as the spell they are assigned

NASSIGN <casterName> <class> <target> <skill ID>
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
local classConversions = {[1] = "WARRIOR", [2] = "ROGUE", [3] = "PRIEST", [4] = "DRUID", [5] = "PALADIN", [6] = "HUNTER", [7] = "MAGE", [8] = "WARLOCK", [9] = "SHAMAN", [10] = "DEATHKNIGHT", ["WARRIOR"] = 1, ["ROGUE"] = 2, ["PRIEST"] = 3, ["DRUID"] = 4, ["PALADIN"] = 5, ["HUNTER"] = 6, ["MAGE"] = 7, ["WARLOCK"] = 8, ["SHAMAN"] = 9, ["DEATHKNIGHT"] = 10}
local singleMaxRanks = {["might"] = 10, ["wisdom"] = 9, ["kings"] = 1, ["sanct"] = 1}
local TOTAL_CLASSES = 11

-- Send the assignments out
-- Timer to make  sure we know the data was cleared first
local function sendPP()
	for name, assignments in pairs(PaladinBuffer.db.profile.assignments) do
		local classesFound = 0
		local spellAssigned
		for target, spellToken in pairs(assignments) do
			-- Check if we can send this as a mass assignment to save bandwidth
			if( not spellAssigned and classList[target] ) then
				spellAssigned = spellToken
				classesFound = classesFound + 1
				
			-- This is a class assignment, but it's using a different token so we have to do single greater assignments
			elseif( classList[target] and spellToken ~= spellAssigned ) then
				spellAssigned = "spam"
			-- This is a single assignment, so send it regardless
			elseif( not classList[target] and UnitExists(target) ) then
				Sync:SendAddonMessage(string.format("NASSIGN %s %d %s %d", name, classConversions[select(2, UnitClass(target))], target, tonumber(singleConversions[spellToken]) or 0), "PLPWR")
			end
		end
		
		-- They are assigned to it, so we can do a mass to save bandwidth
		if( spellAssigned and spellAssigned ~= "spam" and classesFound == 10 ) then
			Sync:SendAddonMessage(string.format("MASSIGN %s %s", name, greaterConversions[spellAssigned]), "PLPWR")
		-- Nope, :( send it as singles
		else
			-- Send that we don't have pets assigned
			Sync:SendAddonMessage(string.format("ASSIGN %s 11 0", name), "PLPWR")
			
			for classToken in pairs(PaladinBuffer.classList) do
				local spellID = 0
				if( assignments[classToken] ) then
					spellID = greaterConversions[assignments[classToken]]
				end
				
				Sync:SendAddonMessage(string.format("ASSIGN %s %d %s", name, classConversions[classToken], spellID), "PLPWR")
			end
		end
	end
end

local timeElapsed = 0
local frame = CreateFrame("Frame")
frame:Hide()
frame:SetScript("OnUpdate", function(self, elapsed)
	timeElapsed = timeElapsed - elapsed
	
	if( timeElapsed <= 0 ) then
		sendPP()
		self:Hide()
	end
end)

function Sync:SendPPAssignments()
	-- Clear everything
	Sync:SendAddonMessage("CLEAR", "PLPWR")
	
	-- Wait half a second so we can be more sure that it was actually all cleared before ours is sent out
	timeElapsed = 0.50
	frame:Show()
end

local function constructRankString(spellText, spellToken)
	if( type(PaladinBuffer.db.profile.blessings[playerName][spellToken]) == "number" ) then
		local rank, points = string.split(".", PaladinBuffer.db.profile.blessings[playerName][spellToken])
		spellText = string.format("%s%s%s", spellText, rank, tonumber(points) or 0)
	else
		spellText = string.format("%snn", spellText)
	end
	
	return spellText
end

function Sync:SendPPData()
	if( PaladinBuffer.disabled ) then
		return
	end
	
	-- Compile the list of what we have trained/talented
	local spellText = ""
	spellText = constructRankString(spellText, "gwisdom")
	spellText = constructRankString(spellText, "gmight")
	spellText = constructRankString(spellText, "gkings")
	spellText = constructRankString(spellText, "gsanct")
	
	-- Compile a list of our assignments (If any)
	local assignText = ""
	for i=1, TOTAL_CLASSES do
		local classToken = classConversions[i]
		local spellToken = PaladinBuffer.db.profile.assignments[playerName][classToken] or ""
		assignText = string.format("%s%s", assignText, tonumber(greaterConversions[spellToken]) or "n")
	end
	
	-- Send it off
	self:SendAddonMessage(string.format("SELF %s@%s", spellText, assignText), "PLPWR")
	-- No we don't want anyone to do our assignments
	self:SendAddonMessage(string.format("FREEASSIGN %s", PaladinBuffer.db.profile.requireLeader and "NO" or "YES"), "PLPWR")
end

function Sync:ParsePPBlessingData(sender, singleType, greaterType, rank, improved)
	-- They don't have this spell, so reset it
	if( not rank ) then
		PaladinBuffer:SetBlessingData(sender, singleType, nil)
		PaladinBuffer:SetBlessingData(sender, greaterType, nil)
		return
	end
	
	-- We have to fake the rank for singles, as PP only passes the highest
	local fraction = (improved or 0) / 10
	PaladinBuffer:SetBlessingData(sender, singleType, singleMaxRanks[singleType] + fraction)
	PaladinBuffer:SetBlessingData(sender, greaterType, rank + fraction)
end

function Sync:CHAT_MSG_ADDON(event, prefix, msg, type, sender)
	--[[if( sender == playerName ) then
		print(" <-- ", prefix, sender, msg)
	else
		print(" --> ", prefix, sender, msg)
	end
	]]
	
	-- Make sure we want this message
	if( prefix ~= "PLPWR" or sender == playerName or not PaladinBuffer.db.profile.ppSupport or supportsPP[sender] or ( type ~= "PARTY" and type ~= "RAID" ) ) then
		return
	end
	
	local cmd, arg = string.match(msg, "([a-zA-Z]+) (.+)")
	if( not cmd or not arg ) then
		cmd = msg
	elseif( arg ) then
		arg = string.trim(arg)
	end

	-- Request our data
	if( cmd == "REQ" ) then
		-- We already got a request from this person, and it's still throttled
		if( requestThrottle[sender] and requestThrottle[sender] >= GetTime() ) then
			return
		end
		
		requestThrottle[sender] = GetTime() + THROTTLE_TIME

		self:SendPPData()
		
	-- Someone was assigned a specific spell to a specific class
	elseif( cmd == "ASSIGN" and arg and playerName ~= sender and PaladinBuffer:HasPermission(sender) ) then
		local name, classID, spellID = string.split(" ", arg)
		classID = tonumber(string.trim(classID))
		spellID = tonumber(string.trim(spellID)) or "n"
		
		if( name and classID and spellID  and classID <= 10 ) then
			PaladinBuffer:AssignBlessing(name, greaterConversions[spellID], classConversions[classID])	
		end
		
	-- Someone was assigned to a single blessing
	elseif( cmd == "NASSIGN" and arg and playerName ~= sender and PaladinBuffer:HasPermission(sender) ) then
		local casterName, _, target, spellID = string.split(" ", arg)
		spellID = tonumber(string.trim(spellID)) or "n"
		
		if( target and casterName and spellID ) then
			PaladinBuffer:AssignBlessing(casterName, singleConversions[spellID], target)
		end
		
	-- Someone was assigned to the same blessing on every class
	elseif( cmd == "MASSIGN" and arg and playerName ~= sender and PaladinBuffer:HasPermission(sender) ) then
		local name, spellID = string.split(" ", arg)
		spellID = tonumber(string.trim(spellID)) or "n"
		
		if( name ) then
			for classToken in pairs(classList) do
				PaladinBuffer:AssignBlessing(name, greaterConversions[spellID], classToken)
			end
		end
	
	-- We got data on someones assignments, make sure they are a Paladin thought, why the fuck would I care about there own assignments
	-- if they aren't a Paladin
	elseif( cmd == "SELF" and arg and playerName ~= sender and UnitExists(sender) and select(2, UnitClass(sender)) == "PALADIN" ) then
		local talents, assignments = string.split("@", arg)
		if( talents and assignments ) then
			-- Parse talents/etc, we don't do the below parsing type because it's an ordered list
			talents = string.trim(talents)
			
			local wisdomRank, wisdomImproved, mightRank, mightImproved, kingsRank, kingsImproved, sanctRank, sanctImproved = string.match(talents, "([0-9n])([0-9n])([0-9n])([0-9n])([0-9n])([0-9n])([0-9n])([0-9n])")
			self:ParsePPBlessingData(sender, "wisdom", "gwisdom", tonumber(wisdomRank), tonumber(wisdomImproved))
			self:ParsePPBlessingData(sender, "might", "gmight", tonumber(mightRank), tonumber(mightImproved))
			self:ParsePPBlessingData(sender, "kings", "gkings", tonumber(kingsRank), tonumber(kingsImproved))
			self:ParsePPBlessingData(sender, "sanct", "gsanct", tonumber(sanctRank), tonumber(sanctImproved))
			
			-- Parse assignments
			assignments = string.trim(assignments)
			
			local offset = 0
			local length = string.len(assignments)
			local classID = 0
			while( offset <= length ) do
				offset = offset + 1
				classID = classID + 1

				local spellID = string.sub(assignments, offset, offset)
				if( spellID == "" or classID >= 11 ) then break end
				spellID = tonumber(spellID) or "n"
										
				PaladinBuffer:AssignBlessing(sender, greaterConversions[spellID], classConversions[classID])
			end
			
		end
	
	-- Should I support this?
	elseif( cmd == "FREEASSIGN" and arg and playerName ~= sender ) then
		freeAssign[sender] = ( arg == "YES" ) and true or false
		self:SendMessage("PB_PERMISSIONS_UPDATED", sender)
	
	-- Clear requested data
	elseif( cmd == "CLEAR" and playerName ~= sender and PaladinBuffer:HasPermission(sender) ) then
		PaladinBuffer:ClearAllAssignments()
	end
end
