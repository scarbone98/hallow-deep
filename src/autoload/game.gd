extends Node
## Save state and controls. Everything the player keeps between rooms and
## sessions lives here: abilities, health, candy, what's been picked up or
## beaten, which map cells were visited and where they last rested.

const TILE := 16
const CELL := Vector2i(20, 12)  # one map cell, in tiles (320x192 px)
const CELL_PX := Vector2(CELL.x * TILE, CELL.y * TILE)
const SAVE_PATH := "user://hallow_deep_save.json"

signal changed  # hp, candy or abilities moved; the HUD redraws

var hp := 5
var max_hp := 5
var character := ""  # "you" (your avatar), a kid ("alex", "joe", "jon", "matt") or "" (not picked yet)
var candy := 0
var abilities := {}  # "double_jump": true
var taken := {}  # pickups and broken blocks, by "<room>:<x>,<y>"
var flags := {}  # story beats: "intro", "met_hollis", "warden_dead"...
var visited := {}  # "<cx>,<cy>" -> true
var save_room := "surface"
var save_pos := Vector2(40, 150)
var deaths := 0
var play_time := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_add_inputs()
	load_game()

func _process(delta: float) -> void:
	if not get_tree().paused:
		play_time += delta

# ---------------------------------------------------------------- controls

func _key(code: int) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	return e

func _pad(button: int) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = button
	return e

func _axis(axis: int, value: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.axis = axis
	e.axis_value = value
	return e

func _add_inputs() -> void:
	var map := {
		"left": [_key(KEY_LEFT), _key(KEY_A), _pad(JOY_BUTTON_DPAD_LEFT), _axis(JOY_AXIS_LEFT_X, -1.0)],
		"right": [_key(KEY_RIGHT), _key(KEY_D), _pad(JOY_BUTTON_DPAD_RIGHT), _axis(JOY_AXIS_LEFT_X, 1.0)],
		"up": [_key(KEY_UP), _key(KEY_W), _pad(JOY_BUTTON_DPAD_UP), _axis(JOY_AXIS_LEFT_Y, -1.0)],
		"down": [_key(KEY_DOWN), _key(KEY_S), _pad(JOY_BUTTON_DPAD_DOWN), _axis(JOY_AXIS_LEFT_Y, 1.0)],
		"jump": [_key(KEY_Z), _key(KEY_SPACE), _key(KEY_K), _pad(JOY_BUTTON_A)],
		"attack": [_key(KEY_X), _key(KEY_J), _pad(JOY_BUTTON_X)],
		"map": [_key(KEY_M), _key(KEY_TAB), _pad(JOY_BUTTON_BACK)],
		"confirm": [_key(KEY_ENTER), _key(KEY_Z), _key(KEY_SPACE), _key(KEY_X), _pad(JOY_BUTTON_A)],
	}
	for action in map:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.3)
		for e in map[action]:
			InputMap.action_add_event(action, e)

# ---------------------------------------------------------------- state

func has(ability: String) -> bool:
	return abilities.get(ability, false)

func grant(ability: String) -> void:
	abilities[ability] = true
	changed.emit()

func add_candy(n: int) -> void:
	candy += n
	changed.emit()

func heal_full() -> void:
	hp = max_hp
	changed.emit()

func hurt(n: int) -> void:
	hp = max(0, hp - n)
	changed.emit()

func raise_max_hp() -> void:
	max_hp += 1
	hp = max_hp
	changed.emit()

func visit(cell: Vector2i) -> void:
	visited["%d,%d" % [cell.x, cell.y]] = true

func was_visited(cell: Vector2i) -> bool:
	return visited.has("%d,%d" % [cell.x, cell.y])

func new_game() -> void:
	hp = 5
	max_hp = 5
	candy = 0
	abilities = {}
	taken = {}
	flags = {}
	visited = {}
	save_room = "surface"
	save_pos = Vector2(40, 150)
	deaths = 0
	play_time = 0.0
	changed.emit()

func has_save() -> bool:
	return flags.get("intro", false)

## Called at a lantern: remember this spot and write the save.
func rest_at(room: String, pos: Vector2) -> void:
	save_room = room
	save_pos = pos
	heal_full()
	save_game()

func save_game() -> void:
	var data := {
		"v": 1, "max_hp": max_hp, "candy": candy, "abilities": abilities, "taken": taken,
		"flags": flags, "visited": visited, "save_room": save_room,
		"save_pos": [save_pos.x, save_pos.y], "deaths": deaths, "play_time": play_time,
		"character": character,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))

func load_game() -> void:
	if Bridge.flags().has("fresh"):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not f:
		return
	var d = JSON.parse_string(f.get_as_text())
	if not d is Dictionary:
		return
	max_hp = int(d.get("max_hp", 5))
	hp = max_hp
	candy = int(d.get("candy", 0))
	abilities = d.get("abilities", {})
	taken = d.get("taken", {})
	flags = d.get("flags", {})
	visited = d.get("visited", {})
	save_room = str(d.get("save_room", "surface"))
	var p: Array = d.get("save_pos", [40, 150])
	save_pos = Vector2(p[0], p[1])
	deaths = int(d.get("deaths", 0))
	play_time = float(d.get("play_time", 0.0))
	character = str(d.get("character", ""))
