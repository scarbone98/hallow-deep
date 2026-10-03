class_name World
extends Node2D
## The caves: loads rooms around the player, moves between them, runs hazards,
## pickups, conversations and the story beats.

const Rooms := preload("res://src/world/rooms.gd")
const Props := preload("res://src/world/props.gd")
const T := 16

const LIGHT := {
	"surface": Color(0.62, 0.58, 0.78),
	"cave": Color(0.46, 0.41, 0.58),
	"chapel": Color(0.5, 0.44, 0.62),
	"mire": Color(0.42, 0.5, 0.44),
	"rim": Color(0.55, 0.36, 0.42),
}
## How loud the heartbeat is in each room: it grows as you go deeper.
const BEAT := {"surface": 0.0, "shaft": 0.12, "shrine": 0.08, "fungus": 0.22, "roost": 0.3,
	"mire": 0.35, "lair": 0.4, "gallery": 0.6, "rim": 1.0}

var hud: Hud
var player: Player
var camera: Camera2D
var shade: CanvasModulate
var back_root: Node2D
var room_root: Node2D
var fx_root: Node2D
var room_id := ""
var room: Dictionary
var room_rect: Rect2
var tiles: Array = []  # mutable copy of the map rows (breakables vanish)
var tickers: Array = []
var boss: Warden
var gate: Node2D
var busy := false  # mid-transition or cutscene
var shake_amt := 0.0
var shake_t := 0.0

func _ready() -> void:
	shade = CanvasModulate.new()
	add_child(shade)
	back_root = Node2D.new()
	back_root.z_index = -10
	add_child(back_root)
	room_root = Node2D.new()
	add_child(room_root)
	fx_root = Node2D.new()
	fx_root.z_index = 5
	add_child(fx_root)
	player = Player.new()
	player.world = self
	player.z_index = 2
	add_child(player)
	player.died.connect(_on_died)
	Bridge.look_loaded.connect(func(look): player.set_look(look))
	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 9.0
	add_child(camera)
	camera.make_current()
	hud = Hud.new()
	hud.world = self
	add_child(hud)
	Sfx.start_ambience()

## Starts at the last lantern (or the cemetery on a new game).
func start(room_name := "", pos := Vector2.INF) -> void:
	var id := room_name if room_name != "" else Game.save_room
	var p := pos if pos != Vector2.INF else Game.save_pos
	if room_name != "" and pos == Vector2.INF:
		p = _first_floor(id)
	Game.heal_full()
	player.global_position = p
	player.velocity = Vector2.ZERO
	player.dead = false
	_load(id)
	camera.global_position = player.global_position
	camera.reset_smoothing()

func _first_floor(id: String) -> Vector2:
	var r: Dictionary = Rooms.ROOMS[id]
	var origin := Rooms.rect(id).position
	for y in range(1, r.map.size()):
		for x in range(1, r.map[0].length()):
			if Terrain.is_solid_char(r.map[y][x]) and not Terrain.is_solid_char(r.map[y - 1][x]) and not Terrain.is_solid_char(r.map[y - 2][x]):
				return origin + Vector2(x * T + 8, y * T)
	return origin + Vector2(40, 40)

# ---------------------------------------------------------------- rooms

func _load(id: String) -> void:
	for c in room_root.get_children():
		c.queue_free()
	for c in back_root.get_children():
		c.queue_free()
	for c in fx_root.get_children():
		c.queue_free()
	tickers.clear()
	boss = null
	gate = null
	room_id = id
	room = Rooms.ROOMS[id]
	room_rect = Rooms.rect(id)
	tiles = room.map.duplicate()
	shade.color = LIGHT.get(room.theme, LIGHT.cave)
	Sfx.beat_level = BEAT.get(id, 0.2)
	camera.limit_left = int(room_rect.position.x)
	camera.limit_top = int(room_rect.position.y)
	camera.limit_right = int(room_rect.end.x)
	camera.limit_bottom = int(room_rect.end.y)

	var built := Terrain.build(id, room)
	var origin := room_rect.position
	_backdrop()
	var holder := Node2D.new()
	holder.position = origin
	room_root.add_child(holder)
	for p in room.get("props", []):
		var s := Props.make(p[0], p[1], p[2])
		s.z_index = -1
		holder.add_child(s)
	var ground := Sprite2D.new()
	ground.texture = ImageTexture.create_from_image(built.image)
	ground.centered = false
	holder.add_child(ground)
	_collision(holder, built.solids, 1, false)
	_collision(holder, built.oneway, 8, true)
	_spawn_things(holder)
	var newly := false
	for y in room.size.y:
		for x in room.size.x:
			var cell: Vector2i = room.cell + Vector2i(x, y)
			if not Game.was_visited(cell):
				newly = true
			Game.visit(cell)
	if newly:
		hud.show_area(room.name)
	if id == "rim":
		_rim_heart(holder)

