class_name SidePanel
extends Control
## Сворачиваемая правая панель. Для каждой числовой настройки есть и слайдер,
## и SpinBox: значение можно двигать, печатать вручную или менять стрелками.

signal setting_changed(setting_name: String, new_value: float)
signal activation_changed(new_name: String)
signal pause_toggle_requested
signal restart_generation_requested
signal new_track_requested
signal menu_requested
signal close_requested

var syncing: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = -392.0
	offset_right = 0.0
	offset_top = 0.0
	offset_bottom = 0.0
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_panel()

func toggle() -> void:
	visible = not visible

func _build_panel() -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel", UIStyle.panel_style(UIStyle.PANEL_DARK, 0))
	add_child(panel)
	var outer: VBoxContainer = VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	panel.add_child(outer)
	var header: HBoxContainer = HBoxContainer.new()
	var title: Label = UIStyle.make_label("НАСТРОЙКИ ЭВОЛЮЦИИ", 17, UIStyle.ACCENT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close_button: Button = UIStyle.make_button("×", UIStyle.DANGER)
	close_button.custom_minimum_size = Vector2(38.0, 34.0)
	close_button.pressed.connect(_on_close)
	header.add_child(close_button)
	outer.add_child(header)
	var note_text: String = "Физика, сеть и состав применяются "
	note_text += "при следующем запуске поколения."
	var note: Label = UIStyle.make_label(note_text, 12, UIStyle.MUTED)
	outer.add_child(note)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	var content: VBoxContainer = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 13)
	scroll.add_child(content)
	_add_simulation_section(content)
	_add_generation_section(content)
	_add_network_section(content)
	_add_physics_section(content)
	_add_track_section(content)

func _add_simulation_section(parent: VBoxContainer) -> void:
	var section: VBoxContainer = UIStyle.make_section("СИМУЛЯЦИЯ")
	parent.add_child(section)
	_add_numeric(section, "Скорость игры", "simulation_speed", 1.0, 100.0, 1.0)
	var pause: Button = UIStyle.make_button("Пауза / продолжить", Color("c9ddf0"))
	pause.pressed.connect(_on_pause_toggle)
	section.add_child(pause)
	var restart: Button = UIStyle.make_button("Перезапустить поколение", UIStyle.DANGER)
	restart.pressed.connect(_on_restart_generation)
	section.add_child(restart)
	var track: Button = UIStyle.make_button("Новая трасса + перезапуск", Color("c9ddf0"))
	track.pressed.connect(_on_new_track)
	section.add_child(track)
	var menu: Button = UIStyle.make_button("В главное меню", UIStyle.DANGER)
	menu.pressed.connect(_on_menu)
	section.add_child(menu)

func _add_generation_section(parent: VBoxContainer) -> void:
	var section: VBoxContainer = UIStyle.make_section("ПОКОЛЕНИЕ")
	parent.add_child(section)
	_add_numeric(section, "Размер поколения", "population_size", 10.0, 150.0, 1.0)
	_add_numeric(section, "Элит", "elites", 1.0, 20.0, 1.0)
	_add_numeric(section, "Вероятность мутации", "mutation_rate", 0.0, 1.0, 0.01)
	_add_numeric(section, "Сила мутации", "mutation_strength", 0.01, 2.0, 0.01)
	_add_numeric(section, "Турнир", "tournament_size", 2.0, 12.0, 1.0)
	_add_numeric(section, "Иммигранты", "immigrant_ratio", 0.0, 0.50, 0.01)
	_add_numeric(section, "Таймаут машины, с", "timeout", 5.0, 120.0, 1.0)
	_add_numeric(section, "Таймаут без движения, с", "idle_timeout", 1.0, 30.0, 0.5)

func _add_network_section(parent: VBoxContainer) -> void:
	var section: VBoxContainer = UIStyle.make_section("НЕЙРОСЕТЬ")
	parent.add_child(section)
	_add_numeric(section, "Скрытых слоёв", "hidden_layers", 1.0, 4.0, 1.0)
	_add_numeric(section, "Нейронов в слое", "hidden_neurons", 4.0, 32.0, 1.0)
	var activation_row: HBoxContainer = HBoxContainer.new()
	var activation_label: Label = UIStyle.make_label("Активация", 13)
	activation_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	activation_row.add_child(activation_label)
	var activation: OptionButton = OptionButton.new()
	activation.add_item("tanh")
	activation.add_item("ReLU")
	activation.select(0 if Config.activation_name == "tanh" else 1)
	activation.item_selected.connect(_on_activation_selected.bind(activation))
	activation_row.add_child(activation)
	section.add_child(activation_row)
	var visual_toggle: CheckButton = CheckButton.new()
	visual_toggle.text = "Показывать сеть"
	visual_toggle.button_pressed = Config.show_network
	visual_toggle.toggled.connect(_on_network_visibility)
	section.add_child(visual_toggle)

