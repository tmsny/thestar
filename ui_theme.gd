class_name UiTheme
extends RefCounted

## Eigenstaendiges, hochwertiges UI-Theme fuer Menues und HUD.
## Einmalig gebaut und ueber `UiTheme.get_theme()` an die UI-Wurzeln gesetzt.
## Ersetzt bewusst den Godot-Standard-Look (dunkles "Glass"-Panel + Tuerkis-Akzent).

const BG_DEEP: Color = Color(0.027, 0.045, 0.063, 1.0)
const PANEL_BG: Color = Color(0.055, 0.08, 0.104, 0.97)
const PANEL_BG_SOFT: Color = Color(0.078, 0.108, 0.133, 0.95)
const BUTTON_BG: Color = Color(0.086, 0.117, 0.143, 0.92)
const BUTTON_BG_HOVER: Color = Color(0.13, 0.2, 0.22, 0.98)
const BUTTON_BG_PRESSED: Color = Color(0.13, 0.42, 0.4, 0.98)
const ACCENT: Color = Color(0.29, 0.94, 0.82, 1.0)
const ACCENT_SOFT: Color = Color(0.24, 0.66, 0.62, 1.0)
const ACCENT_DIM: Color = Color(0.15, 0.36, 0.36, 1.0)
const BORDER: Color = Color(0.16, 0.32, 0.33, 0.85)
const TEXT: Color = Color(0.9, 0.95, 0.94, 1.0)
const TEXT_MUTED: Color = Color(0.6, 0.71, 0.72, 1.0)
const WARN: Color = Color(0.98, 0.79, 0.4, 1.0)

static var _theme: Theme = null

static func get_theme() -> Theme:
	if _theme == null:
		_theme = _build()
	return _theme

static func box(bg: Color, border: Color, radius: int, border_w: int, margin_h: float = 0.0, margin_v: float = 0.0) -> StyleBoxFlat:
	var b: StyleBoxFlat = StyleBoxFlat.new()
	b.bg_color = bg
	b.border_color = border
	b.set_border_width_all(border_w)
	b.set_corner_radius_all(radius)
	b.content_margin_left = margin_h
	b.content_margin_right = margin_h
	b.content_margin_top = margin_v
	b.content_margin_bottom = margin_v
	return b

static func groove(bg: Color) -> StyleBoxFlat:
	var b: StyleBoxFlat = StyleBoxFlat.new()
	b.bg_color = bg
	b.set_corner_radius_all(4)
	b.content_margin_top = 4.0
	b.content_margin_bottom = 4.0
	b.content_margin_left = 4.0
	b.content_margin_right = 4.0
	return b

