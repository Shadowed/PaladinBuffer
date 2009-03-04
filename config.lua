if( not PaladinBuffer ) then return end

local Config = PaladinBuffer:NewModule("Config")
local L = SimpleBBLocals

local SML, registered, options, config, dialog

local globalSettings = {}

function Config:OnInitialize()
	config = LibStub("AceConfig-3.0")
	dialog = LibStub("AceConfigDialog-3.0")
end

-- GUI
local function setGlobal(arg1, arg2, arg3, value)
	for name in pairs(SimpleBB.db.profile.groups) do
		SimpleBB.db.profile[arg1][name][arg3] = value
		globalSettings[arg3] = value
	end
	
	SimpleBB:Reload()
end


local function set(info, value)
	local arg1, arg2, arg3 = string.split(".", info.arg)
	
	if( arg2 == "global" ) then
		setGlobal(arg1, arg2, arg3, value)
		return
	elseif( arg2 and arg3 ) then
		SimpleBB.db.profile[arg1][arg2][arg3] = value
	elseif( arg2 ) then
		SimpleBB.db.profile[arg1][arg2] = value
	else
		SimpleBB.db.profile[arg1] = value
	end
	
	SimpleBB:Reload()
end

local function get(info)
	local arg1, arg2, arg3 = string.split(".", info.arg)
	
	if( arg2 == "global" ) then
		return globalSettings[arg3]
	elseif( arg2 and arg3 ) then
		return SimpleBB.db.profile[arg1][arg2][arg3]
	elseif( arg2 ) then
		return SimpleBB.db.profile[arg1][arg2]
	else
		return SimpleBB.db.profile[arg1]
	end
end

local function setMulti(info, value, state)
	local arg1, arg2, arg3 = string.split(".", info.arg)
	if( tonumber(arg2) ) then arg2 = tonumber(arg2) end

	if( arg2 and arg3 ) then
		SimpleBB.db.profile[arg1][arg2][arg3][value] = state
	elseif( arg2 ) then
		SimpleBB.db.profile[arg1][arg2][value] = state
	else
		SimpleBB.db.profile[arg1][value] = state
	end

	SimpleBB:Reload()
end

local function getMulti(info, value)
	local arg1, arg2, arg3 = string.split(".", info.arg)
	if( tonumber(arg2) ) then arg2 = tonumber(arg2) end
	
	if( arg2 and arg3 ) then
		return SimpleBB.db.profile[arg1][arg2][arg3][value]
	elseif( arg2 ) then
		return SimpleBB.db.profile[arg1][arg2][value]
	else
		return SimpleBB.db.profile[arg1][value]
	end
end


local function setNumber(info, value)
	set(info, tonumber(value))
end

local function setColor(info, r, g, b)
	set(info, {r = r, g = g, b = b})
end

local function getColor(info)
	local value = get(info)
	if( type(value) == "table" ) then
		return value.r, value.g, value.b
	end
	
	return value
end

local textures = {}
function Config:GetTextures()
	for k in pairs(textures) do textures[k] = nil end

	for _, name in pairs(SML:List(SML.MediaType.STATUSBAR)) do
		textures[name] = name
	end
	
	return textures
end

local fonts = {}
function Config:GetFonts()
	for k in pairs(fonts) do fonts[k] = nil end

	for _, name in pairs(SML:List(SML.MediaType.FONT)) do
		fonts[name] = name
	end
	
	return fonts
end

