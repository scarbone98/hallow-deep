extends Node
## Title screen, the opening, then the caves.
## Dev flags: ?room=<id> starts there, ?give=double_jump, ?fresh ignores the
## save, ?outfit=<name> wears a preview outfit, ?touch shows touch buttons,
## ?god ignores damage (for recording the cabinet video), ?trace=1 logs animation frames.

var world: World
var title: CanvasLayer
# Character select on the title screen: your avatar ("you", once the page has sent your look)
# and the four kids. Left / right to choose.
var picks: Array = []
var pick := 0
var pick_sprite: AnimatedSprite2D
var pick_name: Label

func _ready() -> void:
	randomize()
	var f := Bridge.flags()
	if f.has("give"):
		for a in str(f.give).split(","):
			Game.grant(a)
	if f.has("room"):
		Game.flags.intro = true
		_enter(str(f.room))
		return
	_title()

func _title() -> void:
	title = CanvasLayer.new()
	add_child(title)
	var sky := TextureRect.new()
	sky.texture = load("res://assets/cc0/cemetery_background.png")
	sky.position = Vector2(-32, -30)
	title.add_child(sky)
	var yard := TextureRect.new()
	yard.texture = load("res://assets/cc0/cemetery_graveyard.png")
	yard.position = Vector2(-32, 180 - 123 + 20)
	yard.modulate = Color(0.45, 0.4, 0.6)
	title.add_child(yard)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.0, 0.04, 0.35)
	dim.size = Vector2(320, 180)
	title.add_child(dim)
	var name_l := Ui.label("HALLOW DEEP", 16, Color("#ffb347"))
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.size = Vector2(320, 20)
	name_l.position = Vector2(0, 40)
	name_l.add_theme_color_override("font_outline_color", Color("#3a0a10"))
	name_l.add_theme_constant_override("outline_size", 6)
	title.add_child(name_l)
	var sub := Ui.label("SOMETHING DOWN THERE IS BREATHING", 8, Color("#c9bde6"))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.size = Vector2(320, 12)
	sub.position = Vector2(0, 64)
	title.add_child(sub)
	var box := VBoxContainer.new()
	box.position = Vector2(110, 96)
	box.size = Vector2(100, 40)
	box.add_theme_constant_override("separation", 4)
	title.add_child(box)
	var first: Button
	if Game.has_save():
		first = _menu_button(box, "CONTINUE", func(): _enter(""))
		_menu_button(box, "NEW GAME", _new_game)
	else:
		first = _menu_button(box, "BEGIN", _new_game)
	first.grab_focus.call_deferred()
	var keys := Ui.label("ARROWS MOVE   Z JUMP   X SWING   UP READ/REST   M MAP", 8, Color("#7d70a0"))
	keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	keys.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	keys.size = Vector2(300, 24)
	keys.position = Vector2(10, 148)
	title.add_child(keys)
	_build_picker()
	var t := name_l.create_tween().set_loops()
	t.tween_property(name_l, "modulate", Color(1.3, 0.9, 0.9), 0.15)
	t.tween_property(name_l, "modulate", Color.WHITE, 0.3)
	t.tween_interval(0.9)

func _build_picker() -> void:
	var frame := Panel.new()
	frame.add_theme_stylebox_override("panel", Ui.panel(Color(0.06, 0.03, 0.1, 0.6), Color(0.3, 0.24, 0.45)))
	frame.position = Vector2(238, 82)
	frame.size = Vector2(56, 62)
	title.add_child(frame)
	pick_sprite = AnimatedSprite2D.new()
	pick_sprite.centered = false
	pick_sprite.position = Vector2(266, 132)  # the feet
	title.add_child(pick_sprite)
	pick_name = Ui.label("", 8, Color("#ffb347"))
	pick_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pick_name.size = Vector2(56, 10)
	pick_name.position = Vector2(238, 133)
	title.add_child(pick_name)
	for side in [[-1, "<", 228], [1, ">", 298]]:
		var arrow := Ui.label(side[1], 8, Color("#7d70a0"))
		arrow.position = Vector2(side[2], 108)
		title.add_child(arrow)
	_refresh_picks()
	if not Bridge.look_loaded.is_connected(_on_look_loaded):
		Bridge.look_loaded.connect(_on_look_loaded)

