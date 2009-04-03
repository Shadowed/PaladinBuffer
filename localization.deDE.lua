if( GetLocale() ~= "deDE" ) then
	return
end

PaladinBufferLocals = setmetatable({
	["Rank ([0-9]+)"] = "Rang ([0-9]+)",

	["Warning! Paladin Buffer has been disabled for this character as you are not a Paladin."] = "Warnung! Paladin Buffer wurde f\195\188r diesen Charakter deaktiviert da du kein Paladin bist.",
	["You cannot use Paladin Buffer on a non-Paladin."] = "Du kannst Paladin Buffer als Nicht-Paladin nicht verwenden.",

	-- Mini buff thingy
	["Not setup"] = "Nicht eingestellt",
	["Smart buff"] = "Smart buff",
	["[C] Smart buff"] = "[C] Smart buff",
	["%d missing"] = "%d fehlt",
	["Not set"] = "Nicht festgelegt",

	-- Short hand identifiers
	["gmight"] = "M",
	["gkings"] = "K",
	["gsanct"] = "R",
	["gwisdom"] = "W",

	-- Slash commands
	["Slash commands"] = "Konsolenbefehle",
	["/pb assign - Shows the assignment interface."] = "/pb assign - Zeigt das Interface f\195\188r die Zuteilung.",
	["/pb config - Shows the configuration."] = "/pb config - Zeigt das Konfigurationsmen\195\188.",

	-- Configuration
	["General"] = "Allgemein",

	["Border color"] = "Randfarbe",
	["Background color"] = "Hintergrundfarbe",
	["Can rebuff color"] = "Kann-neu-buffen-Farbe",
	["Background color for the buff frame when you need to rebuff (Blessings below the set time) AND all players are within range."] = "Hintergrundfarbe f\195\188r das Buff-Fenster wenn du neu buffen sollst (Segen unterhalb der festgelegten Zeit) UND alle Spieler sich in Reichweite befinden.",

	["Cannot rebuff color"] = "Kann-nicht-neu-buffen-Farbe",
	["Background color when you need to rebuff (Blessings below the set time) BUT there are players out of range."] = "Hintergrundfarbe f\195\188r das Buff-Fenster wenn du neu buffen sollst (Segen unterhalb der festgelegten Zeit) ABER sich Spieler au\195\159erhalb der Reichweite befinden.",

	["Enable Pally Power support"] = "PallyPower-Support aktivieren",
	["Allows you to both send and receive assignments from Pally Power users."] = "Erlaubt das Senden und Empfangen der Zuteilungen an/von Spielern mit PallyPower.",

	["Wait for offline players before buffing"] = "Auf Offline-Spieler warten bevor gebufft wird",
	["Will not buff a class until all offline players are back online and in range."] = "Eine Klasse wird nicht gebufft bevor alle Spieler wieder online und in Reichweite sind.",

	["Single buff binding"] = "Tastenbelegung Kleine Segen",
	["Binding to use for smart buffing your assigned single blessings."] = "Tastenbelegung zum Durchf\195\188hren der dir zugewiesenen, einzelnen Segen.",

	["Greater buff binding"] = "Tastenbelegung Gro\195\159e Segen",
	["Binding to use for smart buffing your assigned greater blessings."] = "Tastenbelegung zum Durchf\195\188hren der dir zugewiesenen, gro\195\159en Segen.",

	["Assignment frame scale"] = "Skalierung Zuteilungs-Fenster",

	["Percentage of in range to buff"] = "Prozentsatz in Reichweite zum Buffen",
	["How much percent of the players should be in range before using a Greater Blessing on there class. 90% for example means at least 90% of the people on the class have to be in range."] = "Wieviel Prozent der Spieler in Reichweite sein m\195\188ssen bevor Gro\195\159e Segen auf die entsprechende Klasse ausgef\195\188hrt werden. 90% zum Beispiel bedeutet, dass 90% der Spieler dieser Klasse in Reichweite sein m\195\188ssen.",

	["Greater rebuff threshold"] = "Schwellwert Gro\195\159er Rebuff",
	["How many minutes should be left on a greater blessing before it's recasted."] = "Wieviele Minuten ein Gro\195\159er Segen noch laufen soll, bevor er erneut durchgebufft wird.",

	["Single rebuff threshold"] = "Schwellwert Einzelner Rebuff",
	["How many minutes should be left on a single blessing before it's recasted."] = "Wieviele Minuten ein einzelner Segen noch laufen soll, bevor er erneut gebufft wird.",

	["Require leader or assist to change assignments"] = "Erfordert Anf\195\188hrer- oder Assistenten-Status um Zuteilungen zu \195\164ndern",
	["Only accepts assignments from people who have either assist or leader, this does NOT apply to parties where any Paladin can change them."] = "Akzeptiert nur Zuteilungen von Leuten die entweder Anf\195\188hrer- oder Assistenten-Status besitzen, dies bezieht sich NICHT auf Gruppen wo jeder Paladin \195\132nderungen durchf\195\188hren kann.",

	["Enable mod inside"] = "Aktiviere Addon in",
	["Allows you to choose which scenarios this mod should be enabled in."] = "Erlaubt dir auszuw\195\164hlen in welchen Szenarien dieses Addon aktiviert werden soll.",
	["Everywhere else"] = "\195\156berall sonst",
	["Battlegrounds"] = "Schlachtfeldern",
	["Arenas"] = "Arena",
	["Raid instances"] = "Schlachtzug-Instanzen",
	["Party instances"] = "Gruppen-Instanzen",

	["Buff frame"] = "Buff-Fenster",

	["Columns"] = "Spalten",
	["How many columns to show, 1 for example will show a single straight line."] = "Wieviele Spalten angezeigt werden sollen. 1 zum Beispiel zeigt eine einzelne gerade Linie.",

	["Enable overall frame"] = "Gesamt-Fenster aktivieren",
	["Shows the lowest greater and single blessings for all classes, also lets you smart buff all classes through them."] = "Zeigt den niedrigsten gro\195\159en und kleinen Segen f\195\188r alle Klassen (also lets you smart buff all classes through them).",

	["Enable class status on buff frame"] = "Klassenstatus im Buff-Fenster aktivieren",
	["Shows each classes buff status and lets you manually buff them with the required blessings."] = "Zeigt den individuellen Buff-Status jeder Klasse und l\195\164sst dich diese manuell mit den entsprechenden Segen buffen.",

	["Locked"] = "Gesperrt",
	["You can move the buff frame by ALT + dragging the smart buff frame window while the frame is unlocked."] = "Du kannst das Buff-Fenster mittels ALT + Ziehen verschieben wenn das Fenster entsperrt ist.",
	["Grow up"] = "Nach oben anwachsen",
	["Scale"] = "Skalierung",

	["Hide in combat"] = "Im Kampf verstecken",
	["Hides the entire buff frame while you are in combat."] = "Versteckt das komplette Buff-Fenster wenn du dich im Kampf befindest.",

	-- Class map
	["PET"] = "Pets",
	["DRUID"] = "Druide",
	["DEATHKNIGHT"] = "Todesritter",
	["WARRIOR"] = "Krieger",
	["PALADIN"] = "Paladin",
	["ROGUE"] = "Schurke",
	["MAGE"] = "Magier",
	["PRIEST"] = "Priester",
	["WARLOCK"] = "Hexenmeister",
	["HUNTER"] = "J\195\164ger",
	["SHAMAN"] = "Schamane",

	-- GUI
	["None"] = "Keine",
	["Quick assign"] = "Schnellzuteilung",
	["Push assignments"] = "Zuteilungen verbreiten",
	["Single assignments"] = "Einzelne Zuteilungen",
	["Clear"] = "L\195\182schen",
	["Refresh"] = "Aktualisieren",
}, {__index = PaladinBufferLocals })