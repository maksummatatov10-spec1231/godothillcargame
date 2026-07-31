class_name AICarController
extends Node
## Контроллер-сенсор: он видит только состояние своей машины и семь лучей перед
## ней. Никаких высот будущей трассы или данных других машин в сеть не идёт.

const SENSOR_LENGTH: float = 300.0

# Конструктор PackedFloat32Array не является constant expression в GDScript 4.3.
# Это неизменяемые для контроллера данные экземпляра, а не константа языка.
var sensor_angles: PackedFloat32Array = PackedFloat32Array([
	0.20, 0.36, 0.52, 0.68, 0.84, 1.00, 1.16
])

var car: Car
var terrain: TerrainGenerator
var network: NeuralNetwork
var genome: Genome

func setup(controlled_car: Car, terrain_node: TerrainGenerator, car_genome: Genome) -> void:
	car = controlled_car
	terrain = terrain_node
	genome = car_genome
	network = NeuralNetwork.new()
	network.configure(genome.layers, genome.genes, Config.activation_name)

func _physics_process(_delta: float) -> void:
	if car == null or not is_instance_valid(car) or car.dead or network == null:
		return
	var inputs: PackedFloat32Array = _collect_inputs()
	var outputs: PackedFloat32Array = network.forward(inputs)
	var throttle: float = (outputs[0] + 1.0) * 0.5 if outputs.size() > 0 else 0.0
	var brake: float = (outputs[1] + 1.0) * 0.5 if outputs.size() > 1 else 0.0
	car.set_controls(throttle, brake)

func _collect_inputs() -> PackedFloat32Array:
	var values: PackedFloat32Array = PackedFloat32Array()
	var chassis_velocity: Vector2 = car.body_linear_velocity()
	values.append(clampf(chassis_velocity.x / 1200.0, -1.0, 1.0))
	values.append(clampf(chassis_velocity.y / 1200.0, -1.0, 1.0))
	values.append(clampf(car.body_angular_velocity() / 18.0, -1.0, 1.0))
	values.append(car.body_angle_normalized())
	var chassis_position: Vector2 = car.body_global_position()
	var ground_y: float = chassis_position.y + 200.0
	if terrain != null:
		ground_y = terrain.height_at(chassis_position.x)
	values.append(clampf((ground_y - chassis_position.y) / 260.0, -1.0, 1.0))
	values.append(1.0 if car.front_wheel != null and car.front_wheel.grounded else -1.0)
	values.append(1.0 if car.rear_wheel != null and car.rear_wheel.grounded else -1.0)
	var front_spin: float = 0.0
	if car.front_wheel != null:
		front_spin = car.front_wheel.angular_velocity
	var rear_spin: float = 0.0
	if car.rear_wheel != null:
		rear_spin = car.rear_wheel.angular_velocity
	values.append(clampf(front_spin / Config.max_wheel_speed, -1.0, 1.0))
	values.append(clampf(rear_spin / Config.max_wheel_speed, -1.0, 1.0))
	var ray_index: int = 0
	while ray_index < sensor_angles.size():
		values.append(_read_sensor(sensor_angles[ray_index]))
		ray_index += 1
	values.append(car.fuel / Car.FULL_FUEL)
	values.append(clampf(car.max_distance_m / 1000.0, 0.0, 1.0))
	return values

func _read_sensor(angle_offset: float) -> float:
	if car == null or not is_instance_valid(car):
		return 1.0
	var chassis_position: Vector2 = car.body_global_position()
	var chassis_rotation: float = car.body_rotation_radians()
	var origin: Vector2 = chassis_position + Vector2(20.0, 12.0).rotated(chassis_rotation)
	var direction: Vector2 = Vector2.RIGHT.rotated(chassis_rotation + angle_offset)
	var target: Vector2 = origin + direction * SENSOR_LENGTH
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.new()
	query.from = origin
	query.to = target
	query.collision_mask = 1
	var excluded: Array[RID] = []
	if car.chassis != null:
		excluded.append(car.chassis.get_rid())
	if car.front_wheel != null:
		excluded.append(car.front_wheel.get_rid())
	if car.rear_wheel != null:
		excluded.append(car.rear_wheel.get_rid())
	query.exclude = excluded
	var space_state: PhysicsDirectSpaceState2D = car.get_world_2d().direct_space_state
	var hit: Dictionary = space_state.intersect_ray(query)
	if hit.is_empty():
		return 1.0
	var hit_position: Vector2 = Vector2(hit.get("position", target))
	return clampf(origin.distance_to(hit_position) / SENSOR_LENGTH, 0.0, 1.0)
