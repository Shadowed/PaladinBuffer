if( not PaladinBuffer ) then return end

local Config = PaladinBuffer:NewModule("Config")
local L = PaladinBufferLocals

local registered, options, config, dialog

function Config:OnInitialize()
	config = LibStub("AceConfig-3.0")
	dialog = LibStub("AceConfigDialog-3.0")
end

-- Variable management
local function set(info, value)
	if( info[#(info) - 1] ~= "general" ) then
		PaladinBuffer.db.profile[info[#(info) - 1]][info[(#info)]] = value
	else
		PaladinBuffer.db.profile[info[(#info)]] = value
	end
	
	PaladinBuffer:Reload()
end

local function get(info)
	if( info[#(info) - 1] ~= "general" ) then
		return PaladinBuffer.db.profile[info[#(info) - 1]][info[(#info)]]
	else
		return PaladinBuffer.db.profile[info[(#info)]]
	end
end

local function setNumber(info, value)
	set(info, tonumber(value))
end

local function setMulti(info, state, value)
	PaladinBuffer.db.profile[info[(#info)]][state] = value
	PaladinBuffer:Reload()
end

local function getMulti(info, state)
	return PaladinBuffer.db.profile[info[(#info)]][state]
end

local function loadOptions()
	options = {}
	options.type = "group"
	options.name = "Paladin Buffer"
	
	options.args = {}
	options.args.general = {
		type = "group",
		order = 1,
		name = L["General"],
		get = get,
		set = set,
		handler = Config,
		args = {
			general = {
				order = 1,
				type = "group",
				inline = true,
				name = L["General"],
				args = {
					ppSupport = {
						order = 0,
						type = "toggle",
						name = L["Enable Pally Power support"],
						desc = L["Allows you to both send and receive assignments from Pally Power users."],
						width = "full",
					},
					greaterBinding = {
						order = 1,
						type = "keybinding",
						name = L["Greater buff binding"],
						desc = L["Binding to use for smart buffing your assigned greater blessings."],
					},
					singleBinding = {
						order = 2,
						type = "keybinding",
						name = L["Single buff binding"],
						desc = L["Binding to use for smart buffing your assigned single blessings."],
					},
					scale = {
						order = 3,
						type = "range",
						name = L["Assignment frame scale"],
						min = 0, max = 2, step = 0.01,
						set = setNumber,
						width = "full",
					},
					rangeThreshold = {
						order = 4,
						type = "range",
						name = L["Percentage of in range to buff"],
						desc = L["How much percent of the players should be in range before using a Greater Blessing on there class. 90% for example means at least 90% of the people on the class have to be in range."],
						min = 0, max = 1.0, step = 0.01,
						set = setNumber,
					},
					timeThreshold = {
						order = 5,
						type = "range",
						name = L["Percentage left until rebuff"],
						desc = L["Percentage of how much time should be left on a buff before recasting it, 50% means that Greater Blessings have to be at or below 15 minutes, and single blessings at or below 5 minutes."],
						min = 0, max = 1.0, step = 0.01,
						set = setNumber,
					},
					inside = {
						order = 6,
						type = "multiselect",
						name = L["Enable mod inside"],
						desc = L["Allows you to choose which scenarios this mod should be enabled in."],
						values = {["none"] = L["Everywhere else"], ["pvp"] = L["Battlegrounds"], ["arena"] = L["Arenas"], ["raid"] = L["Raid instances"], ["party"] = L["Party instances"]},
						width = "full",
						set = setMulti,
						get = getMulti,
					},
				}
			},
			frame = {
				order = 2,
				type = "group",
				inline = true,
				name = L["Buff frame"],
				args = {
					enabled = {
						order = 1,
						type = "toggle",
						name = L["Enable buff frame"],
						desc = L["Enables showing the smart buff frame while in a group."],
						width = "full",
					},
					locked = {
						order = 2,
						type = "toggle",
						name = L["Locked"],
					},
					growUp = {
						order = 3,
						type = "toggle",
						name = L["Grow up"],
					},
					classes = {
						order = 4,
						type = "toggle",
						name = L["Enable class status on buff frame"],
						desc = L["Shows each classes buff status and lets you manually buff them with the required blessings."],
					},
					hideInCombat = {
						order = 5,
						type = "toggle",
						name = L["Hide in combat"],
						desc = L["Hides the entire buff frame while you are in combat."],
					},
					scale = {
						order = 6,
						type = "range",
						name = L["Scale"],
						min = 0, max = 1.0, step = 0.01,
						set = setNumber,
					},
					columns = {
						order = 7,
						type = "range",
						name = L["Columns"],
						desc = L["How many columns to show, 1 for example will show a single straight line."],
						min = 1, max = 11, step = 1,
						set = setNumber,
					},
				},
			},
		}
	}

	-- DB Profiles
	options.args.profile = LibStub("AceDBOptions-3.0"):GetOptionsTable(PaladinBuffer.db)
	options.args.profile.order = 3
end


-- Slash commands
SLASH_PALADINBUFF1 = "/paladinbuff"
SLASH_PALADINBUFF2 = "/paladinbuffer"
SLASH_PALADINBUFF3 = "/pb"
SlashCmdList["PALADINBUFF"] = function(msg)
	msg = string.lower(msg or "")
	
	if( msg == "assign" ) then
		local Assign = PaladinBuffer.modules.AssignGUI
		Assign:CreateFrame()
		
		if( Assign.frame:IsVisible() ) then
			Assign.frame:Hide()	
		else
			Assign.frame:Show()
		end
		
	elseif( msg == "config" ) then
		if( not registered ) then
			if( not options ) then
				loadOptions()
			end

			config:RegisterOptionsTable("PaladinBuffer", options)
			dialog:SetDefaultSize("PaladinBuffer", 650, 525)
			registered = true
		end

		dialog:Open("PaladinBuffer")
	else
		PaladinBuffer:Print(L["Slash commands"])
		PaladinBuffer:Echo(L["/pb config - Shows the configuration."])
		PaladinBuffer:Echo(L["/pb assign - Shows the assignment interface."])
	end
end