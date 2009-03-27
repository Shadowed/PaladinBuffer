if( not PaladinBuffer ) then return end

local Assign = PaladinBuffer:NewModule("Assign", "AceEvent-3.0", "AceComm-3.0")
local blessings, priorities, currentSort, assignments, blacklist
local singleToGreater = {["might"] = "gmight", ["kings"] = "gkings", ["wisdom"] = "gwisdom", ["sanct"] = "gsanct"}

-- Create our tables for doing smart assignments
function Assign:CreateTables()
	if( blessings ) then
		return
	end
	
	-- People we've already used
	blacklist = {}
	
	-- Blessings
	blessings = {}
	for spellToken, type in pairs(PaladinBuffer.blessingTypes) do
		if( type == "greater" ) then
			blessings[spellToken] = {}
		end
	end
	
	self.blessings = blessings
	
	-- Blessing priorities for people
	priorities = {
		["ROGUE"] = {"gkings", "gmight", "gsanct"},
		["WARRIOR"] = {"gkings", "gmight", "gsanct"},
		["DEATHKNIGHT"] = {"gkings", "gmight", "gsanct"},
		["PRIEST"] = {"gkings", "gwisdom", "gsanct"},
		["WARLOCK"] = {"gkings", "gwisdom", "gsanct"},
		["MAGE"] = {"gkings", "gwisdom", "gsanct"},
		["HUNTER"] = {"gkings", "gmight", "gwisdom", "gsanct"},
		["PALADIN"] = {"gkings", "gwisdom", "gmight", "gsanct"},
		["DRUID"] = {"gkings", "gwisdom", "gmight", "gsanct"},
		["SHAMAN"] = {"gkings", "gwisdom", "gmight", "gsanct"},
	}
	
	-- Set assignments for classes
	assignments = {}
	for classToken in pairs(priorities) do
		assignments[classToken] = {}
	end

	self.assignments = assignments
end

-- Sort the tables so the people with the highest rank of blessings come first
local function sortOrder(a, b)
	if( not a ) then
		return false
	elseif( not b ) then
		return true
	end
	
	return PaladinBuffer.db.profile.blessings[a][currentSort] > PaladinBuffer.db.profile.blessings[b][currentSort]
end

function Assign:SetHighestBlessers()
	self:CreateTables()
	
	for _, list in pairs(blessings) do for i=#(list), 1, -1 do table.remove(list, i) end end
	--[[
	-- Load them into a list of of who has what blessing
	for name, data in pairs(PaladinBuffer.db.profile.blessings) do
		for spellToken, rank in pairs(data) do
			if( rank ~= "none" and PaladinBuffer.blessingTypes[spellToken] == "greater" ) then
				blessings[spellToken][name] = rank
			end
		end
	end
	]]
	
	-- Load them into a list of of who has what blessing
	for name, data in pairs(PaladinBuffer.db.profile.blessings) do
		for spellToken, rank in pairs(data) do
			if( rank ~= "none" and PaladinBuffer.blessingTypes[spellToken] == "greater" ) then
				table.insert(blessings[spellToken], name)
			end
		end
	end
	
	
	-- Now sort it
	for spellToken, list in pairs(blessings) do
		currentSort = spellToken
		table.sort(list, sortOrder)
	end
end

