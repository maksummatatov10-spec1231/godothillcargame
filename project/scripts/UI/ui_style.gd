class_name UIStyle
extends RefCounted
## Небольшая палитра и фабрика стилей, чтобы все панели выглядели единообразно.

const INK: Color = Color("eaf4ff")
const MUTED: Color = Color("9eb4ca")
const PANEL: Color = Color("172536e8")
const PANEL_DARK: Color = Color("0d1723ee")
const ACCENT: Color = Color("37d6a0")
const ACCENT_HOVER: Color = Color("68efbd")
const DANGER: Color = Color("ff6675")
const GOLD: Color = Color("ffd45a")

static func panel_style(color: Color = PANEL, radius: int = 16) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color("6b8daa66")
	style.content_margin_left = 14.0
	style.content_margin_top = 10.0
	style.content_margin_right = 14.0
	style.content_margin_bottom = 10.0
	return style

static func make_label(caption: String, font_size: int = 16, tint: Color = INK) -> Label:
	var label: Label = Label.new()
	label.text = caption
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", tint)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

static func make_button(caption: String, emphasis: Color = ACCENT) -> Button:
	var button: Button = Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(0.0, 42.0)
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", Color("10261f"))
	button.add_theme_stylebox_override("normal", panel_style(emphasis, 12))
	button.add_theme_stylebox_override("hover", panel_style(emphasis.lightened(0.13), 12))
	button.add_theme_stylebox_override("pressed", panel_style(emphasis.darkened(0.14), 12))
	button.add_theme_stylebox_override("disabled", panel_style(Color("3f5263"), 12))
	return button

static func make_section(title: String) -> VBoxContainer:
	var section: VBoxContainer = VBoxContainer.new()
	section.add_theme_constant_override("separation", 7)
	var header: Label = make_label(title, 15, ACCENT)
	section.add_child(header)
	return section

static func style_progress(bar: ProgressBar, tint: Color) -> void:
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(220.0, 16.0)
	bar.add_theme_stylebox_override("background", panel_style(Color("071019cc"), 8))
	bar.add_theme_stylebox_override("fill", panel_style(tint, 8))