func _add_physics_section(parent: VBoxContainer) -> void:
	var section: VBoxContainer = UIStyle.make_section("ФИЗИКА МАШИНЫ")
	parent.add_child(section)
	_add_numeric(section, "Масса кузова", "body_mass", 2.0, 20.0, 0.1)
	_add_numeric(section, "Масса колеса", "wheel_mass", 0.4, 5.0, 0.1)
	_add_numeric(section, "Мощность двигателя", "engine_torque", 10000.0, 300000.0, 1000.0)
	_add_numeric(section, "Макс. скорость колеса", "max_wheel_speed", 10.0, 100.0, 1.0)
	_add_numeric(section, "Трение", "wheel_friction", 0.2, 8.0, 0.1)
	_add_numeric(section, "Жёсткость подвески", "suspension_stiffness", 100.0, 2000.0, 10.0)
	_add_numeric(section, "Демпфирование", "suspension_damping", 0.1, 30.0, 0.1)
	_add_numeric(section, "Свободная длина пружины", "suspension_rest_length", 48.0, 66.0, 0.5)
	_add_numeric(section, "Гравитация", "gravity", 600.0, 2600.0, 50.0)

func _add_track_section(parent: VBoxContainer) -> void:
	var section: VBoxContainer = UIStyle.make_section("ТРАССА")
	parent.add_child(section)
	_add_numeric(section, "Сложность", "terrain_difficulty", 0.30, 2.5, 0.05)
	_add_numeric(section, "Высота холмов", "hill_height", 40.0, 360.0, 5.0)
	_add_numeric(section, "Частота неровностей", "terrain_frequency", 0.35, 2.5, 0.05)
	_add_numeric(section, "Плотность канистр", "fuel_density", 0.05, 1.0, 0.01)
	_add_numeric(section, "Плотность монет", "coin_density", 0.05, 1.0, 0.01)
	_add_numeric(section, "Сид", "seed", 1.0, 99999999.0, 1.0)

func _add_numeric(
	parent: VBoxContainer, caption: String, setting_name: String,
	minimum: float, maximum: float, step: float
) -> void:
	var group: VBoxContainer = VBoxContainer.new()
	group.add_theme_constant_override("separation", 2)
	var line: HBoxContainer = HBoxContainer.new()
	var label: Label = UIStyle.make_label(caption, 13)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(label)
	var input: SpinBox = SpinBox.new()
	input.min_value = minimum
	input.max_value = maximum
	input.step = step
	input.value = Config.get_numeric_setting(setting_name)
	input.allow_greater = false
	input.allow_lesser = false
	input.custom_minimum_size = Vector2(102.0, 28.0)
	line.add_child(input)
	group.add_child(line)
	var slider: HSlider = HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.value = input.value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(_on_slider_changed.bind(input, setting_name))
	input.value_changed.connect(_on_input_changed.bind(slider, setting_name))
	group.add_child(slider)
	parent.add_child(group)

func _on_slider_changed(value: float, input: SpinBox, setting_name: String) -> void:
	if syncing:
		return
	syncing = true
	input.value = value
	Config.set_numeric_setting(setting_name, value)
	setting_changed.emit(setting_name, value)
	syncing = false

func _on_input_changed(value: float, slider: HSlider, setting_name: String) -> void:
	if syncing:
		return
	syncing = true
	slider.value = value
	Config.set_numeric_setting(setting_name, value)
	setting_changed.emit(setting_name, value)
	syncing = false

func _on_activation_selected(_index: int, activation: OptionButton) -> void:
	var selected_name: String = activation.get_item_text(activation.selected)
	Config.set_activation(selected_name)
	activation_changed.emit(selected_name)

func _on_network_visibility(value: bool) -> void:
	Config.show_network = value
	setting_changed.emit("show_network", 1.0 if value else 0.0)

func _on_pause_toggle() -> void:
	pause_toggle_requested.emit()

func _on_restart_generation() -> void:
	restart_generation_requested.emit()

func _on_new_track() -> void:
	new_track_requested.emit()

func _on_menu() -> void:
	menu_requested.emit()

func _on_close() -> void:
	visible = false
	close_requested.emit()
