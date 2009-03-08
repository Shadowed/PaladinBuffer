if( not PaladinBuffer ) then return end

local Assign = PaladinBuffer:NewModule("Assign", "AceEvent-3.0", "AceComm-3.0")
local blessings, priorities, currentSort, assignments, blacklist

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

function Assign:IsBlessingAvailable(target, spellToken)
	for _, data in pairs(PaladinBuffer.db.profile.blessings) do
		if( data[spellToken] ) then
			return true
		end
	end
end
