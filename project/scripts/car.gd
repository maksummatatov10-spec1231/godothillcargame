class_name Car
extends Node2D
## Сборка машины: кузов и колёса — СОСЕДНИЕ RigidBody2D под нейтральным Node2D.
## Вложенный RigidBody2D наследует transform физического родителя и разрывает
## подвеску, поэтому Car намеренно не является RigidBody2D.

signal died(reason: String)
signal fuel_changed(current: float, maximum: float)

const FULL_FUEL: float = 100.0
const BLUE_CHASSIS: Texture2D = preload("res://assets/sprites/car/Car.png")
const AI_BODY: Texture2D = preload("res://assets/sprites/characters/Body2.png")
const AI_HEAD: Texture2D = preload("res://assets/sprites/characters/Head2.png")
const REAR_ANCHOR_LOCAL: Vector2 = Vector2(-34.0, -4.0)
const FRONT_ANCHOR_LOCAL: Vector2 = Vector2(34.0, -4.0)

var chassis: RigidBody2D
var front_wheel: Wheel
var rear_wheel: Wheel
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
var dead: bool = false
var ai_controlled: bool = false
var collected_coins: int = 0
var last_progress_m: float = 0.0

func _ready() -> void:
	chassis = get_node_or_null("Chassis") as RigidBody2D
	front_wheel = get_node_or_null("FrontWheel") as Wheel
	rear_wheel = get_node_or_null("RearWheel") as Wheel
	front_spring = get_node_or_null("FrontSpring") as DampedSpringJoint2D
	rear_spring = get_node_or_null("RearSpring") as DampedSpringJoint2D
	head_sensor = get_node_or_null("Chassis/HeadSensor") as Area2D
	engine_audio = get_node_or_null("Chassis/EngineAudio") as AudioStreamPlayer2D
	front_suspension_visual = get_node_or_null("FrontSuspensionVisual") as Line2D
	rear_suspension_visual = get_node_or_null("RearSuspensionVisual") as Line2D
	_configure_chassis()
	_configure_wheels()
	_configure_springs()
	if head_sensor != null:
		head_sensor.body_entered.connect(_on_head_sensor_body_entered)
	if engine_audio != null and not ai_controlled:
		engine_audio.finished.connect(_on_engine_audio_finished)
		engine_audio.play()
	_update_suspension_visuals()

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

func _configure_springs() -> void:
	var rest_length: float = Config.suspension_length * 0.94
	if front_spring != null:
		front_spring.length = Config.suspension_length
		front_spring.rest_length = rest_length
		front_spring.stiffness = Config.suspension_stiffness
		front_spring.damping = Config.suspension_damping
	if rear_spring != null:
		rear_spring.length = Config.suspension_length
		rear_spring.rest_length = rest_length
		rear_spring.stiffness = Config.suspension_stiffness
		rear_spring.damping = Config.suspension_damping

func initialise(spawn_x: float, is_ai: bool, tint: Color = Color.WHITE) -> void:
	start_x = spawn_x
	ai_controlled = is_ai
	modulate = tint
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
	var drive_torque: float = Config.engine_torque * signed_drive
	if rear_wheel != null:
		rear_wheel.apply_drive_torque(drive_torque)
	if front_wheel != null:
		front_wheel.apply_drive_torque(drive_torque * 0.58)
	if not is_any_wheel_grounded():
		chassis.apply_torque(-signed_drive * 9000.0)
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
	if engine_audio != null and not ai_controlled:
		var velocity_x: float = body_linear_velocity().x
		var target_pitch: float = 0.68 + minf(1.35, absf(velocity_x) / 1050.0)
		var blend: float = 1.0 - exp(-7.0 * delta)
		engine_audio.pitch_scale = lerpf(engine_audio.pitch_scale, target_pitch, blend)
	if fuel <= 0.0:
		die("Топливо закончилось")
	elif body_global_position().y > 1900.0:
		die("Машина сорвалась с трассы")

func _process(_delta: float) -> void:
	_update_suspension_visuals()

func _update_suspension_visuals() -> void:
	if chassis == null:
		return
	if rear_suspension_visual != null and rear_wheel != null:
		var rear_anchor: Vector2 = chassis.to_global(REAR_ANCHOR_LOCAL)
		rear_suspension_visual.points = PackedVector2Array([
			to_local(rear_anchor), to_local(rear_wheel.global_position)
		])
	if front_suspension_visual != null and front_wheel != null:
		var front_anchor: Vector2 = chassis.to_global(FRONT_ANCHOR_LOCAL)
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
	died.emit(reason)

func _on_head_sensor_body_entered(other_body: Node2D) -> void:
	if dead:
		return
	var collision_object: CollisionObject2D = other_body as CollisionObject2D
	if collision_object != null and collision_object.collision_layer & 1:
		die("Водитель коснулся земли")

func _on_engine_audio_finished() -> void:
	if not dead and not ai_controlled and engine_audio != null:
		engine_audio.play()
