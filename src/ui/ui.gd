class_name Ui
extends RefCounted
## Shared UI bits.

static var _font: Font

static func font() -> Font:
	if _font == null:
		_font = load("res://assets/fonts/PressStart2P.ttf")
	return _font

static func label(text: String, size := 8, col := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.04, 0.02, 0.07))
	l.add_theme_constant_override("outline_size", 4)
	l.add_theme_constant_override("line_spacing", 3)
	return l

static func panel(col := Color(0.05, 0.03, 0.09, 0.92), border := Color(0.42, 0.33, 0.6)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = col
	s.border_color = border
	s.set_border_width_all(1)
	s.set_content_margin_all(6)
	return s
