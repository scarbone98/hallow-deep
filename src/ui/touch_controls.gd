class_name TouchControls
extends Control
## On-screen buttons for phones: a d-pad on the left, jump and attack on the
## right, map in the corner. Only shown on touch screens (or with ?touch).

var wanted := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(320, 180)
	wanted = Bridge.flags().has("touch")
	if Bridge.is_web() and not wanted:
		# Phones and tablets: a coarse pointer (a finger), not a mouse.
		wanted = bool(JavaScriptBridge.eval("matchMedia('(pointer: coarse)').matches"))
	visible = wanted
	_button("left", Vector2(6, 136), 16, "<")
	_button("right", Vector2(46, 136), 16, ">")
	_button("up", Vector2(26, 116), 16, "^")
	_button("down", Vector2(26, 156), 14, "v")
	_button("attack", Vector2(244, 140), 17, "X")
	_button("jump", Vector2(282, 124), 17, "Z")
	_button("map", Vector2(296, 4), 10, "M")

func _button(action: String, pos: Vector2, r: int, glyph: String) -> void:
	var b := TouchScreenButton.new()
	b.action = action
	b.position = pos
	b.texture_normal = _circle(r, Color(1, 1, 1, 0.16))
	b.texture_pressed = _circle(r, Color(1, 1, 1, 0.38))
	var shape := CircleShape2D.new()
	shape.radius = r + 4
	b.shape = shape
	b.shape_centered = true
	b.passby_press = action in ["left", "right", "up", "down"]
	add_child(b)
	var l := Ui.label(glyph, 8, Color(1, 1, 1, 0.7))
	l.position = pos + Vector2(r - 4, r - 4)
	add_child(l)

func _circle(r: int, col: Color) -> Texture2D:
	var d := r * 2
	var img := Image.create(d, d, false, Image.FORMAT_RGBA8)
	for y in d:
		for x in d:
			var k := Vector2(x + 0.5 - r, y + 0.5 - r).length()
			if k <= r:
				img.set_pixel(x, y, col if k < r - 1.5 else Color(col.r, col.g, col.b, col.a * 2.0))
	return ImageTexture.create_from_image(img)
