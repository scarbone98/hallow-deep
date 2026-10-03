class_name Thing
extends Node2D
## Pickups and things you can read or use. Origin at the tile's floor.
##   candy, heart (vessel), ability   -> picked up by touching
##   lantern, hollis, journal, tablet, flashlight -> press UP nearby

var world
var kind := ""
var key := ""  # remembers one-off pickups: "<room>:<x>,<y>"
var text: Array = []  # lines for journal/tablet
var ability := ""
var vel := Vector2.ZERO
var t := 0.0
var prompt: Label
var sprite: Node2D

func setup(k: String, w) -> void:
	kind = k
	world = w
	t = randf() * 3.0
	match kind:
		"candy":
			var a := AnimatedSprite2D.new()
			a.sprite_frames = Fx.frames("candy_corn", 6, 8.0)
			a.play("default")
			a.scale = Vector2(0.5, 0.5)
			sprite = a
		"heart":
			var s := Sprite2D.new()
			s.texture = load("res://assets/sprites/heart.png")
			s.position = Vector2(0, -10)
			sprite = s
			_glow(Color(1.0, 0.3, 0.35), 80)
		"ability":
			var s := Sprite2D.new()
			s.texture = load("res://assets/sprites/bat_skill.png")
			s.scale = Vector2(0.5, 0.5)
			s.position = Vector2(0, -18)
			sprite = s
			_glow(Color(0.8, 0.5, 1.0), 140)
		"lantern":
			var a := AnimatedSprite2D.new()
			a.sprite_frames = Fx.frames("street_lamp", 4, 6.0)
			a.play("default")
			a.position = Vector2(0, -32)
			sprite = a
			var l := _glow(Color(1.0, 0.75, 0.4), 220)
			l.position = Vector2(0, -44)
		"hollis":
			var a := AnimatedSprite2D.new()
			a.sprite_frames = Fx.frames("ghost", 6, 6.0)
			a.play("default")
			a.position = Vector2(0, -18)
			a.modulate = Color(1.0, 0.92, 0.75, 0.85)
			sprite = a
			_glow(Color(1.0, 0.9, 0.7), 70)
		"tablet":
			var s := Sprite2D.new()
			s.texture = load("res://assets/sprites/grave_2.png")
			s.position = Vector2(0, -16)
			s.modulate = Color(0.85, 0.8, 1.0)
			sprite = s
		"journal":
			var s := Sprite2D.new()
			s.texture = _page_texture()
			s.position = Vector2(0, -8)
			sprite = s
			_glow(Color(1.0, 0.95, 0.8), 48)
		"flashlight":
			var s := Sprite2D.new()
			s.texture = _flashlight_texture()
			s.position = Vector2(0, -3)
			sprite = s
			var l := _glow(Color(1.0, 1.0, 0.85), 160)
			l.position = Vector2(-30, -4)
	add_child(sprite)
	if kind in ["lantern", "hollis", "journal", "tablet", "flashlight"]:
		add_to_group("interact")
		prompt = Label.new()
		prompt.text = "^"
		prompt.add_theme_font_override("font", Ui.font())
		prompt.add_theme_font_size_override("font_size", 8)
		prompt.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.08))
		prompt.add_theme_constant_override("outline_size", 3)
		prompt.position = Vector2(-4, -60 if kind == "lantern" else -44)
		prompt.visible = false
		add_child(prompt)
	else:
		add_to_group("pickups")

func _glow(col: Color, size: int) -> PointLight2D:
	var l := PointLight2D.new()
	l.texture = Fx.light_texture(size, col)
	l.energy = 0.9
	add_child(l)
	return l

func rect() -> Rect2:
	return Rect2(global_position + Vector2(-10, -24), Vector2(20, 24))

func _process(delta: float) -> void:
	t += delta
	match kind:
		"candy":
			var p: Player = world.player
			var to := p.global_position + Vector2(0, -10) - global_position
			if to.length() < 40.0:
				vel = vel.move_toward(to.normalized() * 200.0, 900.0 * delta)
			else:
				vel.y = min(vel.y + 500.0 * delta, 200.0)
				vel.x = move_toward(vel.x, 0.0, 120.0 * delta)
			var next := position + vel * delta
			if vel.y > 0.0 and world.solid_at(next) and to.length() >= 40.0:
				vel = Vector2(vel.x * 0.5, -vel.y * 0.35 if vel.y > 60.0 else 0.0)
			else:
				position = next
		"heart", "ability", "journal":
			sprite.position.y = (-10 if kind != "ability" else -18) + sin(t * 2.5) * 2.0
		"lantern":
			pass
	if prompt:
		var near: bool = world.player and rect().grow(8).intersects(world.player.rect())
		prompt.visible = near and not world.player.frozen
		prompt.position.y = (-60 if kind == "lantern" else -44) + sin(t * 5.0) * 1.5

static func _page_texture() -> Texture2D:
	var img := Image.create(9, 11, false, Image.FORMAT_RGBA8)
	var paper := Color("#e8dcc0")
	var ink := Color("#6a5a4a")
	for y in 11:
		for x in 9:
			var c := paper if (x + y) % 7 != 0 else Color("#d4c4a2")
			if y in [2, 4, 6, 8] and x > 0 and x < 8 - (y % 3): c = ink
			if x == 8 and y == 0: continue
			img.set_pixel(x, y, c)
	img.set_pixel(8, 10, Color("#b02020"))
	img.set_pixel(7, 10, Color("#b02020"))
	return ImageTexture.create_from_image(img)

static func _flashlight_texture() -> Texture2D:
	var img := Image.create(12, 6, false, Image.FORMAT_RGBA8)
	for y in 6:
		for x in 12:
			var c := Color("#3a3a48") if x > 3 else Color("#8a8a98")
			if y == 0 or y == 5: c = c.darkened(0.3) if x > 3 else Color(0, 0, 0, 0)
			if x <= 1: c = Color("#fff6c0")
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)
