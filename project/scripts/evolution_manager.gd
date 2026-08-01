class_name EvolutionManager
extends Node
## Генетический цикл: все машины получают одну структуру сети, но разные веса.
## Отбор полностью отделён от визуала и физики, поэтому его легко расширять.

signal target_changed(target_car: Car, target_network: NeuralNetwork)
signal statistics_changed(
	generation: int, alive: int, total: int, current_best: float,
	best_ever: float, current_fitness: float, average_fitness: float
)

const CAR_SCENE: PackedScene = preload("res://scenes/Car.tscn")
const FUEL_SCENE: PackedScene = preload("res://scenes/FuelCan.tscn")
const STATISTICS_INTERVAL: float = 0.10

var terrain: TerrainGenerator
var vehicle_parent: Node
var shared_fuel_root: Node2D
var random: RandomNumberGenerator = RandomNumberGenerator.new()
var fuel_random: RandomNumberGenerator = RandomNumberGenerator.new()
var genomes: Array[Genome] = []
var cars: Array[Car] = []
var generation: int = 1
var best_distance_ever: float = 0.0
var best_fitness_ever: float = 0.0
var current_best_fitness: float = 0.0
var generation_average_fitness: float = 0.0
var selected_index: int = -1
var user_selected: bool = false
var applied_time_scale: float = -1.0
var statistics_elapsed: float = 0.0
var next_shared_fuel_x: float = 0.0

func setup(terrain_node: TerrainGenerator, parent_for_cars: Node, parent_for_fuel: Node) -> void:
	terrain = terrain_node
	vehicle_parent = parent_for_cars
	shared_fuel_root = Node2D.new()
	shared_fuel_root.name = "ОбщиеКанистрыЭволюции"
	parent_for_fuel.add_child(shared_fuel_root)
	random.seed = Config.terrain_seed * 97 + 31
	fuel_random.seed = Config.terrain_seed * 211 + 17
	create_fresh_population()
	_spawn_generation()

func _physics_process(delta: float) -> void:
	_apply_speed_if_needed()
	if cars.is_empty():
		return
	var alive_count: int = 0
	var current_best_distance: float = 0.0
	var leader_index: int = -1
	var index: int = 0
	while index < cars.size():
		var car: Car = cars[index]
		if is_instance_valid(car):
			current_best_distance = maxf(current_best_distance, car.max_distance_m)
			if not car.dead:
				if Config.track_length_m > 0.0 and car.max_distance_m >= Config.track_length_m:
					car.die("Финиш трассы достигнут")
				elif car.life_time >= Config.evolution_timeout_sec:
					car.die("Время машины истекло")
				elif car.idle_time >= Config.evolution_idle_timeout_sec:
					car.die("Нет прогресса")
				else:
					alive_count += 1
					if leader_index < 0 or car.max_distance_m > cars[leader_index].max_distance_m:
						leader_index = index
		index += 1
	_update_leader_target(leader_index)
	if leader_index >= 0 and is_instance_valid(cars[leader_index]):
		_ensure_shared_fuel_ahead(cars[leader_index].body_global_position().x)
	statistics_elapsed += delta
	if statistics_elapsed >= STATISTICS_INTERVAL or alive_count == 0:
		statistics_elapsed = 0.0
		_emit_statistics(alive_count, current_best_distance)
	if alive_count == 0:
		_finish_generation()

func _update_leader_target(leader_index: int) -> void:
	if leader_index < 0:
		return
	var selected_is_dead: bool = selected_index < 0 or selected_index >= cars.size()
	if not selected_is_dead:
		var selected_car: Car = cars[selected_index]
		selected_is_dead = not is_instance_valid(selected_car) or selected_car.dead
	if user_selected and not selected_is_dead:
		return
	if selected_index != leader_index:
		selected_index = leader_index
		user_selected = false
		_update_target()

func _emit_statistics(alive_count: int, current_best_distance: float) -> void:
	statistics_changed.emit(
		generation, alive_count, cars.size(), current_best_distance,
		best_distance_ever, current_best_fitness, generation_average_fitness
	)

