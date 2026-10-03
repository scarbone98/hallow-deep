class_name AvatarBuilder
extends RefCounted
## Builds the player's sprite from their Scareathon avatar.
##
## The art is the site's pixel avatars (copied in by tools/sync_avatar.sh):
## 32x48 frames where every part hangs on an anchor of the body's rig
## ("head", "body", "ground", "free"). The site only has an idle loop, so the
## run and jump poses are made here: head and body parts bob like the idle
## does, and every ground part (legs, trousers, shoes) is split down the middle
## into a near leg and a far leg that stride apart. That way any outfit, even
## one added to the shop after this was written, runs without new art.
## Colours are swapped exactly like the site's compose.ts.

const ROOT := "res://assets/avatar-px/"
const W := 32
const H := 48
const SPLIT_X := 16  # canvas column where the near leg ends and the far one starts
const SKIP_SLOTS := ["background", "shadow"]
## Bodies with legs to stride; the rest (ghost, skull) float through every pose.
const LEGGED := ["body_kid", "body_zombie"]

static var _manifest: Dictionary = {}

static func manifest() -> Dictionary:
	if _manifest.is_empty():
		var f := FileAccess.open(ROOT + "manifest.json", FileAccess.READ)
		_manifest = JSON.parse_string(f.get_as_text())
	return _manifest

static func item_by_key(key: String) -> Dictionary:
	for item in manifest().items:
		if item.key == key:
			return item
	return {}

## A preview outfit from the site (pixel-avatar/outfits) as a look.
static func outfit_look(file_name: String) -> Dictionary:
	var f := FileAccess.open(ROOT + "outfits/" + file_name, FileAccess.READ)
	if not f:
		return {}
	var o: Dictionary = JSON.parse_string(f.get_as_text())
	var outfit := []
	for entry in o.items:
		outfit.append({"item": {"key": entry.key}, "dyes": entry.get("dyes", {})})
	return {"profile": {"skin": o.skin, "hair": o.hair, "eyes": o.eyes}, "outfit": outfit, "name": o.name}

static func outfit_files() -> PackedStringArray:
	var out := PackedStringArray()
	var d := DirAccess.open(ROOT + "outfits")
	if d:
		for f in d.get_files():
			if f.ends_with(".json"):
				out.append(f)
	out.sort()
	return out

## Guests (and anyone whose look didn't load) are one of the four kids.
static func guest_look() -> Dictionary:
	var kids := ["01-alex.json", "02-joe.json", "03-jon.json", "04-matt.json"]
	return outfit_look(kids[randi() % kids.size()])

## The look's outfit, resolved against our copy of the catalog. Items the game
## doesn't have yet (newer than its last sync) are left off.
static func _entries(look: Dictionary) -> Array:
	var out := []
	for e in look.get("outfit", []):
		var it: Dictionary = e.get("item", {})
		var key := str(it.get("key", it.get("itemKey", "")))
		var item := item_by_key(key)
		if item.is_empty():
			continue
		out.append({"item": item, "dyes": e.get("dyes", {}) if e.get("dyes") is Dictionary else {}})
	out.sort_custom(func(a, b): return int(a.item.get("order", 0)) < int(b.item.get("order", 0)))
	return out

static func _hex(s: String) -> Color:
	return Color.html(s)

static func _swap_table(profile: Dictionary, entry: Dictionary) -> Dictionary:
	var m := manifest()
	var swaps := {
		"skin": profile.get("skin"), "hair": profile.get("hair"), "eyes": profile.get("eyes"),
		"dye1": entry.dyes.get("dye1", entry.item.dyes.get("dye1")),
		"dye2": entry.dyes.get("dye2", entry.item.dyes.get("dye2")),
	}
	var table := {}
	for channel in swaps:
		var target = swaps[channel]
		var from_name: String = m.defaults.get(channel, "")
		if target == null or target == from_name or not m.ramps.has(target) or not m.ramps.has(from_name):
			continue
		var from: Array = m.ramps[from_name]
		var to: Array = m.ramps[target]
		for i in from.size():
			table[_hex(from[i]).to_rgba32() | 0xff] = _hex(to[i])
	return table

static func _load_part(src: String) -> Image:
	var path := ROOT + src.trim_prefix("/avatar-px/").split("?")[0]
	if not ResourceLoader.exists(path):
		return null
	var img: Image = (load(path) as Texture2D).get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	return img

static func _recolour(img: Image, table: Dictionary) -> Image:
	if table.is_empty():
		return img
	var out: Image = img.duplicate()
	for y in out.get_height():
		for x in out.get_width():
			var c := out.get_pixel(x, y)
			if c.a == 0.0:
				continue
			var key := Color(c.r, c.g, c.b, 1.0).to_rgba32()
			if table.has(key):
				var t: Color = table[key]
				out.set_pixel(x, y, Color(t.r, t.g, t.b, c.a))
	return out