func _backdrop() -> void:
	if room.theme == "surface":
		var sky := Parallax2D.new()
		sky.scroll_scale = Vector2(0.1, 0.1)
		sky.repeat_size = Vector2(384, 0)
		sky.repeat_times = 3
		var s := Sprite2D.new()
		s.texture = load("res://assets/cc0/cemetery_background.png")
		s.centered = false
		s.position = Vector2(-32, -24)
		sky.add_child(s)
		back_root.add_child(sky)
		var yard := Parallax2D.new()
		yard.scroll_scale = Vector2(0.4, 1.0)
		yard.repeat_size = Vector2(384, 0)
		yard.repeat_times = 3
		var g := Sprite2D.new()
		g.texture = load("res://assets/cc0/cemetery_graveyard.png")
		g.centered = false
		g.position = Vector2(0, 154 - 123)
		g.modulate = Color(0.55, 0.5, 0.7)
		yard.add_child(g)
		back_root.add_child(yard)
		return
	var wall := Parallax2D.new()
	wall.scroll_scale = Vector2(0.5, 0.5)
	wall.repeat_size = Vector2(320, 192)
	wall.repeat_times = 3
	var s := Sprite2D.new()
	s.texture = ImageTexture.create_from_image(Terrain.back_wall(room.theme, 320, 192))
	s.centered = false
	s.position = room_rect.position * 0.5
	wall.add_child(s)
	back_root.add_child(wall)
	if room.theme == "chapel":
		var ruins := Parallax2D.new()
		ruins.scroll_scale = Vector2(0.75, 1.0)
		ruins.repeat_size = Vector2(352, 0)
		ruins.repeat_times = 3
		var r := Sprite2D.new()
		r.texture = load("res://assets/cc0/grotto_far.png")
		r.region_enabled = true
		r.region_rect = Rect2(0, 128, 352, 112)
		r.centered = false
		r.position = Vector2(room_rect.position.x * 0.75, room_rect.end.y - 112 - 24)
		r.modulate = Color(0.5, 0.45, 0.65)
		ruins.add_child(r)
		back_root.add_child(ruins)

func _collision(holder: Node2D, rects: Array, layer: int, one_way: bool) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = layer
	body.collision_mask = 0
	for r: Rect2i in rects:
		var cs := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		if one_way:
			for x in r.size.x:
				var oc := CollisionShape2D.new()
				var os := RectangleShape2D.new()
				os.size = Vector2(T, 4)
				oc.shape = os
				oc.position = Vector2((r.position.x + x) * T + T / 2.0, r.position.y * T + 2)
				oc.one_way_collision = true
				body.add_child(oc)
			continue
		shape.size = Vector2(r.size) * T
		cs.shape = shape
		cs.position = Vector2(r.position) * T + shape.size / 2.0
		body.add_child(cs)
	holder.add_child(body)