func create_fresh_population() -> void:
	genomes.clear()
	var layout: Array[int] = Config.get_network_layers()
	var amount: int = 0
	while amount < Config.evolution_population_size:
		# Первое поколение не наследует знания: малый нулецентричный разброс
		# даёт почти нейтральные действия, а стратегия появляется через мутации.
		genomes.append(Genome.create_random(layout, random, Config.initial_genome_spread))
		amount += 1
	generation = 1
	current_best_fitness = 0.0
	generation_average_fitness = 0.0

func restart_generation(reset_population: bool = false) -> void:
	get_tree().paused = false
	if reset_population or genomes.is_empty() or not _population_matches_settings():
		create_fresh_population()
	_spawn_generation()

func new_track_and_restart() -> void:
	Config.terrain_seed = random.randi_range(1, 99999999)
	if terrain != null:
		terrain.rebuild(Config.terrain_seed)
	fuel_random.seed = Config.terrain_seed * 211 + 17
	create_fresh_population()
	_spawn_generation()

func select_next(direction: int) -> void:
	if cars.is_empty():
		return
	user_selected = true
	selected_index = posmod(selected_index + direction, cars.size())
	_update_target()

func toggle_pause() -> void:
	get_tree().paused = not get_tree().paused

func _population_matches_settings() -> bool:
	if genomes.size() != Config.evolution_population_size:
		return false
	if genomes.is_empty():
		return false
	return genomes[0].layers == Config.get_network_layers()

func _spawn_generation() -> void:
	for old_car: Car in cars:
		if is_instance_valid(old_car):
			old_car.queue_free()
	cars.clear()
	selected_index = -1
	user_selected = false
	statistics_elapsed = 0.0
	_clear_shared_fuel()
	var spawn_x: float = 120.0
	next_shared_fuel_x = spawn_x + _shared_fuel_spacing()
	var spawn_y: float = terrain.height_at(spawn_x) - 68.0 if terrain != null else 350.0
	var index: int = 0
	while index < genomes.size():
		var car: Car = CAR_SCENE.instantiate() as Car
		# Суставы подвески создают мировые точки крепления при входе в дерево.
		# Сначала ставим сборку, затем добавляем её — точки не увидят (0, 0).
		car.position = Vector2(spawn_x, spawn_y)
		vehicle_parent.add_child(car)
		var alpha: float = 0.25
		car.initialise(spawn_x, true, Color(0.64, 0.87, 1.0, alpha))
		car.front_wheel.set_visual_variant(index % 3)
		car.rear_wheel.set_visual_variant(index % 3)
		var controller: AICarController = AICarController.new()
		controller.name = "AIController"
		car.add_child(controller)
		controller.setup(car, terrain, genomes[index])
		car.died.connect(_on_car_died.bind(car))
		cars.append(car)
		index += 1
	_ensure_shared_fuel_ahead(spawn_x + 5000.0)
	_apply_speed_if_needed()
	_update_target()

func apply_track_length_and_restart() -> void:
	get_tree().paused = false
	if terrain != null:
		terrain.rebuild(Config.terrain_seed)
	fuel_random.seed = Config.terrain_seed * 211 + 17
	create_fresh_population()
	_spawn_generation()

func _clear_shared_fuel() -> void:
	if shared_fuel_root == null:
		return
	for fuel_node: Node in shared_fuel_root.get_children():
		fuel_node.queue_free()

func _ensure_shared_fuel_ahead(world_x: float) -> void:
	if shared_fuel_root == null or terrain == null:
		return
	var desired_x: float = minf(world_x + 5000.0, Config.track_end_x())
	while next_shared_fuel_x < desired_x:
		var fuel_can: FuelCan = FUEL_SCENE.instantiate() as FuelCan
		shared_fuel_root.add_child(fuel_can)
		fuel_can.global_position = Vector2(
			next_shared_fuel_x, terrain.height_at(next_shared_fuel_x) - 78.0
		)
		fuel_can.configure_shared_for_cars(38.0)
		next_shared_fuel_x += _shared_fuel_spacing()

