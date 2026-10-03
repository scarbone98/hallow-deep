extends RefCounted
## Every room of the caves. A room covers whole map cells (Game.CELL tiles
## each) at `cell` on the world grid; its map is one character per tile:
##
##   #  rock          C  chapel brick      =  ledge you can jump up through
##   ^  bone spikes   ~  mire muck         !  the abyss (falls forever)
##   R  hot root wall (needs fire)         B  cracked rock (break it)
##
## and things standing on that tile:
##
##   z  husk (shuffling spelunker)   p  pumpling (hopper)   b  bat
##   g  wraith (drifts through rock) w  werewolf (charger)  o  glowwisp (harmless)
##   W  Mags, the Mire Warden (boss) c  candy corn          H  heart vessel
##   S  lantern (rest and save)      h  Hollis              J  journal page
##   N  carved tablet                F  Rowan's flashlight
##
## Exits are gaps in the outer wall that line up with the room next door.
## tools/check_rooms.gd verifies every gap leads somewhere.
## `props` are pictures placed behind the rock: [name, tile x, tile y (feet)].
## `texts` are read in map order by J, N and h (top to bottom, left to right).

const ROOMS := {
	"surface": {
		"name": "Old Cemetery",
		"cell": Vector2i(0, 0), "size": Vector2i(2, 1), "theme": "surface",
		"map": [
			"........................................",
			"........................................",
			"........................................",
			"........................................",
			"........................................",
			"........................................",
			"........................................",
			"........................................",
			"........................N..J............",
			"#############################...########",
			"#############################...########",
			"#############################...########",
		],
		"props": [
			["cemetery_tree_big", 3, 9], ["tombstone_1", 9, 9], ["tombstone_3", 12, 9], ["statue", 16, 9],
			["tree_dead_1", 20, 9], ["tombstone_2", 22, 9], ["tombstone_4", 25, 9], ["mausoleum", 35, 9],
			["bush_large", 31, 9],
		],
		"texts": [
			["KEEP OUT. CAVE-IN, OCT 31 1987. FOUR SPELUNKERS NEVER RECOVERED. -- CEMETERY BOARD"],
			["ROWAN'S JOURNAL -- DAY 1",
			 "Found it. The crack behind the mausoleum BREATHES. Warm air, in and out, like something asleep.",
			 "Going down tonight. If you're reading this... don't tell my mom."],
		],
	},
	"shaft": {
		"name": "The Sinkhole",
		"cell": Vector2i(1, 1), "size": Vector2i(1, 2), "theme": "cave",
		"map": [
			"#########...########",
			"#######.......######",
			"######.........#####",
			"#####...........####",
			"####............####",
			"####.....===....####",
			"###.............####",
			"###..............###",
			"##===............###",
			"##...............###",
			"##....===........###",
			"##...............###",
			"##..........====.###",
			"##...............###",
			"###..............###",
			"###===...........###",
			"###..............###",
			"###.........===..###",
			"###..............###",
			"........===.........",
			"....................",
			"...............J....",
			"####################",
			"####################",
		],
		"props": [["crystals_big", 12, 22]],
		"texts": [
			["ROWAN'S JOURNAL -- DAY 1, LATER",
			 "The rope snapped. Not frayed. SNAPPED. Like something bit it.",
			 "The walls glow down here. Orange veins in the rock, like roots. They're warm. They pulse."],
		],
	},
	"shrine": {
		"name": "Hollis's Lantern",
		"cell": Vector2i(2, 2), "size": Vector2i(1, 1), "theme": "chapel",
		"map": [
			"####################",
			"####################",
			"###CCCCCCCCCCCCCC###",
			"##C..............C##",
			"##C..............C##",
			"#C...............C##",
			"#C................RR",
			"..................RR",
			"..................RR",
			"..........S...h...RR",
			"CCCCCCCCCCCCCCCCCCCC",
			"####################",
		],
		"props": [["gothic_window", 10, 10], ["torch_niche", 4, 10], ["torch_niche", 16, 10]],
		"texts": [],
	},
	"fungus": {
		"name": "Glowcap Hollow",
		"cell": Vector2i(-1, 2), "size": Vector2i(2, 1), "theme": "cave",
		"map": [
			"########################################",
			"###.......##############################",
			"###...H...##########.......#############",
			"###=======##########.......#######...###",
			"#...................................####",
			"#......................................#",
			"##............===..................====#",
			"....===.................................",
			"........................................",
			".....N.......z.......c.c..p....z........",
			"#######..##############~~~~####...######",
			"########################################",
		],
		"props": [["crystals_small", 30, 10], ["crystals_big", 9, 10]],
		"texts": [["THE SEED SLEEPS BELOW.", "ITS ROOTS REMEMBER THE SUN.", "ITS LIGHT FEEDS THE DEEP, AND THE DEEP FEEDS IT."]],
	},
	"roost": {
		"name": "The Roost",
		"cell": Vector2i(-2, 1), "size": Vector2i(1, 2), "theme": "cave",
		"map": [
			"####################",
			"####################",
			"####.....b.....#####",
			"###.............####",
			"##...............###",
			".................###",
			"..............b..###",
			"..................##",
			"#####..........#####",
			"#####.===..........#",
			"####...............#",
			"###.........b......#",
			"##...........====..#",
			"##.................#",
			"##.................#",
			"##.................#",
			"##...====..........#",
			"##.................#",
			"###................#",
			"......===...........",
			"....................",
			"....................",
			"####################",
			"####################",
		],
		"props": [["crystals_big", 15, 22], ["crystals_small", 6, 7]],
		"texts": [],
	},
	"mire": {
		"name": "The Mire",
		"cell": Vector2i(-4, 2), "size": Vector2i(2, 1), "theme": "mire",
		"map": [
			"########################################",
			"##########.......##########.......######",
			"######.....................o.........###",
			"####..................................##",
			"###...o..............................###",
			"##....................................##",
			"##.....................................#",
			"........===.........===.................",
			"............................J...........",
			"....p.......#####.........######.....p..",
			"#####~~~~~~~#####~~~~~~~~~######~~~~####",
			"########################################",
		],
		"props": [["swamp_tree", 2, 10], ["swamp_tree", 34, 10]],
		"texts": [
			["ROWAN'S JOURNAL -- DAY 2",
			 "There are people down here. Or there were.",
			 "They shuffle in the dark and hum the same note, over and over. One of them had a Scareathon wristband. 1987."],
		],
	},
	"lair": {
		"name": "Warden's Pit",
		"cell": Vector2i(-5, 2), "size": Vector2i(1, 1), "theme": "mire",
		"map": [
			"####################",
			"####################",
			"##..............####",
			"#................###",
			"#.................##",
			"#.................##",
			"#.................##",
			"#...................",
			"#...................",
			"#.......W...........",
			"####~~~########~~###",
			"####################",
		],
		"props": [["swamp_tree", 3, 10], ["swamp_tree", 16, 10], ["crystals_small", 9, 7]],
		"texts": [],
	},
	"gallery": {
		"name": "Sunken Chapel",
		"cell": Vector2i(-3, 1), "size": Vector2i(1, 1), "theme": "chapel",
		"map": [
			"####################",
			"####################",
			"##CCCCCCCCCCCCCCCC##",
			"#C...............C##",
			"#C................##",
			"#C..................",
			"#C..........g.......",
			"....................",
			"..........===.....CC",
			"...J....w.........CC",
			"CCCCCCCCCCCCCCCCCCCC",
			"####################",
		],
		"props": [["skull_pillar", 5, 10], ["altar", 14, 10]],
		"texts": [
			["ROWAN'S JOURNAL -- DAY 3",
			 "I can hear it beating. Under everything. Under ME.",
			 "It knows my name. It says Hallow Fields is real.",
			 "It says it just needs someone to carry it up."],
		],
	},
	"rim": {
		"name": "The Rim",
		"cell": Vector2i(-5, 1), "size": Vector2i(2, 1), "theme": "rim",
		"map": [
			"########################################",
			"########################################",
			"####.................................###",
			"###.................................####",
			"##..................................####",
			"#...................................####",
			"#....................................###",
			"#.......................................",
			"#.......................................",
			"#.....................F.........N.......",
			"#.....................##################",
			"#!!!!!!!!!!!!!!!!!!!!!##################",
		],
		"props": [["crystals_small", 30, 6], ["altar", 34, 10]],
		"texts": [
			["Rowan's flashlight. Still warm. Still on."],
			["HERE THE ROOTS DRINK.", "THE SEED CALLS FOR A CARRIER.", "NONE HAVE CLIMBED BACK."],
		],
	},
}

## The room covering a map cell, or "".
static func at_cell(cell: Vector2i) -> String:
	for id in ROOMS:
		var r: Dictionary = ROOMS[id]
		var c: Vector2i = r.cell
		var s: Vector2i = r.size
		if cell.x >= c.x and cell.y >= c.y and cell.x < c.x + s.x and cell.y < c.y + s.y:
			return id
	return ""

## The room's rectangle in world pixels.
static func rect(id: String) -> Rect2:
	var r: Dictionary = ROOMS[id]
	return Rect2(Vector2(r.cell) * Game.CELL_PX, Vector2(r.size) * Game.CELL_PX)