func _spawn_things(holder: Node2D) -> void:
	var text_i := 0
	var texts: Array = room.get("texts", [])
	for y in tiles.size():
		for x in tiles[y].length():
			var c: String = tiles[y][x]
			var at := room_rect.position + Vector2(x * T + 8, (y + 1) * T)
			var key := "%s:%d,%d" % [room_id, x, y]
			match c:
				"z", "p", "b", "g", "w", "o":
					var kinds := {"z": "husk", "p": "pumpling", "b": "bat", "g": "wraith", "w": "werewolf", "o": "wisp"}
					var e := Enemy.new()
					e.position = at if not (kinds[c] in ["bat", "wraith", "wisp"]) else at - Vector2(0, 8)
					if c == "b":
						e.position = Vector2(at.x, room_rect.position.y + _ceiling_above(x, y) * T + 8)
					room_root.add_child(e)
					e.setup(kinds[c], self)
				"c":
					_thing("candy", at - Vector2(0, 6))
				"H":
					if not Game.taken.has(key):
						_thing("heart", at).key = key
				"S":
					_thing("lantern", at)
				"h":
					_thing("hollis", at)
				"J", "N", "F":
					var th := _thing({"J": "journal", "N": "tablet", "F": "flashlight"}[c], at)
					th.key = key
					if text_i < texts.size():
						th.text = texts[text_i]
					text_i += 1
				"W":
					if not Game.flags.get("warden_dead", false):
						boss = Warden.new()
						boss.position = at
						room_root.add_child(boss)
						boss.setup(self, room_rect)
				"R":
					var s := Sprite2D.new()
					s.texture = ImageTexture.create_from_image(Terrain.root_tile(x, y))
					s.centered = false
					s.position = Vector2(x * T, y * T)
					holder.add_child(s)
					var tw := s.create_tween().set_loops()
					tw.tween_property(s, "modulate", Color(2.4, 1.9, 1.6), 0.6)
					tw.tween_property(s, "modulate", Color(1.4, 1.1, 1.0), 0.6)
					_collision(holder, [Rect2i(x, y, 1, 1)], 1, false)
				"B":
					if Game.taken.has(key):
						tiles[y] = tiles[y].substr(0, x) + "." + tiles[y].substr(x + 1)
					else:
						var b := Breakable.new()
						b.setup(self, x, y, key, room.theme)
						holder.add_child(b)
	if room.theme in ["cave", "mire", "rim"]:
		_fungus(holder)

func _ceiling_above(x: int, y: int) -> int:
	var yy := y
	while yy > 0 and not Terrain.is_solid_char(tiles[yy - 1][x]):
		yy -= 1
	return yy

func _thing(kind: String, at: Vector2) -> Thing:
	var th := Thing.new()
	th.position = at
	room_root.add_child(th)
	th.setup(kind, self)
	return th

## Glowcaps: little luminous mushrooms on lit rock tops; a few carry light.
func _fungus(holder: Node2D) -> void:
	var tex := _glowcap_texture()
	var lights := 0
	var tint := Color(2.2, 2.6, 2.4) if room.theme != "rim" else Color(2.8, 1.8, 1.2)
	for y in range(1, tiles.size()):
		for x in tiles[y].length():
			if tiles[y][x] != "#" or Terrain.is_solid_char(tiles[y - 1][x]) or tiles[y - 1][x] != ".":
				continue
			var h := Terrain._h(x * 7 + 3, y * 13 + room_id.length())
			if h > 0.16:
				continue
			var s := Sprite2D.new()
			s.texture = tex
			s.position = Vector2(x * T + int(h * 60.0) % 10 + 3, y * T - 3)
			s.flip_h = h < 0.08
			s.modulate = tint if room.theme != "mire" else Color(2.4, 2.8, 1.4)
			holder.add_child(s)
			if lights < 7 and h < 0.1:
				lights += 1
				var l := PointLight2D.new()
				l.texture = Fx.light_texture(56, Color(0.4, 1.0, 0.85) if room.theme == "cave" else (Color(0.7, 1.0, 0.4) if room.theme == "mire" else Color(1.0, 0.6, 0.3)))
				l.energy = 0.7
				s.add_child(l)

func _glowcap_texture() -> Texture2D:
	var rows := [
		"..aa....",
		".abba.a.",
		"abbbbaba",
		"..s...s.",
		"..s...s.",
	]
	var img := Image.create(8, 5, false, Image.FORMAT_RGBA8)
	var pal := {"a": Color("#2a7f74"), "b": Color("#6fe3c6"), "s": Color("#3a3248")}
	for y in rows.size():
		for x in 8:
			var ch: String = rows[y][x]
			if pal.has(ch):
				img.set_pixel(x, y, pal[ch])
	return ImageTexture.create_from_image(img)

func _rim_heart(holder: Node2D) -> void:
	var heart := AnimatedSprite2D.new()
	heart.sprite_frames = Fx.frames("heartbeat", 8, 8.0)
	heart.play("default")
	heart.scale = Vector2(2, 2)
	heart.position = Vector2(15 * T, 11 * T + 6)
	heart.z_index = -2
	heart.modulate = Color(0.95, 0.62, 0.66)
	holder.add_child(heart)
	var l := PointLight2D.new()
	l.texture = Fx.light_texture(256, Color(1.0, 0.25, 0.2))
	l.energy = 1.2
	l.position = Vector2(15 * T, 10 * T)
	holder.add_child(l)
	var tw := l.create_tween().set_loops()
	tw.tween_property(l, "energy", 2.0, 0.12)
	tw.tween_property(l, "energy", 1.0, 0.25)
	tw.tween_property(l, "energy", 1.7, 0.12)
	tw.tween_property(l, "energy", 0.9, 0.76)