## Every layer of the look, back to front: {img, part, anchor}.
static func _layers(look: Dictionary) -> Dictionary:
	var m := manifest()
	var entries := _entries(look)
	var body_key := ""
	for e in entries:
		if e.item.category == "body":
			body_key = e.item.key
	var rig: Dictionary = m.bases.get(body_key, {"frames": 1, "fps": 1, "anchors": {}})
	var hidden := {}
	for e in entries:
		for s in e.item.get("hides", []):
			hidden[s] = true
	var layers := []
	var has_legs := false
	for slot in m.slots:
		if hidden.has(slot) or slot in SKIP_SLOTS:
			continue
		for e in entries:
			for part in e.item.parts:
				if part.slot != slot:
					continue
				if body_key != "" and part.has("fits") and not body_key in part.fits:
					continue
				if body_key != "" and not rig.anchors.has(part.anchor):
					continue
				var img := _load_part(part.src)
				if img == null:
					continue
				layers.append({"img": _recolour(img, _swap_table(look.get("profile", {}), e)), "part": part})
	has_legs = body_key in LEGGED
	return {"layers": layers, "rig": rig, "has_legs": has_legs, "body": body_key}

## pose: {"head": Vector2i, "body": Vector2i, "free": Vector2i, "near": Vector2i, "far": Vector2i, "frame": int}
static func _draw(layers: Array, pose: Dictionary) -> Image:
	var canvas := Image.create(W, H, false, Image.FORMAT_RGBA8)
	for l in layers:
		var part: Dictionary = l.part
		var img: Image = l.img
		var fw := int(part.w)
		var fh := int(part.h)
		var f: int = int(pose.frame) % max(1, int(part.frames))
		var px := int(part.x)
		var py := int(part.y)
		if part.anchor == "ground":
			# Split at SPLIT_X: the near (left) leg and the far (right) leg move apart.
			var cut: int = clamp(SPLIT_X - px, 0, fw)
			var near: Vector2i = pose.near
			var far: Vector2i = pose.far
			if cut > 0:
				canvas.blend_rect(img, Rect2i(f * fw, 0, cut, fh), Vector2i(px, py) + near)
			if cut < fw:
				canvas.blend_rect(img, Rect2i(f * fw + cut, 0, fw - cut, fh), Vector2i(px + cut, py) + far)
		else:
			var off: Vector2i = pose.get(part.anchor, Vector2i.ZERO)
			canvas.blend_rect(img, Rect2i(f * fw, 0, fw, fh), Vector2i(px, py) + off)
	return canvas

static func _rig_offset(rig: Dictionary, anchor: String, f: int) -> Vector2i:
	var a = rig.anchors.get(anchor)
	if a == null or not a is Array or a.is_empty():
		return Vector2i.ZERO
	var p: Array = a[f % a.size()]
	return Vector2i(int(p[0]), int(p[1]))

## SpriteFrames with idle, run, jump, fall and hurt, all 32x48 with the kid's
## feet at (16, 46).
static func build(look: Dictionary) -> SpriteFrames:
	var info := _layers(look)
	var layers: Array = info.layers
	var rig: Dictionary = info.rig
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	var add := func(anim: String, fps: float, loop: bool, imgs: Array):
		sf.add_animation(anim)
		sf.set_animation_speed(anim, fps)
		sf.set_animation_loop(anim, loop)
		for img in imgs:
			sf.add_frame(anim, ImageTexture.create_from_image(img))

	var n := int(rig.get("frames", 1))
	var idle := []
	for f in n:
		idle.append(_draw(layers, {"frame": f, "head": _rig_offset(rig, "head", f), "body": _rig_offset(rig, "body", f),
			"free": _rig_offset(rig, "free", f), "near": Vector2i.ZERO, "far": Vector2i.ZERO}))
	add.call("idle", float(rig.get("fps", 6)), true, idle)

	if not info.has_legs:
		# Floating bodies (ghost, skull) just keep floating.
		add.call("run", float(rig.get("fps", 6)) * 1.5, true, idle)
		add.call("jump", 1.0, false, [idle[0]])
		add.call("fall", 1.0, false, [idle[min(2, n - 1)]])
		add.call("hurt", 1.0, false, [idle[0]])
		return sf

	var down := Vector2i(0, 1)
	var run_poses := [
		{"body": Vector2i.ZERO, "near": Vector2i(-1, 0), "far": Vector2i(1, 0)},
		{"body": down, "near": Vector2i(0, -1), "far": Vector2i(0, 0)},
		{"body": Vector2i.ZERO, "near": Vector2i(1, 0), "far": Vector2i(-1, 0)},
		{"body": down, "near": Vector2i(0, 0), "far": Vector2i(0, -1)},
	]
	var run := []
	for i in run_poses.size():
		var p: Dictionary = run_poses[i]
		run.append(_draw(layers, {"frame": i, "head": p.body, "body": p.body, "free": Vector2i.ZERO,
			"near": p.near, "far": p.far}))
	add.call("run", 10.0, true, run)
	add.call("jump", 1.0, false, [_draw(layers, {"frame": 0, "head": Vector2i.ZERO, "body": Vector2i.ZERO,
		"free": Vector2i.ZERO, "near": Vector2i(-1, -2), "far": Vector2i(0, -1)})])
	add.call("fall", 1.0, false, [_draw(layers, {"frame": 0, "head": Vector2i(0, -1), "body": Vector2i.ZERO,
		"free": Vector2i.ZERO, "near": Vector2i(-1, 0), "far": Vector2i(1, 0)})])
	add.call("hurt", 1.0, false, [_draw(layers, {"frame": 0, "head": Vector2i(1, 0), "body": Vector2i.ZERO,
		"free": Vector2i.ZERO, "near": Vector2i(0, 0), "far": Vector2i(1, -1)})])
	return sf
