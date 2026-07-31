class_name Car
extends Node2D
## Кузов и колёса — независимые RigidBody2D под нейтральным Node2D. Колесо
## направляется GrooveJoint2D строго по вертикали, а DampedSpringJoint2D
## создаёт реальную пружину. Одна пружина без направляющей здесь запрещена:
## она удерживает расстояние, но позволяет колесу обходить кузов по окружности.

signal died(reason: String)
signal fuel_changed(current: float, maximum: float)

const FULL_FUEL: float = 100.0
const BLUE_CHASSIS: Texture2D = preload("res://assets/sprites/car/Car.png")
const AI_BODY: Texture2D = preload("res://assets/sprites/characters/Body2.png")
const AI_HEAD: Texture2D = preload("res://assets/sprites/characters/Head2.png")
const REAR_SPRING_TOP_LOCAL: Vector2 = Vector2(-34.0, -10.0)
const FRONT_SPRING_TOP_LOCAL: Vector2 = Vector2(34.0, -10.0)
const FRONT_DRIVE_RATIO: float = 0.58
const TRACTION_ASSIST_RATIO: float = 0.85
const FLIP_ANGLE_LIMIT: float = 2.181661565
const FLIP_CONTACT_TIME: float = 0.25

var chassis: RigidBody2D
var front_wheel: Wheel
var rear_wheel: Wheel
var front_guide: GrooveJoint2D
var rear_guide: GrooveJoint2D
var front_spring: DampedSpringJoint2D
var rear_spring: DampedSpringJoint2D
var head_sensor: Area2D
var engine_audio: AudioStreamPlayer2D
var front_suspension_visual: Line2D
var rear_suspension_visual: Line2D

var throttle_input: float = 0.0
var brake_input: float = 0.0
var fuel: float = FULL_FUEL
var start_x: float = 0.0
var max_distance_m: float = 0.0
var life_time: float = 0.0
var idle_time: float = 0.0
var upside_down_time: float = 0.0
var dead: bool = false
var ai_controlled: bool = false
var visual_detail_enabled: bool = true
var collected_coins: int = 0
var last_progress_m: float = 0.0

func _ready() -> void:
	chassis = get_node_or_null("Chassis") as RigidBody2D
	front_wheel = get_node_or_null("FrontWheel") as Wheel
	rear_wheel = get_node_or_null("RearWheel") as Wheel
	front_guide = get_node_or_null("FrontGuide") as GrooveJoint2D
	rear_guide = get_node_or_null("RearGuide") as GrooveJoint2D
	front_spring = get_node_or_null("FrontSpring") as DampedSpringJoint2D
	rear_spring = get_node_or_null("RearSpring") as DampedSpringJoint2D
	head_sensor = get_node_or_null("Chassis/HeadSensor") as Area2D
	engine_audio = get_node_or_null("Chassis/EngineAudio") as AudioStreamPlayer2D
	front_suspension_visual = get_node_or_null("FrontSuspensionVisual") as Line2D
	rear_suspension_visual = get_node_or_null("RearSuspensionVisual") as Line2D
	_configure_chassis()
	_configure_wheels()
	_configure_suspension()
	if head_sensor != null:
		head_sensor.body_entered.connect(_on_head_sensor_body_entered)
	if engine_audio != null and not ai_controlled:
		engine_audio.finished.connect(_on_engine_audio_finished)
		engine_audio.play()
	set_visual_detail_enabled(true)

func _configure_chassis() -> void:
	if chassis == null:
		return
	chassis.mass = Config.body_mass
	chassis.gravity_scale = Config.gravity / Config.BASE_GRAVITY
	chassis.linear_damp = Config.body_linear_damp
	chassis.angular_damp = Config.body_angular_damp
	chassis.can_sleep = false

func _configure_wheels() -> void:
	if front_wheel != null:
		front_wheel.max_angular_speed = Config.max_wheel_speed
		front_wheel.set_visual_variant(0)
	if rear_wheel != null:
		rear_wheel.max_angular_speed = Config.max_wheel_speed
		rear_wheel.set_visual_variant(0)

