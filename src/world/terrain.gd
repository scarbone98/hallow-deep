class_name Terrain
extends RefCounted
## Paints a room's rock into one image and works out its collision.
##
## Rock is shaded by how deep it is: tiles touching open air get a lit rim on
## top (with moss), softer sides and a dark underside, and their outer corners
## are rounded off; rock two or more tiles in fades to near black. Each theme
## is a palette: 7 rock shades, 3 moss shades.

const T := 16
const SOLID := "#C"

const THEMES := {
	"cave": {
		"rock": ["#0b0811", "#140f1d", "#1d1729", "#282036", "#352a47", "#46385d", "#5d4b7a"],
		"moss": ["#1d5e55", "#35a08a", "#74e6c0"],
		"back": ["#07050b", "#0b0812", "#100c19"],
	},
	"chapel": {
		"rock": ["#0b0811", "#140f1d", "#1d1729", "#282036", "#352a47", "#46385d", "#5d4b7a"],
		"moss": ["#2b4f3a", "#4a7d52", "#8cc070"],
		"brick": ["#130e20", "#1f1735", "#2c214a", "#3b2d61", "#4f3e7c", "#6a569c"],
		"back": ["#08060e", "#0e0a17", "#151021"],
	},
	"mire": {
		"rock": ["#070a09", "#0e1512", "#151f1a", "#1d2b23", "#27392e", "#344b3b", "#476650"],
		"moss": ["#4a6b1f", "#7fa83a", "#c2e06a"],
		"back": ["#050806", "#08100c", "#0c1611"],
	},
	"rim": {
		"rock": ["#0e070a", "#170c12", "#21111a", "#2d1723", "#3b1e2e", "#4e283c", "#68354f"],
		"moss": ["#7a2f12", "#d0661e", "#ffb347"],
		"back": ["#0a0407", "#10060b", "#170911"],
	},
	"surface": {
		"rock": ["#0d090c", "#160f14", "#20151c", "#2b1d25", "#382630", "#49323c", "#5e434b"],
		"moss": ["#1d3b2a", "#2f5e3a", "#4f8a4a"],
		"back": ["#0b0910", "#120f19", "#191523"],
	},
}

static var _noise: FastNoiseLite
static var _cache := {}

static func _n(x: float, y: float) -> float:
	if _noise == null:
		_noise = FastNoiseLite.new()
		_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
		_noise.frequency = 0.09
		_noise.seed = 1987
	return _noise.get_noise_2d(x, y)

static func _h(x: int, y: int) -> float:
	# Cheap stable hash in [0, 1).
	var n := (x * 374761393 + y * 668265263) & 0x7fffffff
	n = ((n ^ (n >> 13)) * 1274126177) & 0x7fffffff
	return float(n % 10007) / 10007.0

static func palette(theme: String) -> Dictionary:
	var src: Dictionary = THEMES.get(theme, THEMES.cave)
	var out := {}
	for k in src:
		var a := []
		for hex in src[k]:
			a.append(Color(hex))
		out[k] = a
	return out

static func is_solid_char(c: String) -> bool:
	return c in SOLID

## {image, solids: [Rect2i], oneway: [Rect2i]} in tiles, for room `id`.
static func build(id: String, room: Dictionary) -> Dictionary:
	if _cache.has(id):
		return _cache[id]
	var map: Array = room.map
	var h := map.size()
	var w: int = map[0].length()
	var pal := palette(room.theme)
	var img := Image.create(w * T, h * T, false, Image.FORMAT_RGBA8)
	var solid := func(x: int, y: int) -> bool:
		if x < 0 or y < 0 or x >= w or y >= h:
			return true
		return is_solid_char(map[y][x])
	# How far each solid tile is from open air (1 = touching it), up to 3.
	var depth := []
	for y in h:
		var row := []
		for x in w:
			var d := 0
			if solid.call(x, y):
				d = 3
				for r in [1, 2]:
					var hit := false
					for dy in range(-r, r + 1):
						for dx in range(-r, r + 1):
							if not solid.call(x + dx, y + dy):
								hit = true
					if hit:
						d = r
						break
			row.append(d)
		depth.append(row)
	var deep_tiles := []
	for v in 3:
		deep_tiles.append(_deep_tile(pal, v))
	for y in h:
		for x in w:
			var c: String = map[y][x]
			if c == "#" and depth[y][x] >= 3:
				img.blit_rect(deep_tiles[int(_h(x, y) * 3)], Rect2i(0, 0, T, T), Vector2i(x * T, y * T))
			elif c == "#" or c == "C":
				_paint_tile(img, pal, x, y, c, depth[y][x], solid)
			elif c == "=":
				_paint_ledge(img, pal, x, y, map[y][x - 1] == "=" if x > 0 else false, map[y][x + 1] == "=" if x < w - 1 else false)
			elif c == "^":
				_paint_spikes(img, x, y)
			elif c == "~":
				_paint_muck(img, x, y, y > 0 and map[y - 1][x] == "~")
			elif c == "!":
				_paint_abyss(img, x, y)
	var out := {"image": img, "solids": _rects(map, func(ch): return ch in SOLID), "oneway": _rects(map, func(ch): return ch == "=")}
	_cache[id] = out
	return out

