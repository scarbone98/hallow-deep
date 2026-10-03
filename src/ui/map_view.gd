class_name MapView
extends Control
## The cave map: every visited cell, room outlines, and where you are.

const Rooms := preload("res://src/world/rooms.gd")
const C := Vector2(18, 11)  # one map cell on screen

var world
var t := 0.0

func _init() -> void:
	size = Vector2(320, 180)
	process_mode = Node.PROCESS_MODE_ALWAYS

func open(w) -> void:
	world = w
	queue_redraw()

func _process(delta: float) -> void:
	if visible:
		t += delta
		queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.01, 0.04, 0.94))
	var f := Ui.font()
	draw_string(f, Vector2(0, 16), "THE DEEP", HORIZONTAL_ALIGNMENT_CENTER, 320, 8, Color("#d8cff0"))
	draw_string(f, Vector2(0, 172), "M / TAB TO CLOSE", HORIZONTAL_ALIGNMENT_CENTER, 320, 8, Color("#6e6290"))
	# Centre the known world.
	var lo := Vector2i(999, 999)
	var hi := Vector2i(-999, -999)
	for id in Rooms.ROOMS:
		var r: Dictionary = Rooms.ROOMS[id]
		lo = Vector2i(min(lo.x, r.cell.x), min(lo.y, r.cell.y))
		hi = Vector2i(max(hi.x, r.cell.x + r.size.x), max(hi.y, r.cell.y + r.size.y))
	var span := Vector2(hi - lo) * C
	var origin := (size - span) / 2.0 - Vector2(lo) * C + Vector2(0, 4)
	for id in Rooms.ROOMS:
		var r: Dictionary = Rooms.ROOMS[id]
		var seen := false
		for y in r.size.y:
			for x in r.size.x:
				var cell: Vector2i = r.cell + Vector2i(x, y)
				if Game.was_visited(cell):
					seen = true
					draw_rect(Rect2(origin + Vector2(cell) * C + Vector2(1, 1), C - Vector2(2, 2)), Color("#3a2f58"))
		if seen:
			var rr := Rect2(origin + Vector2(r.cell) * C, Vector2(r.size) * C)
			draw_rect(rr.grow(-1), Color("#8a78c0"), false, 1.0)
			if id == Game.save_room:
				draw_rect(Rect2(rr.get_center() - Vector2(2, 2), Vector2(4, 4)), Color("#ffb347"))
	if world and world.player and int(t * 3.0) % 2 == 0:
		var p: Vector2 = world.player.global_position / Game.CELL_PX
		draw_rect(Rect2(origin + p * C - Vector2(2, 3), Vector2(4, 4)), Color("#ffffff"))