func _configure_suspension() -> void:
	# rest_length, stiffness и damping меняются у уже настроенного сустава в
	# Godot 4.3. Геометрия GrooveJoint2D зафиксирована в сцене до входа в дерево.
	if front_spring != null:
		front_spring.rest_length = Config.suspension_rest_length
		front_spring.stiffness = Config.suspension_stiffness
		front_spring.damping = Config.suspension_damping
	if rear_spring != null:
		rear_spring.rest_length = Config.suspension_rest_length
		rear_spring.stiffness = Config.suspension_stiffness
		rear_spring.damping = Config.suspension_damping

func initialise(spawn_x: float, is_ai: bool, tint: Color = Color.WHITE) -> void:
	start_x = spawn_x
	ai_controlled = is_ai
	modulate = tint
	set_visual_detail_enabled(not ai_controlled)
	if ai_controlled:
		var chassis_sprite: Sprite2D = get_node_or_null("Chassis/ChassisSprite") as Sprite2D
		var driver_body: Sprite2D = get_node_or_null("Chassis/DriverBody") as Sprite2D
		var driver_head: Sprite2D = get_node_or_null("Chassis/DriverHead") as Sprite2D
		if chassis_sprite != null:
			chassis_sprite.texture = BLUE_CHASSIS
		if driver_body != null:
			driver_body.texture = AI_BODY
		if driver_head != null:
			driver_head.texture = AI_HEAD
	if engine_audio != null and ai_controlled:
		engine_audio.stop()

func set_visual_detail_enabled(enabled: bool) -> void:
	visual_detail_enabled = enabled
	if rear_suspension_visual != null:
		rear_suspension_visual.visible = enabled
	if front_suspension_visual != null:
		front_suspension_visual.visible = enabled
	if enabled:
		_update_suspension_visuals()

func body_global_position() -> Vector2:
	if chassis == null:
		return global_position
	return chassis.global_position

func body_linear_velocity() -> Vector2:
	if chassis == null:
		return Vector2.ZERO
	return chassis.linear_velocity

func body_angular_velocity() -> float:
	if chassis == null:
		return 0.0
	return chassis.angular_velocity

func body_rotation_radians() -> float:
	if chassis == null:
		return 0.0
	return chassis.rotation

func set_controls(new_throttle: float, new_brake: float) -> void:
	throttle_input = clampf(new_throttle, 0.0, 1.0)
	brake_input = clampf(new_brake, 0.0, 1.0)

func add_fuel(amount: float) -> void:
	if dead:
		return
	fuel = minf(FULL_FUEL, fuel + amount)
	fuel_changed.emit(fuel, FULL_FUEL)

func add_coins(amount: int) -> void:
	collected_coins += amount

func current_distance_m() -> float:
	return maxf(0.0, (body_global_position().x - start_x) / Config.PIXELS_PER_METER)

func speed_kmh() -> float:
	return absf(body_linear_velocity().x) * 3.6 / Config.PIXELS_PER_METER

func body_angle_normalized() -> float:
	return wrapf(body_rotation_radians(), -PI, PI) / PI

func is_any_wheel_grounded() -> bool:
	var front_grounded: bool = front_wheel != null and front_wheel.grounded
	var rear_grounded: bool = rear_wheel != null and rear_wheel.grounded
	return front_grounded or rear_grounded

func _physics_process(delta: float) -> void:
	if dead or chassis == null:
		return
	life_time += delta
	var signed_drive: float = throttle_input - brake_input
	_apply_engine_drive(signed_drive, delta)
	_update_flip_failure(delta)
	var consumption: float = 0.25 + absf(signed_drive) * 1.08
	fuel = maxf(0.0, fuel - consumption * delta)
	fuel_changed.emit(fuel, FULL_FUEL)
	var distance_now: float = current_distance_m()
	max_distance_m = maxf(max_distance_m, distance_now)
	if max_distance_m > last_progress_m + 0.04:
		last_progress_m = max_distance_m
		idle_time = 0.0
	else:
		idle_time += delta
	_update_engine_audio(delta)
	if fuel <= 0.0:
		die("Топливо закончилось")
	elif body_global_position().y > 1900.0:
		die("Машина сорвалась с трассы")