--[[
function Assign:IsBlacklistHigher(name, priorityID, spellToken, classToken)
	-- They have an assignment to this class, and they aren't already assigned to it
	if( assignments[classToken][name] and assignments[classToken][name] ~= spellToken ) then
		local assignedPriority
		-- Find out what the priority of the assignment is
		for id, token in pairs(priorities[classToken]) do
			if( token == assignments[classToken][name] ) then
				assignedPriority = id
				break
			end
		end
		
		if( not assignedPriority ) then
			return true
		end
		
		-- If the assigned priority is higher than the one we passed should overwrite the assignment
		return assignedPriority > priorityID, assignedPriority
	end
	
	-- Not assigned to this class yet
	return true
end

function Assign:RecurseBlessingAssign(priorityID, classToken, isRecursed)
	local spellToken = priorities[classToken][priorityID]
	if( not spellToken ) then
		return
	end
	
	print("Assigning priority ID", priorityID, spellToken, classToken)
		
	-- Find the highest one who can buff this, that isn't blacklisted
	local highestAvailable = 0
	local lastAssigned
	for name, rank in pairs(blessings[spellToken]) do
		if( highestAvailable <= rank and not assignments[classToken][name] ) then
			highestAvailable = rank
			lastAssigned = name
		end
	end

	-- We didn't find one looking for people with unassigned blessings, now find one that beats the priority list
	if( highestAvailable == 0 ) then
		for name, rank in pairs(blessings[spellToken]) do
			if( highestAvailable <= rank and self:IsBlacklistHigher(name, priorityID, spellToken, classToken) ) then
				highestAvailable = rank
				lastAssigned = name
			end
		end
	end
	
	-- We have an assignment
	if( lastAssigned ) then
		local previousToken = assignments[classToken][lastAssigned]
		
		print("Assigning", lastAssigned, " to", classToken, spellToken)
		assignments[classToken][lastAssigned] = spellToken
		
		-- We had another blessing assigned to this class, so do a recursive assignment
		if( previousToken and previousToken ~= spellToken ) then
			for id, token in pairs(priorities[classToken]) do
				if( token == previousToken ) then
					print("Player", name, "already was assigned to", previousToken, "recursing to reassign.")
					self:RecurseBlessingAssign(id, classToken, true)
					break
				end
			end
		end
	end
	
	if( isRecursed ) then
		print("Was a recursive assignment for", priorityID, "done.")
		return
	end
	
	print("Finished assignment", priorityID, ", going to next one.")
	self:RecurseBlessingAssign(priorityID - 1, classToken)
end

function Assign:CalculateBlessings()
	for _, list in pairs(assignments) do for k in pairs(list) do list[k] = nil end end
	
	for classToken, classPriorities in pairs(priorities) do
		for k in pairs(blacklist) do blacklist[k] = nil end
		
		if( classToken == "PALADIN" ) then
			self:RecurseBlessingAssign(#(classPriorities), classToken)
			return
		end
	end
end
]]

function Assign:CalculateBlessings()
	for _, list in pairs(assignments) do for k in pairs(list) do list[k] = nil end end
	
	-- Loop through and do all of our fancy assigning
	for classToken, classPriorities in pairs(priorities) do
		for k in pairs(blacklist) do blacklist[k] = nil end
		
		-- Loop through the priorities in order
		for _, spellToken in pairs(classPriorities) do
			-- Now find out who can do the highest rank of this, that isn't black listed
			for _, playerName in pairs(blessings[spellToken]) do
				if( not blacklist[playerName] ) then
					blacklist[playerName] = true

					assignments[classToken][playerName] = spellToken
					break
				end
			end
		end
	end
	
	-- Reset all previous assignments
	PaladinBuffer:ClearAllAssignments()
	
	-- Now assign the new ones
	for classToken, list in pairs(assignments) do
		for playerName, spellToken in pairs(list) do
			PaladinBuffer:AssignBlessing(playerName, spellToken, classToken)
		end
	end
end

function Assign:TotalSingleAssigns(spellToken, playerName)
	if( not PaladinBuffer.db.profile.assignments[playerName] ) then
		return 0
	end
	
	local total = 0
	for assignment, token in pairs(PaladinBuffer.db.profile.assignments[playerName]) do
		if( token == spellToken ) then
			total = total + 1
		end
	end
	
	return total
end


function Assign:FindSingleBlesser(spellToken)
	local highestName, highestRank
	for name, data in pairs(PaladinBuffer.db.profile.blessings) do
		if( data[spellToken] and ( not highestRank or highestRank < data[spellToken] ) ) then
			highestName = name
			highestRank = data[spellToken]
		end
	end
	
	return highestName
end

function Assign:IsBlessingAvailable(spellToken, playerName)
	if( playerName and PaladinBuffer.db.profile.blessings[playerName] ) then
		return PaladinBuffer.db.profile.blessings[playerName][spellToken] and true or false
	end

	for _, data in pairs(PaladinBuffer.db.profile.blessings) do
		if( data[spellToken] ) then
			return true
		end
	end
	
	return false
end

function Assign:IsGreaterAssigned(class, spellToken)
	for _, data in pairs(PaladinBuffer.db.profile.assignments) do
		if( data[class] == singleToGreater[spellToken] ) then
			return true
		end
	end
	
	return false
end