static func grabber_texture(diameter: int, fill: Color, ring: Color) -> ImageTexture:
	var img: Image = Image.create_empty(diameter, diameter, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c: float = (diameter - 1) * 0.5
	for y: int in range(diameter):
		for x: int in range(diameter):
			var d: float = Vector2(float(x) - c, float(y) - c).length()
			if d <= c - 3.0:
				img.set_pixel(x, y, fill)
			elif d <= c:
				img.set_pixel(x, y, ring)
	return ImageTexture.create_from_image(img)

static func _build() -> Theme:
	var theme: Theme = Theme.new()
	theme.default_font_size = 16
	_style_buttons(theme)
	_style_panels(theme)
	_style_sliders(theme)
	_style_misc(theme)
	return theme

static func _style_buttons(theme: Theme) -> void:
	var normal: StyleBoxFlat = box(BUTTON_BG, BORDER, 10, 1, 20.0, 10.0)
	var hover: StyleBoxFlat = box(BUTTON_BG_HOVER, ACCENT, 10, 1, 20.0, 10.0)
	var pressed: StyleBoxFlat = box(BUTTON_BG_PRESSED, ACCENT, 10, 1, 20.0, 10.0)
	var disabled: StyleBoxFlat = box(Color(0.09, 0.11, 0.12, 0.55), Color(0.18, 0.22, 0.23, 0.6), 10, 1, 20.0, 10.0)
	var focus: StyleBoxFlat = box(Color(0, 0, 0, 0), ACCENT, 13, 2)
	focus.draw_center = false
	for type_name: String in ["Button", "OptionButton", "MenuButton"]:
		theme.set_stylebox("normal", type_name, normal)
		theme.set_stylebox("hover", type_name, hover)
		theme.set_stylebox("pressed", type_name, pressed)
		theme.set_stylebox("disabled", type_name, disabled)
		theme.set_stylebox("focus", type_name, focus)
		theme.set_color("font_color", type_name, TEXT)
		theme.set_color("font_hover_color", type_name, Color(1, 1, 1))
		theme.set_color("font_pressed_color", type_name, Color(1, 1, 1))
		theme.set_color("font_focus_color", type_name, TEXT)
		theme.set_color("font_disabled_color", type_name, Color(0.5, 0.55, 0.56, 0.7))
		theme.set_font_size("font_size", type_name, 18)
		theme.set_constant("h_separation", type_name, 10)

static func _style_panels(theme: Theme) -> void:
	var panel: StyleBoxFlat = box(PANEL_BG, BORDER, 16, 1, 0.0, 0.0)
	panel.shadow_color = Color(0, 0, 0, 0.5)
	panel.shadow_size = 14
	panel.shadow_offset = Vector2(0, 6)
	theme.set_stylebox("panel", "Panel", panel)
	theme.set_stylebox("panel", "PanelContainer", panel)
	theme.set_stylebox("panel", "ScrollContainer", box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0))

static func _style_sliders(theme: Theme) -> void:
	theme.set_stylebox("slider", "HSlider", groove(Color(0.08, 0.11, 0.13, 0.9)))
	theme.set_stylebox("grabber_area", "HSlider", groove(ACCENT_SOFT))
	theme.set_stylebox("grabber_area_highlight", "HSlider", groove(ACCENT))
	var grabber: ImageTexture = grabber_texture(18, ACCENT, Color(0.02, 0.05, 0.06))
	theme.set_icon("grabber", "HSlider", grabber)
	theme.set_icon("grabber_highlight", "HSlider", grabber)
	theme.set_constant("center_grabber", "HSlider", 1)

static func _style_misc(theme: Theme) -> void:
	theme.set_stylebox("background", "ProgressBar", box(Color(0.08, 0.11, 0.13, 0.9), Color(0, 0, 0, 0), 6, 0))
	theme.set_stylebox("fill", "ProgressBar", box(ACCENT, Color(0, 0, 0, 0), 6, 0))
	theme.set_color("font_color", "ProgressBar", TEXT)

	theme.set_stylebox("normal", "LineEdit", box(BUTTON_BG, BORDER, 8, 1, 12.0, 8.0))
	theme.set_stylebox("focus", "LineEdit", box(BUTTON_BG, ACCENT, 8, 1, 12.0, 8.0))
	theme.set_color("font_color", "LineEdit", TEXT)
	theme.set_color("caret_color", "LineEdit", ACCENT)

	theme.set_stylebox("scroll", "VScrollBar", box(Color(0.06, 0.09, 0.1, 0.55), Color(0, 0, 0, 0), 5, 0, 3.0, 0.0))
	theme.set_stylebox("grabber", "VScrollBar", box(Color(0.22, 0.5, 0.47, 0.9), Color(0, 0, 0, 0), 5, 0, 3.0, 0.0))
	theme.set_stylebox("grabber_highlight", "VScrollBar", box(ACCENT, Color(0, 0, 0, 0), 5, 0, 3.0, 0.0))
	theme.set_stylebox("grabber_pressed", "VScrollBar", box(ACCENT, Color(0, 0, 0, 0), 5, 0, 3.0, 0.0))

	theme.set_color("font_color", "Label", TEXT)
	theme.set_font_size("font_size", "Label", 16)
	theme.set_color("font_color", "CheckBox", TEXT)
	theme.set_color("font_color", "CheckButton", TEXT)
	theme.set_color("font_hover_color", "CheckButton", Color(1, 1, 1))