local timeDisplay = {["hhmmss"] = L["HH:MM:SS"], ["blizzard"] = L["Blizzard default"]}
local function createAnchorOptions(group)
	return {
		desc = {
			order = 0,
			name = string.format(L["Anchor configuration for %ss."], group),
			type = "description",
		},
		general = {
			order = 1,
			type = "group",
			inline = true,
			name = L["General"],
			args = {
				growUp = {
					order = 0,
					type = "toggle",
					name = L["Grow display up"],
					desc = L["Instead of adding everything from top to bottom, timers will be shown from bottom to top."],
					arg = string.format("groups.%s.growUp", group),
					width = "full",
				},
				timeless = {
					order = 1,
					type = "toggle",
					name = L["Fill timeless buffs"],
					desc = L["Buffs without a duration will have the status bar shown as filled in, instead of empty."],
					arg = string.format("groups.%s.fillTimeless", group),
				},
				passive = {
					order = 2,
					type = "toggle",
					name = L["Hide passive buffs"],
					arg = string.format("groups.%s.passive", group),
				},
				sep = {
					order = 3,
					name = "",
					type = "description",
				},
				scale = {
					order = 4,
					type = "range",
					name = L["Display scale"],
					desc = L["How big the actual timers should be."],
					min = 0, max = 2, step = 0.01,
					arg = string.format("groups.%s.scale", group),
				},
				alpha = {
					order = 5,
					type = "range",
					name = L["Display alpha"],
					min = 0, max = 1, step = 0.1,
					arg = string.format("groups.%s.alpha", group),
				},
				sep = {
					order = 6,
					name = "",
					type = "description",
				},
				--[[
				maxRows = {
					order = 6,
					type = "range",
					name = L["Max timers"],
					desc = L["Maximum amount of timers that should be ran per an anchor at the same time, if too many are running at the same time then the new ones will simply be hidden until older ones are removed."],
					min = 1, max = 100, step = 1,
					arg = string.format("groups.%s.maxRows", group),
				},
				]]
				sorting = {
					order = 7,
					type = "select",
					name = L["Buff sorting"],
					desc = L["Sorting information\nTime Left:\nTracking > Auras > Temporary weapon enchant > Buffs by time left\n\nOrder gained:\nTracking > Temporary weapon enchant > Auras > Buffs by order added."],
					values = {["timeleft"] = L["Time left"], ["index"] = L["Order gained"]},
					arg = string.format("groups.%s.sortBy", group),
				},
				icon = {
					order = 8,
					type = "select",
					name = L["Icon position"],
					values = {["LEFT"] = L["Left"], ["RIGHT"] = L["Right"]},
					arg = string.format("groups.%s.iconPosition", group),
				},
				spacing = {
					order = 9,
					type = "range",
					name = L["Row spacing"],
					desc = L["How far apart each timer bar should be."],
					min = -20, max = 20, step = 1,
					arg = string.format("groups.%s.spacing", group),
				},
			}
		},
		anchor = {
			order = 2,
			type = "group",
			inline = true,
			name = L["Anchor"],
			args = {
			 	size = {
					order = 1,
					type = "range",
					name = L["Spacing"],
					desc = L["How far apart this anchor should be from the one it's anchored to, does not apply if anchor to is set to none."],
					min = 0, max = 100, step = 1,
					set = setNumber,
					arg = string.format("groups.%s.anchorSpacing", group),
				},
				to = {
					order = 2,
					type = "select",
					name = L["Anchor to"],
					desc = string.format(L["Lets you anchor %ss to another anchor where it'll be shown below it and positioned so that they never overlap."], group),
					values = {[""] = L["None"], ["buffs"] = L["Buffs"], ["debuffs"] = L["Debuffs"], ["tempEnchants"] = L["Temporary enchants"]},
					arg = string.format("groups.%s.anchorTo", group),
				},
			},
		},
		tempEnchant = {
			order = 2,
			type = "group",
			inline = true,
			name = L["Temporary enchants"],
			args = {
				to = {
					order = 2,
					type = "select",
					name = L["Move to"],
					desc = L["Allows you to move the temporary weapon enchants into another anchor."],
					values = {[""] = L["None"], ["buffs"] = L["Buffs"], ["debuffs"] = L["Debuffs"]},
					arg = string.format("groups.%s.moveTo", group),
				},
				tempColor = {
					order = 4,
					type = "color",
					name = L["Temporary enchant colors"],
					desc = L["Bar and background color for temporary weapon enchants, only used if color by type is enabled."],
					set = setColor,
					get = getColor,
					arg = string.format("groups.%s.tempColor", group),
				},
			},
		},
		bar = {
			order = 3,
			type = "group",
			inline = true,
			name = L["Bars"],
			args = {
				width = {
					order = 1,
					type = "range",
					name = L["Width"],
					min = 50, max = 300, step = 1,
					set = setNumber,
					arg = string.format("groups.%s.width", group),
				},
				height = {
					order = 2,
					type = "range",
					name = L["Height"],
					min = 1, max = 30, step = 1,
					set = setNumber,
					arg = string.format("groups.%s.height", group),
				},
				sep = {
					order = 3,
					name = "",
					type = "description",
				},
				texture = {
					order = 4,
					type = "select",
					name = L["Texture"],
					dialogControl = "LSM30_Statusbar",
					values = "GetTextures",
					arg = string.format("groups.%s.texture", group),
				},
				color = {
					order = 5,
					type = "group",
					inline = true,
					name = L["Colors"],
					args = {
						colorType = {
							order = 1,
							type = "toggle",
							name = L["Color by type"],
							desc = L["Sets the bar color to the buff type, if it's a buff light blue, temporary weapon enchants purple, debuffs will be colored by magic type, or red if none."],
							arg = string.format("groups.%s.colorByType", group),
						},
						baseColor = {
							order = 3,
							type = "color",
							name = L["Color"],
							desc = L["Bar color and background color, if color by type is enabled then this only applies to buffs and tracking."],
							set = setColor,
							get = getColor,
							arg = string.format("groups.%s.color", group),
						},
					},
				},
			},
		},
		text = {
			order = 8,
			type = "group",
			inline = true,
			name = L["Text"],
			args = {
				size = {
					order = 1,
					type = "range",
					name = L["Size"],
					min = 1, max = 20, step = 1,
					set = setNumber,
					arg = string.format("groups.%s.fontSize", group),
				},
				name = {
					order = 2,
					type = "select",
					name = L["Font"],
					dialogControl = "LSM30_Font",
					values = "GetFonts",
					arg = string.format("groups.%s.font", group),
				},
				display = {
					order = 3,
					type = "group",
					inline = true,
					name = L["Display"],
					args = {
						stack = {
							order = 1,
							type = "toggle",
							name = L["Show stack size"],
							arg = string.format("groups.%s.showStack", group),
							width = "full",
						},
						stackFirst = {
							order = 2,
							type = "toggle",
							name = L["Show stack first"],
							arg = string.format("groups.%s.stackFirst", group),
						},
						rank = {
							order = 3,
							type = "toggle",
							name = L["Show spell rank"],
							arg = string.format("groups.%s.showRank", group),
						},
						name = {
							order = 4,
							type = "select",
							name = L["Time display"],
							values = timeDisplay,
							arg = string.format("groups.%s.time", group),
						},
					},
				},
			},
		},
	}
