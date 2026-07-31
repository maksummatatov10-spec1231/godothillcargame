class_name MainMenu
extends Control
## Небольшое стартовое меню, не похожее на системный диалог: фон остаётся
## видимым, а настройки открываются отдельной компактной карточкой.

signal manual_requested
signal evolution_requested
signal exit_requested

const BACKGROUND: Texture2D = preload("res://assets/sprites/background/SceneBG.png")
const CLOUDS: Texture2D = preload("res://assets/sprites/background/Clouds.png")

var settings_card: PanelContainer
var volume_slider: HSlider

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_background()
	_build_menu()
	_build_settings()

func _build_background() -> void:
	var sky: ColorRect = ColorRect.new()
	sky.color = Color("72cbed")
	sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(sky)
	var landscape: TextureRect = TextureRect.new()
	landscape.texture = BACKGROUND
	landscape.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	landscape.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	landscape.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	landscape.modulate = Color(1.0, 1.0, 1.0, 0.9)
	add_child(landscape)
	var clouds: TextureRect = TextureRect.new()
	clouds.texture = CLOUDS
	clouds.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	clouds.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	clouds.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	clouds.modulate = Color(1.0, 1.0, 1.0, 0.55)
	add_child(clouds)

func _build_menu() -> void:
	var panel: PanelContainer = PanelContainer.new()
	# Фиксированная карточка: PRESET_LEFT_WIDE растягивает высоту по родителю
	# и затем перезаписывает size, из-за чего кнопки уходили за нижний край.
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.position = Vector2(72.0, 105.0)
	panel.size = Vector2(410.0, 510.0)
	panel.add_theme_stylebox_override("panel", UIStyle.panel_style(UIStyle.PANEL_DARK, 22))
	add_child(panel)
	var content: VBoxContainer = VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 13)
	panel.add_child(content)
	var eyebrow: Label = UIStyle.make_label("2D • ФИЗИКА • ГЕНЕТИЧЕСКИЙ АЛГОРИТМ", 12, UIStyle.ACCENT)
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(eyebrow)
	var title: Label = UIStyle.make_label("HILL\nMOTION", 42, UIStyle.INK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)
	var subtitle_text: String = "Покоряйте холмы сами — или научите машину делать это лучше вас."
	var subtitle: Label = UIStyle.make_label(subtitle_text, 15, UIStyle.MUTED)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(subtitle)
	var manual: Button = UIStyle.make_button("Играть")
	manual.pressed.connect(_on_manual)
	content.add_child(manual)
	var evolution: Button = UIStyle.make_button("Эволюция", Color("8fd4ff"))
	evolution.pressed.connect(_on_evolution)
	content.add_child(evolution)
	var settings: Button = UIStyle.make_button("Настройки", Color("c9ddf0"))
	settings.pressed.connect(_on_settings)
	content.add_child(settings)
	var exit_button: Button = UIStyle.make_button("Выход", UIStyle.DANGER)
	exit_button.pressed.connect(_on_exit)
	content.add_child(exit_button)
	var record_text: String = "Рекорд: %d м  •  Монеты: %d" % [
		int(floor(Config.record_distance_m)), Config.record_coins
	]
	var record: Label = UIStyle.make_label(record_text, 13, UIStyle.GOLD)
	record.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(record)

func _build_settings() -> void:
	settings_card = PanelContainer.new()
	# Обе оси anchor совпадают, поэтому размер не будет переписан после _ready().
	settings_card.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	settings_card.position = Vector2(-420.0, 170.0)
	settings_card.size = Vector2(350.0, 310.0)
	settings_card.add_theme_stylebox_override("panel", UIStyle.panel_style(UIStyle.PANEL_DARK, 18))
	settings_card.visible = false
	add_child(settings_card)
	var rows: VBoxContainer = VBoxContainer.new()
	rows.add_theme_constant_override("separation", 12)
	settings_card.add_child(rows)
	var header: HBoxContainer = HBoxContainer.new()
	var title: Label = UIStyle.make_label("Настройки", 24, UIStyle.ACCENT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close: Button = UIStyle.make_button("×", UIStyle.DANGER)
	close.custom_minimum_size = Vector2(36.0, 34.0)
	close.pressed.connect(_on_close_settings)
	header.add_child(close)
	rows.add_child(header)
	rows.add_child(UIStyle.make_label("Общая громкость", 14))
	volume_slider = HSlider.new()
	volume_slider.min_value = -40.0
	volume_slider.max_value = 0.0
	volume_slider.step = 1.0
	volume_slider.value = Config.master_volume_db
	volume_slider.value_changed.connect(_on_volume_changed)
	rows.add_child(volume_slider)
	var controls_text: String = "Управление\nГаз: D, → или Пробел\n"
	controls_text += "Тормоз / задний ход: A или ←\nПауза: Esc"
	rows.add_child(UIStyle.make_label(controls_text, 14, UIStyle.MUTED))
	var reset_record: Button = UIStyle.make_button("Сбросить рекорд", Color("c9ddf0"))
	reset_record.pressed.connect(_on_reset_record)
	rows.add_child(reset_record)

func _on_manual() -> void:
	manual_requested.emit()

func _on_evolution() -> void:
	evolution_requested.emit()

func _on_settings() -> void:
	settings_card.visible = true

func _on_close_settings() -> void:
	settings_card.visible = false

func _on_volume_changed(value: float) -> void:
	Config.master_volume_db = value
	AudioServer.set_bus_volume_db(0, value)
	Config.save_progress()

func _on_reset_record() -> void:
	Config.record_distance_m = 0.0
	Config.record_coins = 0
	Config.save_progress()

func _on_exit() -> void:
	exit_requested.emit()
