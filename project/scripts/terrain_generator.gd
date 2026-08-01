class_name TerrainGenerator
extends Node2D
## Детерминированная наращиваемая трасса. При длине 0 она бесконечна; при
## положительной длине заканчивается финишем. Коллизия состоит из сегментов
## StaticBody2D: колёса не проваливаются в вогнутый Polygon2D.

const DIRT_TEXTURE: Texture2D = preload("res://assets/sprites/terrain/DirtBG.png")
const GRASS_TEXTURE: Texture2D = preload("res://assets/sprites/terrain/Grass.png")
const SEGMENT_WIDTH: float = 64.0
const INITIAL_LEFT: float = -1200.0
const INITIAL_RIGHT: float = 12000.0
const KEEP_AHEAD: float = 9000.0
const GROUND_BOTTOM: float = 2200.0

var surface_points: PackedVector2Array = PackedVector2Array()
var last_generated_x: float = INITIAL_LEFT
var current_seed: int = 0
var ground_polygon: Polygon2D
var grass_line: Line2D
var collision_root: Node2D

func _ready() -> void:
	ground_polygon = Polygon2D.new()
	ground_polygon.texture = DIRT_TEXTURE
	ground_polygon.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	ground_polygon.z_index = -4
	add_child(ground_polygon)
	grass_line = Line2D.new()
	grass_line.texture = GRASS_TEXTURE
	grass_line.width = 17.0
	grass_line.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	grass_line.z_index = -2
	add_child(grass_line)
	collision_root = Node2D.new()
	collision_root.name = "КоллизияРельефа"
	add_child(collision_root)
	rebuild(Config.terrain_seed)

func rebuild(new_seed: int) -> void:
	current_seed = new_seed
	for collision_node: Node in collision_root.get_children():
		collision_node.queue_free()
	surface_points.clear()
	last_generated_x = INITIAL_LEFT
	_append_until(minf(INITIAL_RIGHT, Config.track_end_x()))
	_refresh_visual()

func ensure_ahead(world_x: float) -> void:
	var desired_right: float = minf(world_x + KEEP_AHEAD, Config.track_end_x())
	if desired_right <= last_generated_x:
		return
	_append_until(desired_right)
	_refresh_visual()

func height_at(world_x: float) -> float:
	# Сумма длинной, средней и короткой волн даёт ровные разгоны, холмы и ямы.
	# Фазы из seed сохраняют трассу между ручным режимом и эволюцией.
	var phase_a: float = float(posmod(current_seed * 17, 6283)) / 1000.0
	var phase_b: float = float(posmod(current_seed * 43, 6283)) / 1000.0
	var phase_c: float = float(posmod(current_seed * 71, 6283)) / 1000.0
	var difficulty: float = Config.terrain_difficulty
	var frequency: float = Config.terrain_frequency
	var hill: float = Config.hill_height
	var long_wave: float = sin(world_x * 0.0032 * frequency + phase_a) * hill * 0.54
	var medium_wave: float = sin(world_x * 0.0091 * frequency + phase_b) * hill * 0.26
	var small_wave: float = sin(world_x * 0.0217 * frequency + phase_c) * hill * 0.135 * difficulty
	var bump_wave: float = sin(world_x * 0.047 * frequency + phase_b * 1.9) * hill * 0.052 * difficulty
	# Асимметричный профиль даёт короткие подъёмы и спуски, на которых можно
	# ошибиться с газом и перевернуться, а не только бесконечные синусоиды.
	var ridge_phase: float = sin(world_x * 0.0135 * frequency + phase_a * 1.7)
	var ridge_wave: float = maxf(0.0, ridge_phase) * hill * 0.16 * difficulty
	var rough_wave: float = sin(world_x * 0.062 * frequency + phase_c * 1.3)
	rough_wave *= hill * 0.030 * difficulty
	# Первые метры остаются мягкими для корректной посадки подвески.
	var start_blend: float = clampf((world_x + 150.0) / 900.0, 0.0, 1.0)
	var terrain_offset: float = long_wave + medium_wave + small_wave
	terrain_offset += bump_wave + ridge_wave + rough_wave
	return 510.0 - terrain_offset * start_blend

func surface_normal_at(world_x: float) -> Vector2:
	var sample: float = 5.0
	var slope: float = (height_at(world_x + sample) - height_at(world_x - sample)) / (sample * 2.0)
	return Vector2(slope, -1.0).normalized()

func _append_until(target_x: float) -> void:
	var capped_target: float = minf(target_x, Config.track_end_x())
	if capped_target <= last_generated_x:
		return
	if surface_points.is_empty():
		var first_point: Vector2 = Vector2(last_generated_x, height_at(last_generated_x))
		surface_points.append(first_point)
	while last_generated_x < capped_target:
		var previous_point: Vector2 = surface_points[surface_points.size() - 1]
		last_generated_x = minf(last_generated_x + SEGMENT_WIDTH, capped_target)
		var next_point: Vector2 = Vector2(last_generated_x, height_at(last_generated_x))
		surface_points.append(next_point)
		_create_collision_segment(previous_point, next_point)

func _create_collision_segment(first_point: Vector2, second_point: Vector2) -> void:
	var terrain_body: StaticBody2D = StaticBody2D.new()
	terrain_body.collision_layer = 1
	terrain_body.collision_mask = 0
	var collider: CollisionShape2D = CollisionShape2D.new()
	var segment: SegmentShape2D = SegmentShape2D.new()
	segment.a = first_point
	segment.b = second_point
	collider.shape = segment
	terrain_body.add_child(collider)
	collision_root.add_child(terrain_body)

func _refresh_visual() -> void:
	if surface_points.size() < 2:
		return
	var filled_points: PackedVector2Array = surface_points.duplicate()
	filled_points.append(Vector2(last_generated_x, GROUND_BOTTOM))
	filled_points.append(Vector2(surface_points[0].x, GROUND_BOTTOM))
	ground_polygon.polygon = filled_points
	grass_line.points = surface_points
