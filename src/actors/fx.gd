class_name Fx
extends RefCounted
## Small shared visuals: sprite strips, light textures, dust, death bursts.

static var _frames := {}
static var _lights := {}

## SpriteFrames from a horizontal strip of `n` equal frames.
## `name` is a file in assets/sprites, or "cc0/<file>" for assets/cc0.
static func frames(name: String, n: int, fps: float, loop := true) -> SpriteFrames:
	var key := "%s:%d:%f:%s" % [name, n, fps, loop]
	if _frames.has(key):
		return _frames[key]
	var path := "res://assets/" + (name if name.begins_with("cc0/") else "sprites/" + name) + ".png"
	var tex: Texture2D = load(path)
	var fw := tex.get_width() / n
	var sf := SpriteFrames.new()
	sf.set_animation_speed("default", fps)
	sf.set_animation_loop("default", loop)
	for i in n:
		var a := AtlasTexture.new()
		a.atlas = tex
		a.region = Rect2(i * fw, 0, fw, tex.get_height())
		sf.add_frame("default", a)
	_frames[key] = sf
	return sf

## A soft round light with a few hard steps, so it still reads as pixel art.
static func light_texture(size: int, tint := Color.WHITE) -> Texture2D:
	var key := "%d:%s" % [size, tint.to_html()]
	if _lights.has(key):
		return _lights[key]
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := size / 2.0
	for y in size:
		for x in size:
			var d := Vector2(x + 0.5 - c, y + 0.5 - c).length() / c
			var v := 0.0
			if d < 1.0:
				v = pow(1.0 - d, 1.4)
				v = floor(v * 6.0) / 6.0
			img.set_pixel(x, y, Color(tint.r, tint.g, tint.b, v))
	var tex := ImageTexture.create_from_image(img)
	_lights[key] = tex
	return tex

static func _pixel() -> Texture2D:
	if not _lights.has("px"):
		var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		_lights["px"] = ImageTexture.create_from_image(img)
	return _lights["px"]

## A few specks that puff out and fall.
static func dust(world: Node, pos: Vector2, n: int, col := Color(0.75, 0.7, 0.85)) -> void:
	for i in n:
		var s := Sprite2D.new()
		s.texture = _pixel()
		s.scale = Vector2(2, 2) if randf() < 0.4 else Vector2.ONE
		s.modulate = col
		s.position = pos + Vector2(randf_range(-4, 4), randf_range(-2, 0))
		s.z_index = 5
		world.add_effect(s)
		var t := s.create_tween()
		var to := s.position + Vector2(randf_range(-14, 14), randf_range(-12, 2))
		t.tween_property(s, "position", to, 0.35).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(s, "modulate:a", 0.0, 0.35)
		t.tween_callback(s.queue_free)

## The church pack's purple smoke burst.
static func poof(world: Node, pos: Vector2, scale := 0.6) -> void:
	var a := AnimatedSprite2D.new()
	a.sprite_frames = frames("cc0/enemy_death", 9, 18.0, false)
	a.position = pos
	a.scale = Vector2(scale, scale)
	a.z_index = 6
	world.add_effect(a)
	a.play("default")
	a.animation_finished.connect(a.queue_free)

## Floating text (damage, pickups).
static func popup(world: Node, pos: Vector2, text: String, col := Color.WHITE) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", Ui.font())
	l.add_theme_font_size_override("font_size", 8)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.08))
	l.add_theme_constant_override("outline_size", 3)
	l.position = pos - Vector2(text.length() * 4, 8)
	l.z_index = 20
	world.add_effect(l)
	var t := l.create_tween()
	t.tween_property(l, "position:y", l.position.y - 14, 0.7)
	t.parallel().tween_property(l, "modulate:a", 0.0, 0.7).set_delay(0.3)
	t.tween_callback(l.queue_free)