end

local function loadOptions()
	options = {}
	options.type = "group"
	options.name = "Simple Buff Bars"
	
	options.args = {}
	options.args.general = {
		type = "group",
		order = 1,
		name = L["General"],
		get = get,
		set = set,
		handler = Config,
		args = {
			enabled = {
				order = 0,
				type = "toggle",
				name = L["Lock frames"],
				desc = L["Prevents the frames from being dragged with ALT + Drag."],
				width = "full",
				arg = "locked",
			},
			example = {
				order = 1,
				type = "toggle",
				name = L["Show examples"],
				desc = L["Shows an example buff/debuff for configuration."],
				width = "full",
				arg = "showExample",
			},
			temps = {
				order = 2,
				type = "toggle",
				name = L["Show temporary weapon enchants"],
				desc = L["Shows your current temporary weapon enchants as a buff."],
				width = "full",
				arg = "showTemp",
			},
			tracking = {
				order = 3,
				type = "toggle",
				name = L["Show tracking"],
				desc = L["Shows your current tracking as a buff, can change trackings through this as well."],
				width = "full",
				arg = "showTrack",
			},
			filters = {
				order = 4,
				type = "group",
				inline = true,
				name = L["Filtering"],
				args = {
					desc = {
						order = 0,
						name = L["Allows you to reduce the amount of buffs that are shown by using different filters to hide things that are not relevant to your current talents.\n\nThis will filter things that are not directly related to the filter type, the Physical filter will hide things like Flametongue Totem, or Divine Spirit, while the Caster filter will hide Windfury Totem or Battle Shout."],
						type = "description",
					},
					autoFilter = {
						order = 1,
						type = "toggle",
						name = L["Auto filter"],
						desc = L["Automatically enables the physical or caster filters based on talents and class."],
						arg = "autoFilter",
						width = "full",
					},
					filters = {
						order = 2,
						name = L["Filters"],
						type = "multiselect",
						arg = "filtersEnabled",
						disabled = function() return SimpleBB.db.profile.autoFilter end,
						values = SimpleBB.modules.Filters:GetList(),
						set = setMulti,
						get = getMulti,
					},
				},
			},
			global = {
				order = 5,
				type = "group",
				inline = true,
				name = L["Global options"],
				args = {},
			},
		},
	}
	
	-- Setup global options
	options.args.general.args.global.args = createAnchorOptions("global")
	
	local globalOptions = options.args.general.args.global.args
	globalOptions.desc.name = L["Lets you globally set options for all anchors instead of having to do it one by one.\n\nThe options already chosen in these do not reflect the current anchors settings.\n\nNOTE! Not all options are available, things like anchoring or hiding passive buffs are only available in the anchors own configuration."]
	globalOptions.anchor.args.to = nil
	globalOptions.general.args.passive = nil
	globalOptions.general.args.growUp.width = nil
	
	
	-- Buff configuration
	options.args.buffs = {
		order = 2,
		type = "group",
		name = L["Player buffs"],
		get = get,
		set = set,
		handler = Config,
		args = createAnchorOptions("buffs"),
	}
	
	options.args.buffs.args.tempEnchant = nil
	options.args.buffs.args.anchor.args.to.values.buffs = nil

	-- Debuff configuration
	options.args.tempEnchants = {
		order = 3,
		type = "group",
		name = L["Temporary enchants"],
		get = get,
		set = set,
		handler = Config,
		args = createAnchorOptions("tempEnchants"),
	}
	
	options.args.tempEnchants.args.bar.args.color.args.color = nil
	options.args.tempEnchants.args.anchor.args.to.values.tempenchants = nil

	-- Debuff configuration
	options.args.debuffs = {
		order = 4,
		type = "group",
		name = L["Player debuffs"],
		get = get,
		set = set,
		handler = Config,
		args = createAnchorOptions("debuffs"),
	}
	
	options.args.debuffs.args.tempEnchant = nil
	options.args.debuffs.args.anchor.args.to.values.debuffs = nil

	-- DB Profiles
	options.args.profile = LibStub("AceDBOptions-3.0"):GetOptionsTable(SimpleBB.db)
	options.args.profile.order = 5
end

-- Slash commands
SLASH_PALADINBUFF1 = "/paladinbuff"
SLASH_PALADINBUFF2 = "/paladinbuffer"
SLASH_PALADINBUFF3 = "/pb"
SLASH_PALADINBUFF4 = "/pp"
SlashCmdList["PALADINBUFF"] = function(msg)
	if( not registered ) then
		if( not options ) then
			loadOptions()
		end

		config:RegisterOptionsTable("SimpleBB", options)
		dialog:SetDefaultSize("SimpleBB", 650, 525)
		registered = true
	end

	dialog:Open("SimpleBB")
end