func _apply_engine_drive(signed_drive: float, delta: float) -> void:
	var rear_torque: float = Config.engine_torque * signed_drive
	var front_torque: float = rear_torque * FRONT_DRIVE_RATIO
	if rear_wheel != null:
		rear_wheel.apply_engine_drive(rear_torque, delta)
	if front_wheel != null:
		front_wheel.apply_engine_drive(front_torque, delta)
	var traction_force: float = 0.0
	if rear_wheel != null and rear_wheel.grounded:
		traction_force += rear_torque / Wheel.RADIUS
	if front_wheel != null and front_wheel.grounded:
		traction_force += front_torque / Wheel.RADIUS
	if not is_zero_approx(traction_force):
		var tangent: Vector2 = _ground_drive_tangent()
		chassis.apply_central_force(tangent * traction_force * TRACTION_ASSIST_RATIO)
	if not is_any_wheel_grounded():
		chassis.apply_torque(-signed_drive * 9000.0)

func _ground_drive_tangent() -> Vector2:
	var normal_sum: Vector2 = Vector2.ZERO
	if rear_wheel != null and rear_wheel.grounded:
		normal_sum += rear_wheel.ground_normal
	if front_wheel != null and front_wheel.grounded:
		normal_sum += front_wheel.ground_normal
	if normal_sum.length_squared() <= 0.0001:
		return Vector2.RIGHT
	var normal: Vector2 = normal_sum.normalized()
	if normal.y > 0.0:
		normal = -normal
	var tangent: Vector2 = Vector2(-normal.y, normal.x).normalized()
	if tangent.x < 0.0:
		tangent = -tangent
	return tangent

func _update_flip_failure(delta: float) -> void:
	var upside_down: bool = absf(wrapf(body_rotation_radians(), -PI, PI)) > FLIP_ANGLE_LIMIT
	if upside_down and is_any_wheel_grounded():
		upside_down_time += delta
		if upside_down_time >= FLIP_CONTACT_TIME:
			die("Машина перевернулась")
	else:
		upside_down_time = 0.0

func _update_engine_audio(delta: float) -> void:
	if engine_audio == null or ai_controlled:
		return
	var velocity_x: float = body_linear_velocity().x
	var target_pitch: float = 0.68 + minf(1.35, absf(velocity_x) / 1050.0)
	var blend: float = 1.0 - exp(-7.0 * delta)
	engine_audio.pitch_scale = lerpf(engine_audio.pitch_scale, target_pitch, blend)

func _process(_delta: float) -> void:
	if visual_detail_enabled:
		_update_suspension_visuals()

func _update_suspension_visuals() -> void:
	if chassis == null:
		return
	if rear_suspension_visual != null and rear_wheel != null:
		var rear_anchor: Vector2 = chassis.to_global(REAR_SPRING_TOP_LOCAL)
		rear_suspension_visual.points = PackedVector2Array([
			to_local(rear_anchor), to_local(rear_wheel.global_position)
		])
	if front_suspension_visual != null and front_wheel != null:
		var front_anchor: Vector2 = chassis.to_global(FRONT_SPRING_TOP_LOCAL)
		front_suspension_visual.points = PackedVector2Array([
			to_local(front_anchor), to_local(front_wheel.global_position)
		])

func die(reason: String) -> void:
	if dead:
		return
	dead = true
	set_controls(0.0, 0.0)
	if engine_audio != null:
		engine_audio.stop()
	if head_sensor != null:
		head_sensor.monitoring = false
	_freeze_component(chassis)
	_freeze_component(front_wheel)
	_freeze_component(rear_wheel)
	died.emit(reason)

func _freeze_component(component: RigidBody2D) -> void:
	if component == null:
		return
	component.freeze = true
	component.collision_layer = 0
	component.collision_mask = 0

func _on_head_sensor_body_entered(other_body: Node2D) -> void:
	if dead:
		return
	var collision_object: CollisionObject2D = other_body as CollisionObject2D
	if collision_object != null and collision_object.collision_layer & 1:
		die("Водитель коснулся земли")

func _on_engine_audio_finished() -> void:
	if not dead and not ai_controlled and engine_audio != null:
		engine_audio.play()
