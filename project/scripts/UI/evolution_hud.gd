class_name EvolutionHUD
extends Control
## HUD обучения отделён от панели настроек: цифры не перекрывают заезд, а
## настройка остаётся сворачиваемой справа.

signal settings_requested
signal pause_requested
signal next_car_requested
signal previous_car_requested

const NETWORK_SCENE: PackedScene = preload("res://scenes/UI/NetworkVisualizer.tscn")

var generation_label: Label
var alive_label: Label
var current_best_label: Label
var all_time_best_label: Label
var fitness_label: Label
var average_label: Label
var speed_label: Label
var network_view: NetworkVisualizer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_metrics()
	_build_actions()
	_build_network()

func _build_metrics() -> void:
	var card: PanelContainer = PanelContainer.new()
	card.position = Vector2(22.0, 22.0)
	card.custom_minimum_size = Vector2(306.0, 218.0)
	card.add_theme_stylebox_override("panel", UIStyle.panel_style())
	add_child(card)
	var rows: VBoxContainer = VBoxContainer.new()
	rows.add_theme_constant_override("separation", 6)
	card.add_child(rows)
	rows.add_child(UIStyle.make_label("ЭВОЛЮЦИОННАЯ ЛАБОРАТОРИЯ", 13, UIStyle.ACCENT))
	generation_label = UIStyle.make_label("Поколение: 1", 23)
	rows.add_child(generation_label)
	alive_label = UIStyle.make_label("Живы: 0 / 0", 16)
	rows.add_child(alive_label)
	current_best_label = UIStyle.make_label("Лучший сейчас: 0 м", 15, UIStyle.GOLD)
	rows.add_child(current_best_label)
	all_time_best_label = UIStyle.make_label("Лучший за всё время: 0 м", 14, UIStyle.MUTED)
	rows.add_child(all_time_best_label)
	fitness_label = UIStyle.make_label("Fitness: 0", 14, UIStyle.MUTED)
	rows.add_child(fitness_label)
	average_label = UIStyle.make_label("Средний fitness: 0", 14, UIStyle.MUTED)
	rows.add_child(average_label)
	speed_label = UIStyle.make_label("Скорость: x1", 13, UIStyle.MUTED)
	rows.add_child(speed_label)

func _build_actions() -> void:
	var gear: Button = UIStyle.make_button("⚙", Color("c9ddf0"))
	gear.set_anchors_preset(Control.PRESET_RIGHT_TOP)
	gear.position = Vector2(-72.0, 22.0)
	gear.size = Vector2(48.0, 42.0)
	gear.pressed.connect(_on_settings)
	add_child(gear)
	var pause: Button = UIStyle.make_button("Ⅱ", UIStyle.ACCENT)
	pause.set_anchors_preset(Control.PRESET_RIGHT_TOP)
	pause.position = Vector2(-128.0, 22.0)
	pause.size = Vector2(48.0, 42.0)
	pause.pressed.connect(_on_pause)
	add_child(pause)
	var back: Button = UIStyle.make_button("‹", Color("c9ddf0"))
	back.position = Vector2(340.0, 198.0)
	back.size = Vector2(36.0, 32.0)
	back.pressed.connect(_on_previous)
	add_child(back)
	var forward: Button = UIStyle.make_button("›", Color("c9ddf0"))
	forward.position = Vector2(382.0, 198.0)
	forward.size = Vector2(36.0, 32.0)
	forward.pressed.connect(_on_next)
	add_child(forward)

func _build_network() -> void:
	network_view = NETWORK_SCENE.instantiate() as NetworkVisualizer
	network_view.set_anchors_preset(Control.PRESET_RIGHT_BOTTOM)
	network_view.position = Vector2(-392.0, -282.0)
	network_view.size = Vector2(370.0, 260.0)
	add_child(network_view)

func set_metrics(
	generation: int, alive: int, total: int, current_best: float,
	best_ever: float, current_fitness: float, average_fitness: float,
	requested_speed: float, actual_speed: float
) -> void:
	generation_label.text = "Поколение: %d" % generation
	alive_label.text = "Живы: %d / %d" % [alive, total]
	current_best_label.text = "Лучший сейчас: %d м" % int(floor(current_best))
	all_time_best_label.text = "Лучший за всё время: %d м" % int(floor(best_ever))
	fitness_label.text = "Лучший fitness: %d" % int(round(current_fitness))
	average_label.text = "Средний fitness: %d" % int(round(average_fitness))
	if requested_speed > actual_speed:
		speed_label.text = "Скорость: x%d (физика x%d)" % [int(requested_speed), int(actual_speed)]
	else:
		speed_label.text = "Скорость: x%d" % int(requested_speed)

func set_network(network: NeuralNetwork) -> void:
	if network_view != null:
		network_view.set_network(network)

func set_network_visible(value: bool) -> void:
	if network_view != null:
		network_view.set_network_visible(value)

func _on_settings() -> void:
	settings_requested.emit()

func _on_pause() -> void:
	pause_requested.emit()

func _on_next() -> void:
	next_car_requested.emit()

func _on_previous() -> void:
	previous_car_requested.emit()