# ---------------------------------------------------------------- queries

func _tile_at(p: Vector2) -> String:
	if not room_rect.has_point(p):
		return "#"
	var local := p - room_rect.position
	var tx := int(local.x / T)
	var ty := int(local.y / T)
	if ty < 0 or ty >= tiles.size() or tx < 0 or tx >= tiles[ty].length():
		return "#"
	return tiles[ty][tx]

func solid_at(p: Vector2) -> bool:
	var c := _tile_at(p)
	return c in "#CRB"

## "spike", "muck", "abyss" or "".
func hazard_at(p: Vector2) -> String:
	var c := _tile_at(p)
	var within := fposmod(p.y - room_rect.position.y, T)
	match c:
		"^":
			return "spike" if within >= 7 else ""
		"~":
			return "muck" if within >= 3 else ""
		"!":
			return "abyss"
	return ""

func hazard_in(r: Rect2) -> String:
	for p in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.get_center(),
			Vector2(r.get_center().x, r.end.y)]:
		var h := hazard_at(p)
		if h != "":
			return h
	return ""

func hazard_under(p: Player) -> bool:
	var f := p.global_position
	return hazard_at(f + Vector2(-6, 6)) != "" or hazard_at(f + Vector2(6, 6)) != ""

# ---------------------------------------------------------------- per frame

func _physics_process(delta: float) -> void:
	if busy or player.dead:
		return
	_check_exit()
	if busy:
		return
	var h := hazard_in(player.rect().grow(-2))
	if h != "" and not player.frozen:
		player.hazard(1 if h != "abyss" else 1)
	for th in get_tree().get_nodes_in_group("pickups"):
		if th.rect().intersects(player.rect()):
			_collect(th)
	if Input.is_action_just_pressed("up") and player.is_on_floor() and not player.frozen and player.swing_t <= 0.0:
		_interact()
	if boss and boss.state == "dormant" and player.global_position.x < room_rect.position.x + 15 * T:
		_start_boss()

func _process(delta: float) -> void:
	for i in range(tickers.size() - 1, -1, -1):
		var tk: Array = tickers[i]
		if not is_instance_valid(tk[1]) or not tk[0].call(delta):
			if is_instance_valid(tk[1]):
				tk[1].queue_free()
			tickers.remove_at(i)
	var target := player.global_position + Vector2(player.facing * 16, -20)
	camera.global_position = target
	if shake_t > 0.0:
		shake_t -= delta
		camera.offset = Vector2(randf_range(-shake_amt, shake_amt), randf_range(-shake_amt, shake_amt)).round()
	else:
		camera.offset = Vector2.ZERO

func _check_exit() -> void:
	var p := player.global_position
	var mid := p + Vector2(0, -10)
	if room_rect.has_point(mid):
		return
	var cell := Vector2i(floori(mid.x / Game.CELL_PX.x), floori(mid.y / Game.CELL_PX.y))
	var next := Rooms.at_cell(cell)
	if next == "" or next == room_id:
		# No room there: the edge is a wall (or the sky).
		player.global_position.x = clamp(p.x, room_rect.position.x + 5, room_rect.end.x - 5)
		if p.y > room_rect.end.y + 20:
			player.hazard(1)
		return
	_go(next)

func _go(next: String) -> void:
	busy = true
	get_tree().paused = true
	await hud.fade_to(1.0, 0.1)
	_load(next)
	camera.global_position = player.global_position
	camera.reset_smoothing()
	# Coming up through a floor gap: give a little hop so you clear the lip.
	if player.velocity.y < 0.0:
		player.velocity.y = min(player.velocity.y, -240.0)
	get_tree().paused = false
	await hud.fade_to(0.0, 0.15)
	busy = false

# ---------------------------------------------------------------- helpers for actors

func add_effect(n: Node) -> void:
	fx_root.add_child(n)

func add_ticker(f: Callable, owner_node: Node) -> void:
	tickers.append([f, owner_node])

func drop_candy(at: Vector2, n: int) -> void:
	for i in n:
		var th := _thing("candy", at)
		th.vel = Vector2(randf_range(-70, 70), randf_range(-170, -90))

