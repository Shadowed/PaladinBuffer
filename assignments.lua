if( not PaladinBuffer ) then return end

local Assign = PaladinBuffer:NewModule("Assign", "AceEvent-3.0", "AceComm-3.0")
local blessings, priorities, currentSort, assignments, blacklist
local singleToGreater = {["might"] = "gmight", ["kings"] = "gkings", ["wisdom"] = "gwisdom", ["sanct"] = "gsanct"}
local pointsInfo = {}

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
	
	return pointsInfo[a] < pointsInfo[b]
end

function Assign:SetHighestBlessers(classToken)
	-- Reset our list
	for _, list in pairs(blessings) do for i=#(list), 1, -1 do table.remove(list, i) end end
	
	-- Load the list of players by blessing into a table
	for name, data in pairs(PaladinBuffer.db.profile.blessings) do
		for spellToken, rank in pairs(data) do
			if( rank ~= "none" and PaladinBuffer.blessingTypes[spellToken] == "greater" ) then
				table.insert(blessings[spellToken], name)
			end
		end
	end
	
	-- Now go through that list
	for spellToken, list in pairs(blessings) do
		currentSort = spellToken
		
		-- What this does is find the person who is least likely to conflict with someone else, and ultimately give the highest blessing assignment		
		for k in pairs(pointsInfo) do pointsInfo[k] = nil end
		for name, data in pairs(PaladinBuffer.db.profile.blessings) do
			pointsInfo[name] = pointsInfo[name] or 0

			for token, rank in pairs(data) do
				if( token == spellToken ) then
					pointsInfo[name] = pointsInfo[name] - (rank * 1000)
				else
					-- Find the blessing priority
					local priority = 10
					for pID, pToken in pairs(priorities[classToken]) do
						if( pToken == token ) then
							priority = pID * 10
							break
						end
					end

					-- Add it up
					pointsInfo[name] = pointsInfo[name] + (rank * (100 - priority))
				end
			end
		end

		-- Sort it with our least likely conflicter
		table.sort(list, sortOrder)
	end
end

function Assign:CalculateBlessings()
	self:CreateTables()
	
	-- Reset assignments
	for _, list in pairs(assignments) do for k in pairs(list) do list[k] = nil end end
	
	-- Loop through and do all of our fancy assigning
	for classToken, classPriorities in pairs(priorities) do
		for k in pairs(blacklist) do blacklist[k] = nil end
		self:SetHighestBlessers(classToken)
		
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