## The choices: your avatar once the page has sent it, then the kids. Keeps the current choice.
func _refresh_picks() -> void:
	var current: String = picks[pick] if not picks.is_empty() else Game.character
	picks = []
	if not Bridge.look.is_empty():
		picks.append("you")
	picks.append_array(KidSprites.KIDS)
	var f := Bridge.flags()
	if f.has("outfit") and str(f.outfit) in picks:
		current = str(f.outfit)  # ?outfit=joe also picks Joe on the title screen
	if current == "" or not current in picks:
		current = "you" if "you" in picks else KidSprites.KIDS[randi() % KidSprites.KIDS.size()]
	pick = picks.find(current)
	_show_pick()

func _on_look_loaded(_look: Dictionary) -> void:
	if title:
		if Game.character == "":
			Game.character = "you"  # signed in and never chose: default to your own avatar
		picks = []
		_refresh_picks()

func _show_pick() -> void:
	var who: String = picks[pick]
	if who == "you":
		pick_sprite.sprite_frames = AvatarBuilder.build(Bridge.look)
		pick_sprite.offset = Vector2(-16, -47)
		pick_name.text = (Bridge.user_name if Bridge.user_name != "" else "YOU").to_upper()
	else:
		var k := KidSprites.build(who)
		pick_sprite.sprite_frames = k.frames
		pick_sprite.offset = -k.pivot
		pick_name.text = who.to_upper()
	pick_sprite.scale = Vector2(2, 2)  # avatar and kids stand about the same height in game
	pick_sprite.play("idle")

func _unhandled_input(event: InputEvent) -> void:
	if not title or picks.is_empty():
		return
	var step := 0
	if event.is_action_pressed("left"):
		step = -1
	elif event.is_action_pressed("right"):
		step = 1
	if step != 0:
		pick = (pick + step + picks.size()) % picks.size()
		_show_pick()
		Sfx.play("swing")
		get_viewport().set_input_as_handled()

func _menu_button(box: VBoxContainer, text: String, on: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_override("font", Ui.font())
	b.add_theme_font_size_override("font_size", 8)
	b.add_theme_stylebox_override("normal", Ui.panel(Color(0.06, 0.03, 0.1, 0.8), Color(0.3, 0.24, 0.45)))
	b.add_theme_stylebox_override("hover", Ui.panel(Color(0.18, 0.08, 0.16, 0.9), Color(1.0, 0.7, 0.3)))
	b.add_theme_stylebox_override("focus", Ui.panel(Color(0.18, 0.08, 0.16, 0.9), Color(1.0, 0.7, 0.3)))
	b.add_theme_stylebox_override("pressed", Ui.panel(Color(0.25, 0.1, 0.2, 0.9), Color(1.0, 0.7, 0.3)))
	b.add_theme_color_override("font_focus_color", Color("#ffb347"))
	b.add_theme_color_override("font_hover_color", Color("#ffb347"))
	b.pressed.connect(on)
	box.add_child(b)
	return b

func _new_game() -> void:
	Game.new_game()
	_enter("", true)

func _enter(room: String, intro := false) -> void:
	if title and not picks.is_empty():
		Game.character = picks[pick]
		if Game.has_save():
			Game.save_game()
	if title:
		title.queue_free()
		title = null
	world = World.new()
	add_child(world)
	if intro:
		world.hud.fade.color = Color(0, 0, 0, 1)
		world.start()
		await world.hud.say([
			"Three nights ago, Rowan went looking for Hallow Fields.",
			"Everyone in town knows the legend. A door under the old cemetery. Fields where it's Halloween forever.",
			"Rowan didn't come home.",
			"Tonight, the ground behind the mausoleum split open.",
			"And it's breathing.",
		], "", "card")
		Game.flags.intro = true
		Game.save_game()
		await world.hud.fade_to(0.0, 1.2)
		world.hud.show_area("Old Cemetery")
	else:
		world.start(room)