func shake(amount: float, time: float) -> void:
	shake_amt = max(shake_amt if shake_t > 0.0 else 0.0, amount)
	shake_t = max(shake_t, time)

func hitstop(time: float) -> void:
	Engine.time_scale = 0.05
	await get_tree().create_timer(time, true, false, true).timeout
	Engine.time_scale = 1.0

func fade_flash() -> void:
	hud.fade.color = Color(1, 1, 1, 0.5)
	var t := create_tween()
	t.tween_property(hud.fade, "color", Color(0, 0, 0, 0), 0.3)

# ---------------------------------------------------------------- story

func _collect(th: Thing) -> void:
	match th.kind:
		"candy":
			Game.add_candy(1)
			Sfx.play("candy")
			th.queue_free()
		"heart":
			th.queue_free()
			Game.taken[th.key] = true
			Game.raise_max_hp()
			Sfx.play("power")
			await hud.say(["HEART VESSEL", "Something in the dark wanted you to live a little longer. Max health up."])
			Game.save_game()
		"ability":
			th.queue_free()
			Game.grant("double_jump")
			Sfx.play("power")
			shake(2.0, 0.5)
			await hud.say(["BAT WINGS", "Something leathery unfolds from your back. It doesn't feel like yours.",
				"Press JUMP again in the air to flap."])
			Game.save_game()

func _interact() -> void:
	var best: Thing = null
	for th in get_tree().get_nodes_in_group("interact"):
		if th.rect().grow(8).intersects(player.rect()):
			best = th
	if best == null:
		# A root wall right in front of you?
		var ahead := player.global_position + Vector2(player.facing * 12, -10)
		if _tile_at(ahead) == "R":
			await hud.say(["A root as thick as a coffin. It's hot, and it's pulsing.", "Fire might get through it. Nothing you're carrying would."])
		return
	player.velocity.x = 0.0
	match best.kind:
		"lantern":
			Sfx.play("rest")
			Game.rest_at(room_id, best.global_position + Vector2(-14, 0))
			fade_flash()
			await hud.say(["The lantern's light settles over you. Nothing down here can touch you while it burns.", "(Rested. Your progress is saved.)"])
		"hollis":
			await _hollis()
		"journal":
			Sfx.play("page")
			await hud.say(best.text.slice(1), best.text[0])
		"tablet":
			await hud.say(best.text, "CARVED STONE")
		"flashlight":
			await _ending(best)

func _hollis() -> void:
	var f := Game.flags
	if not f.get("met_hollis", false):
		f.met_hollis = true
		await hud.say([
			"Don't scream. Screaming draws the hungry ones.",
			"Name's Hollis. Came down in '87 with my partner, Mags. Looking for Hallow Fields, same as every fool with a flashlight.",
			"See those orange veins in the rock? Roots. Every one of 'em runs down to one thing. The Hallowseed.",
			"The first jack-o'-lantern seed. Everything down here lives off its light. The mushrooms. The bats. The folks who wandered in and never wandered out.",
			"A kid came through three nights back. Ran right past me. Following the beat.",
			"Your friend? ...Then hear me. Mags went west into the mire. The muck took her, and it KEPT her.",
			"If you go that way, don't let her get her hands on you.",
			"Rest by the lantern. It's the only light down here that isn't hungry.",
		], "HOLLIS")
	elif f.get("warden_dead", false) and not f.get("hollis_after", false):
		f.hollis_after = true
		await hud.say([
			"...I felt it. She's quiet now.",
			"Forty years I couldn't go to her. Thank you.",
			"The kid went up through the roost. Toward the old chapel, and the Rim past it.",
			"Whatever's beating down there, it's louder tonight. Go. Find your friend before the seed does.",
		], "HOLLIS")
	elif f.get("warden_dead", false):
		await hud.say(["The Rim's past the chapel. Don't look down too long. It looks back."], "HOLLIS")
	else:
		await hud.say(["West, through the mire. Keep your feet out of the muck, and your back to the light."], "HOLLIS")
	Game.save_game()

