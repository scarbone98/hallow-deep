extends SceneTree
## godot --headless --path . -s tools/avatar_sheet.gd -- out.png
## Draws every outfit's animations into one sheet (rows: outfits; columns:
## idle, run, jump, fall, hurt frames) to check the generated poses.
func _init() -> void:
	var out := "shots/avatars.png"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: out = args[0]
	var files := AvatarBuilder.outfit_files()
	var anims := ["idle", "run", "jump", "fall", "hurt"]
	var sheet := Image.create(32 * 13, 48 * files.size(), false, Image.FORMAT_RGBA8)
	sheet.fill(Color("#3a3150"))
	for r in files.size():
		var sf := AvatarBuilder.build(AvatarBuilder.outfit_look(files[r]))
		var c := 0
		for a in anims:
			for i in sf.get_frame_count(a):
				if c < 13:
					sheet.blend_rect(sf.get_frame_texture(a, i).get_image(), Rect2i(0, 0, 32, 48), Vector2i(c * 32, r * 48))
				c += 1
	DirAccess.make_dir_recursive_absolute("shots")
	sheet.resize(sheet.get_width() * 3, sheet.get_height() * 3, Image.INTERPOLATE_NEAREST)
	sheet.save_png(out)
	print("saved ", out, " ", files.size(), " outfits")
	quit()
