class_name HUD
extends Control
## Игровой HUD ручного режима. Кнопки газа и тормоза также работают мышью/тачем.

signal pause_requested
signal restart_requested
signal menu_requested

var distance_label: Label
var speed_label: Label
var coin_label: Label
var record_label: Label
var fuel_bar: ProgressBar
var fuel_caption: Label
var accelerate_pressed: bool = false
var brake_pressed: bool = false
var result_overlay: Control
var result_title: Label
var result_details: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_status_panel()
	_build_controls()
	_build_result_overlay()

func _build_status_panel() -> void:
	var card: PanelContainer = PanelContainer.new()
	card.position = Vector2(22.0, 22.0)
	card.custom_minimum_size = Vector2(280.0, 180.0)
	card.add_theme_stylebox_override("panel", UIStyle.panel_style())
	add_child(card)
	var rows: VBoxContainer = VBoxContainer.new()
	rows.add_theme_constant_override("separation", 6)
	card.add_child(rows)
	rows.add_child(UIStyle.make_label("ЗАЕЗД", 14, UIStyle.ACCENT))
	distance_label = UIStyle.make_label("Дистанция: 0 м", 23)
	rows.add_child(distance_label)
	speed_label = UIStyle.make_label("Скорость: 0 км/ч", 16, UIStyle.MUTED)
	rows.add_child(speed_label)
	coin_label = UIStyle.make_label("Монеты: 0", 16, UIStyle.GOLD)
	rows.add_child(coin_label)
	record_label = UIStyle.make_label("Рекорд: 0 м", 14, UIStyle.MUTED)
	rows.add_child(record_label)
	fuel_caption = UIStyle.make_label("Топливо 100%", 14)
	rows.add_child(fuel_caption)
	fuel_bar = ProgressBar.new()
	fuel_bar.max_value = Car.FULL_FUEL
	fuel_bar.value = Car.FULL_FUEL
	UIStyle.style_progress(fuel_bar, UIStyle.ACCENT)
	rows.add_child(fuel_bar)

func _build_controls() -> void:
	var hint_text: String = "A / ← — тормоз и задний ход     D / → / Пробел — газ"
	var hint: Label = UIStyle.make_label(hint_text, 14, UIStyle.MUTED)
	hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint.position = Vector2(-220.0, -52.0)
	hint.size = Vector2(440.0, 28.0)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hint)
	var brake_button: Button = UIStyle.make_button("◀  ТОРМОЗ", UIStyle.DANGER)
	brake_button.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	brake_button.position = Vector2(25.0, -98.0)
	brake_button.size = Vector2(154.0, 60.0)
	brake_button.button_down.connect(_on_brake_down)
	brake_button.button_up.connect(_on_brake_up)
	add_child(brake_button)
	var gas_button: Button = UIStyle.make_button("ГАЗ  ▶", UIStyle.ACCENT)
	gas_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	gas_button.position = Vector2(-179.0, -98.0)
	gas_button.size = Vector2(154.0, 60.0)
	gas_button.button_down.connect(_on_gas_down)
	gas_button.button_up.connect(_on_gas_up)
	add_child(gas_button)
	var pause_button: Button = UIStyle.make_button("Ⅱ", Color("c9ddf0"))
	pause_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	pause_button.position = Vector2(-74.0, 23.0)
	pause_button.size = Vector2(48.0, 42.0)
	pause_button.pressed.connect(_on_pause_pressed)
	add_child(pause_button)

func _build_result_overlay() -> void:
	result_overlay = Control.new()
	result_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	result_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	result_overlay.visible = false
	var shade: ColorRect = ColorRect.new()
	shade.color = Color("071019cc")
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	result_overlay.add_child(shade)
	var card: PanelContainer = PanelContainer.new()
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.position = Vector2(-210.0, -175.0)
	card.size = Vector2(420.0, 350.0)
	card.add_theme_stylebox_override("panel", UIStyle.panel_style(UIStyle.PANEL_DARK, 20))
	result_overlay.add_child(card)
	var content: VBoxContainer = VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 12)
	card.add_child(content)
	var alarm: TextureRect = TextureRect.new()
	alarm.texture = preload("res://assets/sprites/background/Alarm.png")
	alarm.custom_minimum_size = Vector2(56.0, 56.0)
	alarm.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	alarm.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	content.add_child(alarm)
	result_title = UIStyle.make_label("Заезд завершён", 28, UIStyle.DANGER)
	result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(result_title)
	result_details = UIStyle.make_label("", 17, UIStyle.INK)
	result_details.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(result_details)
	var restart_button: Button = UIStyle.make_button("Заново")
	restart_button.pressed.connect(_on_restart_pressed)
	content.add_child(restart_button)
	var menu_button: Button = UIStyle.make_button("В главное меню", Color("c9ddf0"))
	menu_button.pressed.connect(_on_menu_pressed)
	content.add_child(menu_button)
	add_child(result_overlay)

func set_stats(distance_m: float, speed_kmh: float, coins: int, record_m: float) -> void:
	if distance_label == null:
		return
	distance_label.text = "Дистанция: %d м" % int(floor(distance_m))
	speed_label.text = "Скорость: %d км/ч" % int(round(speed_kmh))
	coin_label.text = "Монеты: %d" % coins
	record_label.text = "Рекорд: %d м" % int(floor(maxf(record_m, distance_m)))

func set_fuel(current: float, maximum: float) -> void:
	if fuel_bar == null:
		return
	fuel_bar.max_value = maximum
	fuel_bar.value = current
	fuel_caption.text = "Топливо %d%%" % int(round(current / maximum * 100.0))
	var tint: Color = UIStyle.ACCENT if current > 35.0 else UIStyle.DANGER
	UIStyle.style_progress(fuel_bar, tint)

func show_result(reason: String, distance_m: float, coins: int, is_new_record: bool) -> void:
	accelerate_pressed = false
	brake_pressed = false
	result_title.text = "Новый рекорд!" if is_new_record else "Заезд завершён"
	var title_color: Color = UIStyle.GOLD if is_new_record else UIStyle.DANGER
	result_title.add_theme_color_override("font_color", title_color)
	result_details.text = "%s\n\nДистанция: %d м\nМонеты: %d" % [reason, int(floor(distance_m)), coins]
	result_overlay.visible = true

func _on_gas_down() -> void:
	accelerate_pressed = true

func _on_gas_up() -> void:
	accelerate_pressed = false

func _on_brake_down() -> void:
	brake_pressed = true

func _on_brake_up() -> void:
	brake_pressed = false

func _on_pause_pressed() -> void:
	pause_requested.emit()

func _on_restart_pressed() -> void:
	restart_requested.emit()

func _on_menu_pressed() -> void:
	menu_requested.emit()