static func _deep_tile(pal: Dictionary, v: int) -> Image:
	var t := Image.create(T, T, false, Image.FORMAT_RGBA8)
	var rock: Array = pal.rock
	for y in T:
		for x in T:
			var k := _h(x + v * 31, y + v * 17)
			t.set_pixel(x, y, rock[0] if k > 0.12 else rock[1])
	return t

static func _paint_tile(img: Image, pal: Dictionary, tx: int, ty: int, c: String, depth: int, solid: Callable) -> void:
	var rock: Array = pal.rock
	var moss: Array = pal.moss
	var open_n: bool = not solid.call(tx, ty - 1)
	var open_s: bool = not solid.call(tx, ty + 1)
	var open_w: bool = not solid.call(tx - 1, ty)
	var open_e: bool = not solid.call(tx + 1, ty)
	var open_nw: bool = not solid.call(tx - 1, ty - 1)
	var open_ne: bool = not solid.call(tx + 1, ty - 1)
	var open_sw: bool = not solid.call(tx - 1, ty + 1)
	var open_se: bool = not solid.call(tx + 1, ty + 1)
	var brick: bool = c == "C"
	for y in T:
		for x in T:
			var gx := tx * T + x
			var gy := ty * T + y
			# Round off outer corners.
			if open_n and open_w and x + y < 2: continue
			if open_n and open_e and (T - 1 - x) + y < 2: continue
			if open_s and open_w and x + (T - 1 - y) < 2: continue
			if open_s and open_e and (T - 1 - x) + (T - 1 - y) < 2: continue
			var dn: int = y if open_n else 99
			var ds: int = (T - 1 - y) if open_s else 99
			var dw: int = x if open_w else 99
			var de: int = (T - 1 - x) if open_e else 99
			# Inner corners: diagonal air with both sides solid.
			if open_nw and not open_n and not open_w: dn = min(dn, max(x, y))
			if open_ne and not open_n and not open_e: dn = min(dn, max(T - 1 - x, y))
			if open_sw and not open_s and not open_w: ds = min(ds, max(x, T - 1 - y))
			if open_se and not open_s and not open_e: ds = min(ds, max(T - 1 - x, T - 1 - y))
			var d: int = min(min(dn, ds), min(dw, de))
			var s := 1
			if d < 99:
				s = 3 if d < 6 else 2
				if d >= 10: s = 1
			elif depth <= 1:
				s = 2
			var nz := _n(gx, gy)
			if nz > 0.3: s += 1
			elif nz < -0.35: s -= 1
			if dn == 0: s = 6
			elif dn == 1: s = 5
			elif dn <= 3: s = max(s, 4)
			elif dw == 0: s = max(s, 4)
			elif de == 0: s = max(s, 3)
			if ds == 0: s = 0
			elif ds == 1: s = min(s, 1)
			if _h(gx, gy) < 0.04: s -= 1
			s = clamp(s, 0, 6)
			var col: Color = rock[s]
			if brick:
				col = _brick(pal.brick, gx, gy, s)
			# Moss on lit tops, dripping a little over the lip.
			if open_n and dn <= 3:
				var m := _n(gx * 2.0, 400.0)
				if m > -0.1 and (dn <= 1 or _h(gx, 7) < 0.35 - dn * 0.1):
					col = moss[2] if dn == 0 and _h(gx, gy) < 0.35 else (moss[1] if dn <= 1 else moss[0])
			img.set_pixel(gx, gy, col)

static func _brick(ramp: Array, gx: int, gy: int, s: int) -> Color:
	var row := gy / 8
	var off := 8 if row % 2 == 1 else 0
	var bx := (gx + off) % 16
	var by := gy % 8
	if bx == 0 or by == 7:
		return ramp[max(0, min(s, 5) - 3)]
	var b := _h((gx + off) / 16, row)
	var k: int = clamp(s - 1 + (1 if b > 0.7 else 0) - (1 if b < 0.2 else 0), 0, 5)
	if by == 0 and k < 5: k += 1
	return ramp[k]

static func _paint_ledge(img: Image, pal: Dictionary, tx: int, ty: int, left: bool, right: bool) -> void:
	var wood := [Color("#1c0f0b"), Color("#3a2015"), Color("#5c3420"), Color("#84502e")]
	var vein: Color = pal.moss[1]
	for y in 6:
		for x in T:
			if not left and x == 0 and (y == 0 or y == 5): continue
			if not right and x == T - 1 and (y == 0 or y == 5): continue
			var k := 3 if y == 0 else (2 if y < 3 else (1 if y < 5 else 0))
			var col: Color = wood[k]
			if y == 2 and _h(tx * T + x, ty) < 0.25: col = vein
			img.set_pixel(tx * T + x, ty * T + y, col)
	# Roots dangling under it.
	for x in T:
		var dangle := int(_h(tx * T + x, ty * 3) * 9) - 4
		for y in range(6, 6 + max(0, dangle)):
			img.set_pixel(tx * T + x, ty * T + y, wood[0])

