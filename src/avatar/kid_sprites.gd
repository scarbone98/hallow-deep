class_name KidSprites
extends RefCounted
## The four kids (Alex, Joe, Jon, Matt) drawn from 3D-rendered sprite sheets: every state the
## game plays (idle, run, jump, fall, land, double jump, hurt, death, the sword combo, up / down /
## air slashes...). Made by the spritechar pipeline and copied in by tools/sync_kids.sh.
## Each sheet has a JSON atlas: frame size, a shared pivot (feet), and per animation its row,
## frame count, fps and whether it loops.

const ROOT := "res://assets/kids/"
const KIDS := ["alex", "joe", "jon", "matt"]

const OUTFITS := {"alex": "01-alex.json", "joe": "02-joe.json", "jon": "03-jon.json", "matt": "04-matt.json"}

## The outfit look for a kid (used for its name and as the avatar fallback).
static func look_for(kid: String) -> Dictionary:
	return AvatarBuilder.outfit_look(OUTFITS[kid])

## The kid this look is (by outfit name), or "" for anyone else.
static func kid_for(look: Dictionary) -> String:
	var n := str(look.get("name", "")).to_lower()
	return n if n in KIDS and ResourceLoader.exists(ROOT + n + "_sheet.png") else ""

## {frames: SpriteFrames, pivot: Vector2}
static func build(kid: String) -> Dictionary:
	var f := FileAccess.open(ROOT + kid + "_sheet.json", FileAccess.READ)
	var atlas: Dictionary = JSON.parse_string(f.get_as_text())
	var tex: Texture2D = load(ROOT + kid + "_sheet.png")
	var fw := int(atlas.frameWidth)
	var fh := int(atlas.frameHeight)
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	for anim in atlas.animations:
		var a: Dictionary = atlas.animations[anim]
		sf.add_animation(anim)
		sf.set_animation_speed(anim, float(a.fps))
		sf.set_animation_loop(anim, bool(a.loop))
		for i in int(a.frames):
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(i * fw, int(a.row) * fh, fw, fh)
			sf.add_frame(anim, at)
	var p: Array = atlas.get("pivot", [fw / 2, fh])
	return {"frames": sf, "pivot": Vector2(p[0], p[1])}
