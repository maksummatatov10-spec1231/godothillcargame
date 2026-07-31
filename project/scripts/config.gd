extends Node
## Единая точка настроек. Значения меняются панелью и применяются к следующему
## заезду/поколению; рекорд хранится отдельно в user://.

const PIXELS_PER_METER: float = 32.0
const BASE_GRAVITY: float = 1400.0
const SAVE_PATH: String = "user://hill_motion_progress.cfg"

var record_distance_m: float = 0.0
var record_coins: int = 0
var master_volume_db: float = -6.0

# Трасса.
var terrain_seed: int = 20260731
var terrain_difficulty: float = 1.0
var hill_height: float = 150.0
var terrain_frequency: float = 1.0
var fuel_density: float = 0.36
var coin_density: float = 0.78

# Машина.
var body_mass: float = 7.0
var wheel_mass: float = 1.25
var engine_torque: float = 47000.0
var max_wheel_speed: float = 54.0
var wheel_friction: float = 2.2
# Чем больше значение, тем меньше PinJoint2D.softness и тем жёстче ось.
var axle_stiffness: float = 110.0
var gravity: float = BASE_GRAVITY
var body_linear_damp: float = 0.16
var body_angular_damp: float = 1.35

# Эволюция.
var evolution_population_size: int = 150
var evolution_elites: int = 5
var evolution_mutation_rate: float = 0.15
var evolution_mutation_strength: float = 0.30
var evolution_tournament_size: int = 5
var evolution_immigrant_ratio: float = 0.05
var evolution_timeout_sec: float = 30.0
var evolution_idle_timeout_sec: float = 5.0
var simulation_speed: float = 1.0
var hidden_layer_count: int = 2
var hidden_neurons: int = 16
var activation_name: String = "tanh"
var show_network: bool = true

func _ready() -> void:
	load_progress()

func load_progress() -> void:
	var storage: ConfigFile = ConfigFile.new()
	if storage.load(SAVE_PATH) != OK:
		return
	record_distance_m = float(storage.get_value("progress", "record_distance_m", 0.0))
	record_coins = int(storage.get_value("progress", "record_coins", 0))
	master_volume_db = float(storage.get_value("audio", "master_volume_db", -6.0))
	AudioServer.set_bus_volume_db(0, master_volume_db)

func save_progress() -> void:
	var storage: ConfigFile = ConfigFile.new()
	storage.set_value("progress", "record_distance_m", record_distance_m)
	storage.set_value("progress", "record_coins", record_coins)
	storage.set_value("audio", "master_volume_db", master_volume_db)
	storage.save(SAVE_PATH)

func register_manual_result(distance_m: float, coins: int) -> bool:
	var was_record: bool = distance_m > record_distance_m
	if was_record:
		record_distance_m = distance_m
	if coins > record_coins:
		record_coins = coins
	save_progress()
	return was_record

func get_network_layers() -> Array[int]:
	var result: Array[int] = [18]
	var layer_index: int = 0
	while layer_index < hidden_layer_count:
		result.append(hidden_neurons)
		layer_index += 1
	result.append(2)
	return result

func effective_simulation_speed() -> float:
	# RigidBody2D нельзя безопасно прогонять с time_scale=100: движок начинает
	# ограничивать число физических шагов. Честно ограничиваем физическую часть,
	# а запрошенная величина остаётся видна в панели.
	return minf(simulation_speed, 4.0)

func set_numeric_setting(setting_name: String, new_value: float) -> void:
	match setting_name:
		"simulation_speed":
			simulation_speed = clampf(new_value, 1.0, 100.0)
		"population_size":
			evolution_population_size = clampi(int(round(new_value)), 10, 150)
		"elites":
			evolution_elites = clampi(int(round(new_value)), 1, max(1, evolution_population_size - 1))
		"mutation_rate":
			evolution_mutation_rate = clampf(new_value, 0.0, 1.0)
		"mutation_strength":
			evolution_mutation_strength = clampf(new_value, 0.01, 2.0)
		"tournament_size":
			evolution_tournament_size = clampi(int(round(new_value)), 2, 12)
		"immigrant_ratio":
			evolution_immigrant_ratio = clampf(new_value, 0.0, 0.50)
		"timeout":
			evolution_timeout_sec = clampf(new_value, 5.0, 120.0)
		"idle_timeout":
			evolution_idle_timeout_sec = clampf(new_value, 1.0, 30.0)
		"hidden_layers":
			hidden_layer_count = clampi(int(round(new_value)), 1, 4)
		"hidden_neurons":
			hidden_neurons = clampi(int(round(new_value)), 4, 32)
		"body_mass":
			body_mass = clampf(new_value, 2.0, 20.0)
		"wheel_mass":
			wheel_mass = clampf(new_value, 0.4, 5.0)
		"engine_torque":
			engine_torque = clampf(new_value, 10000.0, 100000.0)
		"max_wheel_speed":
			max_wheel_speed = clampf(new_value, 10.0, 100.0)
		"wheel_friction":
			wheel_friction = clampf(new_value, 0.2, 8.0)
		"axle_stiffness":
			axle_stiffness = clampf(new_value, 20.0, 300.0)
		"gravity":
			gravity = clampf(new_value, 600.0, 2600.0)
		"terrain_difficulty":
			terrain_difficulty = clampf(new_value, 0.30, 2.5)
		"hill_height":
			hill_height = clampf(new_value, 40.0, 360.0)
		"terrain_frequency":
			terrain_frequency = clampf(new_value, 0.35, 2.5)
		"fuel_density":
			fuel_density = clampf(new_value, 0.05, 1.0)
		"coin_density":
			coin_density = clampf(new_value, 0.05, 1.0)
		"seed":
			terrain_seed = int(round(new_value))

func get_numeric_setting(setting_name: String) -> float:
	var result: float = 0.0
	match setting_name:
		"simulation_speed": result = simulation_speed
		"population_size": result = evolution_population_size
		"elites": result = evolution_elites
		"mutation_rate": result = evolution_mutation_rate
		"mutation_strength": result = evolution_mutation_strength
		"tournament_size": result = evolution_tournament_size
		"immigrant_ratio": result = evolution_immigrant_ratio
		"timeout": result = evolution_timeout_sec
		"idle_timeout": result = evolution_idle_timeout_sec
		"hidden_layers": result = hidden_layer_count
		"hidden_neurons": result = hidden_neurons
		"body_mass": result = body_mass
		"wheel_mass": result = wheel_mass
		"engine_torque": result = engine_torque
		"max_wheel_speed": result = max_wheel_speed
		"wheel_friction": result = wheel_friction
		"axle_stiffness": result = axle_stiffness
		"gravity": result = gravity
		"terrain_difficulty": result = terrain_difficulty
		"hill_height": result = hill_height
		"terrain_frequency": result = terrain_frequency
		"fuel_density": result = fuel_density
		"coin_density": result = coin_density
		"seed": result = terrain_seed
	return result

func set_activation(new_name: String) -> void:
	if new_name == "ReLU":
		activation_name = "relu"
	else:
		activation_name = "tanh"