static func _paint_spikes(img: Image, tx: int, ty: int) -> void:
	var bone := [Color("#3a3446"), Color("#7f7790"), Color("#cfc6dc")]
	for i in 4:
		var cx := i * 4 + 2
		var hgt := 7 + int(_h(tx * 4 + i, ty) * 4)
		for y in hgt:
			var half := int(float(y) / hgt * 2.0)
			for dx in range(-half, half + 1):
				var x := cx + dx
				if x < 0 or x >= T: continue
				var col: Color = bone[2] if dx < 0 else (bone[1] if dx == 0 else bone[0])
				img.set_pixel(tx * T + x, ty * T + (T - hgt) + y, col)

static func _paint_muck(img: Image, tx: int, ty: int, below_surface: bool) -> void:
	var muck := [Color("#0f2412"), Color("#1d3d1a"), Color("#3c7a2a"), Color("#9fe06a")]
	for y in T:
		for x in T:
			var col: Color = muck[0]
			if not below_surface:
				if y < 2: col = muck[3] if _h(tx * T + x, y) < 0.3 else muck[2]
				elif y < 4: col = muck[1]
			if _h(tx * T + x, ty * T + y) < 0.03: col = muck[2]
			col.a = 0.92
			img.set_pixel(tx * T + x, ty * T + y, col)

static func _paint_abyss(img: Image, tx: int, ty: int) -> void:
	for y in T:
		for x in T:
			img.set_pixel(tx * T + x, ty * T + y, Color(0, 0, 0, 0.6 + 0.4 * float(y) / T))

## Greedy rectangles over the tiles `want` accepts, merging rows that match.
static func _rects(map: Array, want: Callable) -> Array:
	var open := {}  # "x0,x1" -> Rect2i still growing down
	var done := []
	for y in map.size():
		var row: String = map[y]
		var runs := {}
		var x := 0
		while x < row.length():
			if want.call(row[x]):
				var x0 := x
				while x < row.length() and want.call(row[x]):
					x += 1
				runs["%d,%d" % [x0, x]] = Rect2i(x0, y, x - x0, 1)
			else:
				x += 1
		var next := {}
		for k in runs:
			if open.has(k):
				var r: Rect2i = open[k]
				r.size.y += 1
				next[k] = r
			else:
				next[k] = runs[k]
		for k in open:
			if not next.has(k) or next[k].position.y != open[k].position.y:
				done.append(open[k])
		open = next
	for k in open:
		done.append(open[k])
	return done

## The far cave wall behind a room: big soft blobs in the theme's back colours.
static func back_wall(theme: String, w: int, h: int) -> Image:
	var key := "back:%s:%d:%d" % [theme, w, h]
	if _cache.has(key):
		return _cache[key]
	var back: Array = palette(theme).back
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var n := _n(x * 0.45 + 900.0, y * 0.45)
			var k := 0
			if n > 0.15: k = 1
			if n > 0.45: k = 2
			if k == 1 and _h(x, y) < 0.08: k = 0
			img.set_pixel(x, y, back[k])
	_cache[key] = img
	return img

## A hot root: twisted bark with glowing veins (one tile).
static func root_tile(tx: int, ty: int) -> Image:
	var bark := [Color("#1a0c08"), Color("#2e150c"), Color("#4a2412"), Color("#6b3517")]
	var glow := [Color("#c4521a"), Color("#ff9a3c"), Color("#ffe08a")]
	var img := Image.create(T, T, false, Image.FORMAT_RGBA8)
	for y in T:
		for x in T:
			var gx := tx * T + x
			var gy := ty * T + y
			# Twisted strands running up and down, with hot veins wandering through.
			var strand := _n(gx * 1.1, gy * 0.16 + 50.0)
			var col: Color = bark[clampi(int((strand + 1.0) * 2.0), 0, 3)]
			var vein := absf(_n(gx * 0.4 + 300.0, gy * 0.3))
			if vein < 0.035: col = glow[2]
			elif vein < 0.08: col = glow[1]
			elif vein < 0.12: col = glow[0]
			img.set_pixel(x, y, col)
	return img

## Cracked rock you can break (one tile).
static func cracked_tile(theme: String) -> Image:
	var rock: Array = palette(theme).rock
	var img := Image.create(T, T, false, Image.FORMAT_RGBA8)
	for y in T:
		for x in T:
			var s := 3 + (1 if _n(x * 3.0, y * 3.0) > 0.2 else 0)
			if y == 0: s = 5
			if x == 0 or y == T - 1 or x == T - 1: s = 2
			img.set_pixel(x, y, rock[s])
	var crack := [[3, 2], [4, 3], [5, 4], [5, 5], [6, 6], [8, 6], [9, 7], [10, 9], [11, 10], [11, 12], [6, 7], [5, 9], [4, 10], [9, 3], [10, 2], [12, 4]]
	for p in crack:
		img.set_pixel(p[0], p[1], rock[0])
	return img
