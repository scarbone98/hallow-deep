class_name Hud
extends CanvasLayer
## Everything drawn over the game: hearts, candy, area names, the dialogue box,
## whispers, the boss bar, the cave map, fades and the touch buttons.

signal advance

var world
var hearts: HBoxContainer
var candy_label: Label
var area: Label
var box: PanelContainer
var box_text: Label
var box_name: Label
var whisper_label: Label
var card: ColorRect
var card_text: Label
var fade: ColorRect
var boss: Control
var boss_fill: ColorRect
var boss_name: Label
var map_view: MapView
var touch: Control
var talking := false
var _typing := false
var _full := ""

func _init() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS

func _ready() -> void:
	hearts = HBoxContainer.new()
	hearts.position = Vector2(6, 5)
	hearts.add_theme_constant_override("separation", 1)
	add_child(hearts)

	var candy_icon := TextureRect.new()
	var at := AtlasTexture.new()
	at.atlas = load("res://assets/sprites/candy_corn.png")
	at.region = Rect2(0, 0, 24, 24)
	candy_icon.texture = at
	candy_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	candy_icon.position = Vector2(3, 16)
	candy_icon.size = Vector2(12, 12)
	add_child(candy_icon)
	candy_label = Ui.label("0", 8, Color("#ffd27a"))
	candy_label.position = Vector2(18, 20)
	candy_label.size = Vector2(60, 10)
	add_child(candy_label)

	area = Ui.label("", 8, Color("#d8cff0"))
	area.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	area.size = Vector2(320, 12)
	area.position = Vector2(0, 30)
	area.modulate.a = 0.0
	add_child(area)

	boss = Control.new()
	boss.position = Vector2(60, 164)
	boss.visible = false
	add_child(boss)
	var back := ColorRect.new()
	back.color = Color(0.05, 0.02, 0.06, 0.9)
	back.size = Vector2(200, 6)
	boss.add_child(back)
	boss_fill = ColorRect.new()
	boss_fill.color = Color("#7fd04a")
	boss_fill.position = Vector2(1, 1)
	boss_fill.size = Vector2(198, 4)
	boss.add_child(boss_fill)
	boss_name = Ui.label("MAGS, THE MIRE WARDEN", 8, Color("#c8f0a0"))
	boss_name.position = Vector2(0, -12)
	boss.add_child(boss_name)

	map_view = MapView.new()
	map_view.visible = false
	add_child(map_view)

	box = PanelContainer.new()
	box.add_theme_stylebox_override("panel", Ui.panel())
	box.position = Vector2(8, 118)
	box.custom_minimum_size = Vector2(304, 56)
	box.size = Vector2(304, 56)
	box.visible = false
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	box.add_child(v)
	box_name = Ui.label("", 8, Color("#ffb347"))
	v.add_child(box_name)
	box_text = Ui.label("", 8)
	box_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box_text.custom_minimum_size = Vector2(290, 0)
	v.add_child(box_text)
	add_child(box)

	whisper_label = Ui.label("", 8, Color("#ff3b3b"))
	whisper_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	whisper_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	whisper_label.size = Vector2(280, 40)
	whisper_label.position = Vector2(20, 70)
	whisper_label.visible = false
	add_child(whisper_label)

	fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.size = Vector2(320, 180)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade)

	card = ColorRect.new()
	card.color = Color(0.02, 0.01, 0.03)
	card.size = Vector2(320, 180)
	card.visible = false
	add_child(card)
	card_text = Ui.label("", 8, Color("#e6def5"))
	card_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	card_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_text.size = Vector2(280, 140)
	card_text.position = Vector2(20, 20)
	card.add_child(card_text)

	touch = TouchControls.new()
	add_child(touch)

	Game.changed.connect(refresh)
	refresh()

func refresh() -> void:
	for c in hearts.get_children():
		c.queue_free()
	for i in Game.max_hp:
		var r := TextureRect.new()
		r.texture = load("res://assets/sprites/heart.png" if i < Game.hp else "res://assets/sprites/heart_empty.png")
		r.custom_minimum_size = Vector2(10, 10)
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		hearts.add_child(r)
	candy_label.text = str(Game.candy)

func show_area(name: String) -> void:
	area.text = "- " + name.to_upper() + " -"
	var t := create_tween()
	t.tween_property(area, "modulate:a", 1.0, 0.4)
	t.tween_interval(1.6)
	t.tween_property(area, "modulate:a", 0.0, 0.8)

func boss_bar(frac: float) -> void:
	boss.visible = frac >= 0.0
	if frac >= 0.0:
		boss_fill.size.x = 198.0 * frac
		boss_fill.color = Color("#7fd04a") if frac > 0.5 else Color("#e05a3a")

func fade_to(alpha: float, time := 0.25) -> void:
	var t := create_tween()
	t.tween_property(fade, "color:a", alpha, time)
	await t.finished

func _input(event: InputEvent) -> void:
	if talking and (event.is_action_pressed("confirm") or event.is_action_pressed("jump") or event.is_action_pressed("attack") or event.is_action_pressed("up") or (event is InputEventScreenTouch and event.pressed)):
		get_viewport().set_input_as_handled()
		if _typing:
			_typing = false
		else:
			advance.emit()
	elif not talking and event.is_action_pressed("map") and world and world.player:
		map_view.visible = not map_view.visible
		get_tree().paused = map_view.visible
		if map_view.visible:
			map_view.open(world)

## Shows pages of text one at a time and waits for each to be dismissed.
## style: "box" (dialogue), "card" (black screen) or "whisper" (red, shaky).
func say(pages: Array, speaker := "", style := "box") -> void:
	talking = true
	get_tree().paused = true
	touch.visible = false
	var target: Label = box_text if style == "box" else (card_text if style == "card" else whisper_label)
	box.visible = style == "box"
	card.visible = style == "card"
	whisper_label.visible = style == "whisper"
	box_name.text = speaker
	box_name.visible = speaker != ""
	for page in pages:
		var text := str(page).replace("{name}", Bridge.user_name.to_upper() if Bridge.user_name != "" else "YOU")
		target.text = text
		target.visible_characters = 0
		if style == "box":
			# Grow the box upward to fit the page.
			box.size = Vector2(304, 0)
			await get_tree().process_frame
			box.position.y = 174.0 - box.get_combined_minimum_size().y
		_typing = true
		var speed := 45.0 if style != "whisper" else 14.0
		var shown := 0.0
		while _typing and target.visible_characters < text.length():
			await get_tree().process_frame
			shown += get_process_delta_time() * speed
			target.visible_characters = int(shown)
			if style == "whisper":
				target.position = Vector2(20, 70) + Vector2(randf_range(-1, 1), randf_range(-1, 1))
		_typing = false
		target.visible_characters = -1
		await advance
	box.visible = false
	whisper_label.visible = false
	card.visible = false
	talking = false
	touch.visible = touch.wanted
	get_tree().paused = false
