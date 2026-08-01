class_name Game
extends Node2D
## Оркестратор одного заезда. Ручной режим создаёт одну машину и предметы;
## режим обучения передаёт трассу EvolutionManager и не смешивает их логику.

signal restart_requested(selected_mode: int)
signal menu_requested

enum Mode { MANUAL, EVOLUTION }

const CAR_SCENE: PackedScene = preload("res://scenes/Car.tscn")
const COIN_SCENE: PackedScene = preload("res://scenes/Coin.tscn")
const FUEL_SCENE: PackedScene = preload("res://scenes/FuelCan.tscn")
const CHECKPOINT_SCENE: PackedScene = preload("res://scenes/Checkpoint.tscn")
const HUD_SCENE: PackedScene = preload("res://scenes/UI/HUD.tscn")
const EVOLUTION_HUD_SCENE: PackedScene = preload("res://scenes/UI/EvolutionHUD.tscn")
const SIDE_PANEL_SCENE: PackedScene = preload("res://scenes/UI/SidePanel.tscn")
const PAUSE_MENU_SCENE: PackedScene = preload("res://scenes/UI/PauseMenu.tscn")
const COIN_TEXTURES: Array[Texture2D] = [
	preload("res://assets/sprites/pickups/Coin5.png"),
	preload("res://assets/sprites/pickups/Coin10.png"),
	preload("res://assets/sprites/pickups/Coin25.png"),
	preload("res://assets/sprites/pickups/Coin50.png")
]
const COIN_SOUND: AudioStream = preload("res://assets/sounds/Coin.wav")
const FUEL_SOUND: AudioStream = preload("res://assets/sounds/Fuel.wav")

# PackedInt32Array(...) не допускается в const в GDScript 4.3.
var coin_values: PackedInt32Array = PackedInt32Array([5, 10, 25, 50])
var mode: Mode = Mode.MANUAL
var terrain: TerrainGenerator
var camera_controller: CameraController
var interface_layer: CanvasLayer
var pickup_root: Node2D
var checkpoint_root: Node2D
var manual_car: Car
var manual_hud: HUD
var evolution_hud: EvolutionHUD
var side_panel: SidePanel
var pause_menu: PauseMenu
var evolution: EvolutionManager
var pickup_random: RandomNumberGenerator = RandomNumberGenerator.new()
var next_pickup_x: float = 620.0
var next_fuel_x: float = 0.0
var next_checkpoint_x: float = 500.0 * Config.PIXELS_PER_METER
var coin_audio: AudioStreamPlayer
var fuel_audio: AudioStreamPlayer

func _ready() -> void:
	Engine.time_scale = 1.0
	terrain = get_node_or_null("Terrain") as TerrainGenerator
	camera_controller = get_node_or_null("Camera2D") as CameraController
	interface_layer = get_node_or_null("Interface") as CanvasLayer
	pickup_root = Node2D.new()
	pickup_root.name = "Предметы"
	add_child(pickup_root)
	checkpoint_root = Node2D.new()
	checkpoint_root.name = "Чекпоинты"
	add_child(checkpoint_root)
	_create_audio_players()
	if mode == Mode.EVOLUTION:
		_start_evolution()
	else:
		_start_manual()

func _exit_tree() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false

func _start_manual() -> void:
	manual_hud = HUD_SCENE.instantiate() as HUD
	interface_layer.add_child(manual_hud)
	manual_hud.pause_requested.connect(_open_pause)
	manual_hud.restart_requested.connect(_restart_current)
	manual_hud.menu_requested.connect(_return_to_menu)
	_create_pause_menu()
	var spawn_x: float = 120.0
	var spawn_y: float = terrain.height_at(spawn_x) - 68.0
	manual_car = CAR_SCENE.instantiate() as Car
	# Joint2D фиксирует anchors при входе в дерево, поэтому задаём position до add_child().
	manual_car.position = Vector2(spawn_x, spawn_y)
	add_child(manual_car)
	manual_car.initialise(spawn_x, false)
	manual_car.died.connect(_on_manual_car_died)
	manual_car.fuel_changed.connect(_on_manual_fuel_changed)
	var controller: CarController = CarController.new()
	controller.name = "ManualController"
	manual_car.add_child(controller)
	controller.setup(manual_car, manual_hud)
	camera_controller.set_target(manual_car)
	pickup_random.seed = Config.terrain_seed * 13 + 7
	next_pickup_x = 620.0
	next_fuel_x = _manual_fuel_spacing()
	_spawn_manual_content_ahead()