func _start_boss() -> void:
	busy = true
	player.velocity.x = 0.0
	gate = Node2D.new()
	gate.position = room_rect.position
	room_root.add_child(gate)
	for y in [7, 8, 9]:
		tiles[y] = tiles[y].substr(0, 19) + "#"
		var s := Sprite2D.new()
		s.texture = ImageTexture.create_from_image(Terrain.cracked_tile(room.theme))
		s.centered = false
		s.position = Vector2(19 * T, y * T)
		gate.add_child(s)
	_collision(gate, [Rect2i(19, 7, 1, 3)], 1, false)
	Sfx.play("gate")
	shake(3.0, 0.4)
	boss.wake()
	await get_tree().create_timer(1.0).timeout
	await hud.say(["The muck heaves. Something wearing a miner's lamp drags itself up out of it.",
		"Its mouth opens. What comes out is Hollis's name, over and over, like a scratched record."])
	hud.boss_bar(1.0)
	busy = false
	boss.defeated.connect(_boss_down)

func _boss_down() -> void:
	Game.flags.warden_dead = true
	if gate:
		for y in [7, 8, 9]:
			tiles[y] = tiles[y].substr(0, 19) + "."
		gate.queue_free()
		Sfx.play("gate")
	var orb := _thing("ability", boss.global_position)
	orb.key = "lair:wings"
	await hud.say(["Mags sinks back into the muck. Her lamp flickers once... and goes out.",
		"Something is left where she stood, twitching."])
	Game.save_game()

func _ending(th: Thing) -> void:
	if Game.flags.get("ending", false):
		await hud.say(["Rowan's flashlight. Down below, the beating hasn't stopped."])
		return
	busy = true
	player.frozen = true
	Sfx.play("page")
	await hud.say(th.text, "")
	Sfx.beat_level = 1.0
	shake(2.0, 2.5)
	await get_tree().create_timer(1.2).timeout
	Sfx.play("whisper")
	await hud.say(["{name}...", "...you came for your friend...", "...rowan is with me now. rowan is warm...",
		"...come down. carry me up into the open air...", "...and the fields will wake."], "", "whisper")
	shake(5.0, 1.5)
	Sfx.play("roar", 0.5)
	await hud.fade_to(1.0, 1.4)
	Game.flags.ending = true
	Game.save_game()
	await hud.say(["The heartbeat doesn't stop.", "It follows you into your dreams.",
		"TO BE CONTINUED", "Thanks for playing the first slice of HALLOW DEEP.\n\nThe Hallowseed is waiting."], "", "card")
	player.frozen = false
	await hud.fade_to(0.0, 1.0)
	busy = false

func _on_died() -> void:
	busy = true
	Game.deaths += 1
	Sfx.play("roar", 0.4)
	player.sprite.play("hurt")
	var t := create_tween()
	t.tween_property(player, "rotation", PI / 2.0 * -player.facing, 0.4)
	await t.finished
	await hud.fade_to(1.0, 0.8)
	player.rotation = 0.0
	var lines := ["The roots find you in the dark. They are so warm.", "Something hums the same note, over and over.", "...and then the lantern light pulls you back."]
	await hud.say([lines[0], lines[2]] if Game.deaths % 2 == 1 else [lines[1], lines[2]], "", "card")
	Game.load_game()
	start()
	player.invuln = 1.0
	await hud.fade_to(0.0, 0.6)
	busy = false


class Breakable extends Node2D:
	## Cracked rock: a couple of hits and it crumbles for good.
	var world
	var tx := 0
	var ty := 0
	var key := ""
	var hp := 2
	var body: StaticBody2D

	func setup(w, x: int, y: int, k: String, theme: String) -> void:
		world = w
		tx = x
		ty = y
		key = k
		position = Vector2(x * 16, y * 16)
		var s := Sprite2D.new()
		s.texture = ImageTexture.create_from_image(Terrain.cracked_tile(theme))
		s.centered = false
		add_child(s)
		body = StaticBody2D.new()
		body.collision_layer = 1
		var cs := CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = Vector2(16, 16)
		cs.shape = r
		cs.position = Vector2(8, 8)
		body.add_child(cs)
		add_child(body)
		add_to_group("hittable")

	func hit_rect() -> Rect2:
		return Rect2(global_position, Vector2(16, 16))

	func take_hit(_d: int, _from: Vector2) -> void:
		hp -= 1
		Sfx.play("thud", 1.4)
		Fx.dust(world, global_position + Vector2(8, 8), 6)
		if hp <= 0:
			Game.taken[key] = true
			world.tiles[ty] = world.tiles[ty].substr(0, tx) + "." + world.tiles[ty].substr(tx + 1)
			Fx.poof(world, global_position + Vector2(8, 8), 0.4)
			queue_free()
