extends SceneTree
## godot --headless --path . -s tools/check_rooms.gd
## Checks every room's map is the right size and every gap in its outer wall
## opens into the room next door (or is a known way out: sky, abyss).
const Rooms := preload("res://src/world/rooms.gd")
const SOLID := "#CRB"

func _tile(id: String, world: Vector2i) -> String:
	var r: Dictionary = Rooms.ROOMS[id]
	var local: Vector2i = world - r.cell * Game.CELL
	return r.map[local.y][local.x]

func _init() -> void:
	var bad := 0
	for id in Rooms.ROOMS:
		var r: Dictionary = Rooms.ROOMS[id]
		var w: int = r.size.x * Game.CELL.x
		var h: int = r.size.y * Game.CELL.y
		if r.map.size() != h:
			print("%s: %d rows, want %d" % [id, r.map.size(), h]); bad += 1; continue
		for y in h:
			if r.map[y].length() != w:
				print("%s row %d: %d wide, want %d" % [id, y, r.map[y].length(), w]); bad += 1
		if bad: continue
		var origin: Vector2i = r.cell * Game.CELL
		var edges := []
		for x in w:
			edges.append([Vector2i(x, 0), Vector2i(0, -1)]); edges.append([Vector2i(x, h - 1), Vector2i(0, 1)])
		for y in h:
			edges.append([Vector2i(0, y), Vector2i(-1, 0)]); edges.append([Vector2i(w - 1, y), Vector2i(1, 0)])
		for e in edges:
			var t: String = r.map[e[0].y][e[0].x]
			if t in SOLID or t == "!": continue
			var out: Vector2i = origin + e[0] + e[1]
			var cell := Vector2i(floori(float(out.x) / Game.CELL.x), floori(float(out.y) / Game.CELL.y))
			var other := Rooms.at_cell(cell)
			if other == "":
				if id == "surface" and e[1].y <= 0: continue  # sky and the cemetery fence
				print("%s: gap at %s leads nowhere" % [id, e[0]]); bad += 1
			elif _tile(other, out) in SOLID:
				print("%s: gap at %s hits rock in %s" % [id, e[0], other]); bad += 1
	print("rooms ok" if bad == 0 else "%d problems" % bad)
	quit()