func _shared_fuel_spacing() -> float:
	var base_spacing: float = lerpf(6500.0, 2800.0, Config.fuel_density)
	return fuel_random.randf_range(base_spacing * 0.85, base_spacing * 1.15)

func _on_car_died(_reason: String, car: Car) -> void:
	if car == null or not is_instance_valid(car):
		return
	var controller: AICarController = car.get_node_or_null("AIController") as AICarController
	if controller == null or controller.genome == null:
		return
	controller.genome.fitness = FitnessEvaluator.evaluate(car)
	current_best_fitness = maxf(current_best_fitness, controller.genome.fitness)
	best_distance_ever = maxf(best_distance_ever, car.max_distance_m)
	best_fitness_ever = maxf(best_fitness_ever, controller.genome.fitness)

func _finish_generation() -> void:
	if genomes.is_empty():
		return
	var total_fitness: float = 0.0
	current_best_fitness = 0.0
	for genome_item: Genome in genomes:
		total_fitness += genome_item.fitness
		current_best_fitness = maxf(current_best_fitness, genome_item.fitness)
	generation_average_fitness = total_fitness / float(genomes.size())
	var ranked: Array[Genome] = genomes.duplicate()
	ranked.sort_custom(_sort_by_fitness)
	var next_population: Array[Genome] = []
	var elite_count: int = mini(Config.evolution_elites, ranked.size())
	var elite_index: int = 0
	while elite_index < elite_count:
		next_population.append(ranked[elite_index].duplicate_genome())
		elite_index += 1
	var requested_immigrants: float = float(Config.evolution_population_size)
	requested_immigrants *= Config.evolution_immigrant_ratio
	var immigrant_count: int = maxi(1, int(round(requested_immigrants)))
	while next_population.size() < Config.evolution_population_size:
		if next_population.size() < elite_count + immigrant_count:
			next_population.append(Genome.create_random(Config.get_network_layers(), random))
		else:
			var first_parent: Genome = _tournament_pick(ranked)
			var second_parent: Genome = _tournament_pick(ranked)
			var child: Genome = Genome.crossover(first_parent, second_parent, random)
			child.mutate(random, Config.evolution_mutation_rate, Config.evolution_mutation_strength)
			next_population.append(child)
	genomes = next_population
	generation += 1
	_spawn_generation()

func _tournament_pick(ranked: Array[Genome]) -> Genome:
	var winner: Genome = ranked[random.randi_range(0, ranked.size() - 1)]
	var round_index: int = 1
	while round_index < Config.evolution_tournament_size:
		var candidate: Genome = ranked[random.randi_range(0, ranked.size() - 1)]
		if candidate.fitness > winner.fitness:
			winner = candidate
		round_index += 1
	return winner

func _sort_by_fitness(first: Genome, second: Genome) -> bool:
	return first.fitness > second.fitness

func _update_target() -> void:
	if selected_index < 0 or selected_index >= cars.size():
		return
	var index: int = 0
	while index < cars.size():
		var car: Car = cars[index]
		if is_instance_valid(car):
				var is_selected: bool = index == selected_index
				car.modulate = Color(0.82, 0.96, 1.0, 1.0)
				car.set_visual_detail_enabled(is_selected)
				if not is_selected:
					car.modulate = Color(0.64, 0.87, 1.0, 0.25)
		index += 1
	var selected_car: Car = cars[selected_index]
	if not is_instance_valid(selected_car):
		return
	var controller: AICarController = selected_car.get_node_or_null("AIController") as AICarController
	if controller != null:
		target_changed.emit(selected_car, controller.network)

func _apply_speed_if_needed() -> void:
	var safe_speed: float = Config.effective_simulation_speed()
	if is_equal_approx(safe_speed, applied_time_scale):
		return
	applied_time_scale = safe_speed
	Engine.time_scale = safe_speed