func _start_evolution() -> void:
	evolution_hud = EVOLUTION_HUD_SCENE.instantiate() as EvolutionHUD
	evolution_hud.process_mode = Node.PROCESS_MODE_ALWAYS
	interface_layer.add_child(evolution_hud)
	side_panel = SIDE_PANEL_SCENE.instantiate() as SidePanel
	interface_layer.add_child(side_panel)
	evolution_hud.settings_requested.connect(_toggle_side_panel)
	evolution_hud.pause_requested.connect(_toggle_evolution_pause)
	evolution_hud.next_car_requested.connect(_select_next_car.bind(1))
	evolution_hud.previous_car_requested.connect(_select_next_car.bind(-1))
	side_panel.setting_changed.connect(_on_evolution_setting_changed)
	side_panel.restart_generation_requested.connect(_restart_evolution_generation)
	side_panel.new_track_requested.connect(_new_track)
	side_panel.pause_toggle_requested.connect(_toggle_evolution_pause)
	side_panel.menu_requested.connect(_return_to_menu)
	evolution = EvolutionManager.new()
	evolution.name = "EvolutionManager"
	add_child(evolution)
	evolution.target_changed.connect(_on_evolution_target_changed)
	evolution.statistics_changed.connect(_on_evolution_statistics_changed)
	evolution.setup(terrain, self, pickup_root)
	evolution_hud.set_network_visible(Config.show_network)

func _create_pause_menu() -> void:
	pause_menu = PAUSE_MENU_SCENE.instantiate() as PauseMenu
	interface_layer.add_child(pause_menu)
	pause_menu.resume_requested.connect(_close_pause)
	pause_menu.restart_requested.connect(_restart_from_pause)
	pause_menu.menu_requested.connect(_return_to_menu)

func _create_audio_players() -> void:
	coin_audio = AudioStreamPlayer.new()
	coin_audio.stream = COIN_SOUND
	coin_audio.volume_db = -7.0
	add_child(coin_audio)
	fuel_audio = AudioStreamPlayer.new()
	fuel_audio.stream = FUEL_SOUND
	fuel_audio.volume_db = -8.0
	add_child(fuel_audio)

func _process(_delta: float) -> void:
	var focus_car: Car = camera_controller.target_car if camera_controller != null else null
	if focus_car != null and is_instance_valid(focus_car) and terrain != null:
		terrain.ensure_ahead(focus_car.body_global_position().x)
	if mode == Mode.MANUAL and manual_car != null and is_instance_valid(manual_car):
		_spawn_manual_content_ahead()
		_cleanup_old_content()
		if Config.track_length_m > 0.0 and manual_car.max_distance_m >= Config.track_length_m:
			manual_car.die("Финиш трассы достигнут")
		manual_hud.set_stats(
			manual_car.max_distance_m, manual_car.speed_kmh(),
			manual_car.collected_coins, Config.record_distance_m
		)

func _unhandled_input(event: InputEvent) -> void:
	var key_event: InputEventKey = event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	if key_event.keycode == KEY_ESCAPE:
		if mode == Mode.MANUAL:
			if get_tree().paused:
				_close_pause()
			else:
				_open_pause()
		else:
			_toggle_evolution_pause()

func _spawn_manual_content_ahead() -> void:
	if manual_car == null or terrain == null:
		return
	var desired_x: float = manual_car.body_global_position().x + 5000.0
	desired_x = minf(desired_x, Config.track_end_x())
	while next_pickup_x < desired_x:
		if pickup_random.randf() < Config.coin_density:
			_spawn_coin(next_pickup_x)
		next_pickup_x += pickup_random.randf_range(82.0, 180.0)
	# Канистры идут по собственной шкале дистанции, поэтому генератор не может
	# случайно собрать несколько штук в одном месте.
	while next_fuel_x < desired_x:
		_spawn_fuel(next_fuel_x)
		next_fuel_x += _manual_fuel_spacing()
	while next_checkpoint_x < desired_x:
		_spawn_checkpoint(next_checkpoint_x)
		next_checkpoint_x += 500.0 * Config.PIXELS_PER_METER

func _manual_fuel_spacing() -> float:
	var base_spacing: float = lerpf(6500.0, 2800.0, Config.fuel_density)
	return pickup_random.randf_range(base_spacing * 0.85, base_spacing * 1.15)

