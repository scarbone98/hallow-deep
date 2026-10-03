extends RefCounted
## Pictures placed in rooms: scenery cut from the CC0 packs (assets/cc0, see
## CREDITS.md) and the 8 Bit Evil Returns sprites. [texture, region, tint].

const CC0 := "res://assets/cc0/"
const SPR := "res://assets/sprites/"

const PROPS := {
	"cemetery_tree_big": [CC0 + "cemetery_objects.png", Rect2(784, 22, 176, 170), "#ffffff"],
	"tree_dead_1": [CC0 + "cemetery_objects.png", Rect2(193, 75, 166, 117), "#ffffff"],
	"tree_dead_2": [CC0 + "cemetery_objects.png", Rect2(608, 75, 166, 117), "#ffffff"],
	"swamp_tree": [CC0 + "cemetery_objects.png", Rect2(608, 75, 166, 117), "#5f8a64"],
	"statue": [CC0 + "cemetery_objects.png", Rect2(530, 117, 63, 75), "#ffffff"],
	"tombstone_1": [CC0 + "cemetery_objects.png", Rect2(19, 155, 21, 37), "#ffffff"],
	"tombstone_2": [CC0 + "cemetery_objects.png", Rect2(59, 152, 27, 40), "#ffffff"],
	"tombstone_3": [CC0 + "cemetery_objects.png", Rect2(109, 159, 27, 33), "#ffffff"],
	"tombstone_4": [CC0 + "cemetery_objects.png", Rect2(157, 154, 19, 38), "#ffffff"],
	"bush_large": [CC0 + "cemetery_objects.png", Rect2(372, 127, 77, 65), "#ffffff"],
	"gothic_window": [CC0 + "church_bg.png", Rect2(0, 0, 160, 192), "#b9a8d8"],
	"skull_pillar": [CC0 + "church_bg.png", Rect2(176, 0, 128, 192), "#b9a8d8"],
	"altar": [CC0 + "church_bg.png", Rect2(320, 0, 128, 192), "#b9a8d8"],
	"gargoyle": [CC0 + "church_bg.png", Rect2(464, 0, 80, 192), "#b9a8d8"],
	"torch_niche": [CC0 + "church_bg.png", Rect2(560, 0, 64, 192), "#ffffff"],
	"crystals_big": [CC0 + "grotto_middle.png", Rect2(61, 92, 135, 148), "#7d6f9c"],
	"crystals_small": [CC0 + "grotto_middle.png", Rect2(185, 0, 131, 100), "#7d6f9c"],
	"temple_door": [CC0 + "grotto_tiles.png", Rect2(201, 32, 151, 144), "#9a8cc0"],
	"mausoleum": [SPR + "mausoleum.png", Rect2(0, 0, 80, 116), "#ffffff"],
}

## A Sprite2D standing with its bottom centre on tile (tx, ty)'s top edge.
static func make(name: String, tx: int, ty: int) -> Sprite2D:
	var p: Array = PROPS[name]
	var s := Sprite2D.new()
	s.texture = load(p[0])
	s.region_enabled = true
	s.region_rect = p[1]
	s.modulate = Color(p[2])
	s.centered = false
	var r: Rect2 = p[1]
	s.position = Vector2(tx * 16 + 8 - r.size.x / 2.0, ty * 16 - r.size.y).floor()
	return s