func _spawn_coin(world_x: float) -> void:
	var coin: Coin = COIN_SCENE.instantiate() as Coin
	pickup_root.add_child(coin)
	var variant: int = pickup_random.randi_range(0, coin_values.size() - 1)
	var item_y: float = terrain.height_at(world_x)
	item_y -= pickup_random.randf_range(62.0, 108.0)
	coin.global_position = Vector2(world_x, item_y)
	coin.configure(coin_values[variant], COIN_TEXTURES[variant])
	coin.collected.connect(_on_coin_collected)

func _spawn_fuel(world_x: float) -> void:
	var fuel_can: FuelCan = FUEL_SCENE.instantiate() as FuelCan
	pickup_root.add_child(fuel_can)
	fuel_can.global_position = Vector2(world_x, terrain.height_at(world_x) - 78.0)
	fuel_can.collected.connect(_on_fuel_collected)

func _spawn_checkpoint(world_x: float) -> void:
	var checkpoint: Checkpoint = CHECKPOINT_SCENE.instantiate() as Checkpoint
	checkpoint_root.add_child(checkpoint)
	checkpoint.global_position = Vector2(world_x, terrain.height_at(world_x))
	checkpoint.distance_m = world_x / Config.PIXELS_PER_METER

func _cleanup_old_content() -> void:
	if manual_car == null:
		return
	var cutoff_x: float = manual_car.body_global_position().x - 1200.0
	for item: Node in pickup_root.get_children():
		var world_item: Node2D = item as Node2D
		if world_item != null and world_item.global_position.x < cutoff_x:
			world_item.queue_free()
	for marker: Node in checkpoint_root.get_children():
		var checkpoint: Node2D = marker as Node2D
		if checkpoint != null and checkpoint.global_position.x < cutoff_x:
			checkpoint.queue_free()

func _on_coin_collected(_value: int) -> void:
	if coin_audio != null:
		coin_audio.play()

func _on_fuel_collected(_value: float) -> void:
	if fuel_audio != null:
		fuel_audio.play()

func _on_manual_fuel_changed(current: float, maximum: float) -> void:
	if manual_hud != null:
		manual_hud.set_fuel(current, maximum)

func _on_manual_car_died(reason: String) -> void:
	var distance_m: float = manual_car.max_distance_m
	var coins: int = manual_car.collected_coins
	var new_record: bool = Config.register_manual_result(distance_m, coins)
	manual_hud.show_result(reason, distance_m, coins, new_record)

func _open_pause() -> void:
	if pause_menu == null or manual_car == null or manual_car.dead:
		return
	get_tree().paused = true
	pause_menu.open()

func _close_pause() -> void:
	get_tree().paused = false
	if pause_menu != null:
		pause_menu.close()

func _restart_from_pause() -> void:
	_close_pause()
	_restart_current()

func _restart_current() -> void:
	get_tree().paused = false
	restart_requested.emit(mode)

func _return_to_menu() -> void:
	get_tree().paused = false
	menu_requested.emit()

func _toggle_side_panel() -> void:
	if side_panel != null:
		side_panel.toggle()

func _toggle_evolution_pause() -> void:
	if evolution != null:
		evolution.toggle_pause()

func _select_next_car(direction: int) -> void:
	if evolution != null:
		evolution.select_next(direction)

func _restart_evolution_generation() -> void:
	if evolution != null:
		evolution.restart_generation()

func _new_track() -> void:
	if evolution != null:
		evolution.new_track_and_restart()

func _on_evolution_setting_changed(setting_name: String, _value: float) -> void:
	if setting_name == "show_network" and evolution_hud != null:
		evolution_hud.set_network_visible(Config.show_network)
	if setting_name == "track_length" and evolution != null:
		evolution.apply_track_length_and_restart()

func _on_evolution_target_changed(target_car: Car, network: NeuralNetwork) -> void:
	if target_car == null:
		return
	camera_controller.set_target(target_car)
	if evolution_hud != null:
		evolution_hud.set_network(network)

func _on_evolution_statistics_changed(
	generation: int, alive: int, total: int, current_best: float,
	best_ever: float, current_fitness: float, average_fitness: float
) -> void:
	if evolution_hud != null:
		evolution_hud.set_metrics(
			generation, alive, total, current_best, best_ever,
			current_fitness, average_fitness, Config.simulation_speed,
			Config.effective_simulation_speed()
		)
