class_name Wheel
extends RigidBody2D
## Физическое колесо. В физическом тике сохраняет контакт и нормаль земли:
## Car использует их для тяги вдоль склона, а не просто по горизонтали экрана.

const WHEEL_SMALL: Texture2D = preload("res://assets/sprites/car/Wheel.png")
const WHEEL_MEDIUM: Texture2D = preload("res://assets/sprites/car/WheelMedium.png")
const WHEEL_BIG: Texture2D = preload("res://assets/sprites/car/WheelBig.png")
const RADIUS: float = 30.0

var grounded: bool = false
var ground_normal: Vector2 = Vector2.UP
var max_angular_speed: float = 54.0

func _ready() -> void:
	mass = Config.wheel_mass
	gravity_scale = Config.gravity / Config.BASE_GRAVITY
	linear_damp = 0.05
	angular_damp = 0.03
	contact_monitor = true
	max_contacts_reported = 8
	# CanvasItem уже имеет свойство material; другое имя исключает shadow warning.
	var wheel_physics_material: PhysicsMaterial = PhysicsMaterial.new()
	wheel_physics_material.friction = Config.wheel_friction
	wheel_physics_material.bounce = 0.02
	physics_material_override = wheel_physics_material

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	var contact_count: int = state.get_contact_count()
	grounded = contact_count > 0
	if not grounded:
		ground_normal = Vector2.UP
		return
	var accumulated_normal: Vector2 = Vector2.ZERO
	var contact_index: int = 0
	while contact_index < contact_count:
		var local_normal: Vector2 = state.get_contact_local_normal(contact_index)
		var world_normal: Vector2 = state.transform.basis_xform(local_normal)
		if world_normal.y > 0.0:
			world_normal = -world_normal
		accumulated_normal += world_normal.normalized()
		contact_index += 1
	if accumulated_normal.length_squared() > 0.0001:
		ground_normal = accumulated_normal.normalized()
	else:
		ground_normal = Vector2.UP

func apply_engine_drive(torque_value: float, delta: float) -> void:
	if is_zero_approx(torque_value):
		return
	var can_accelerate: bool = absf(angular_velocity) < max_angular_speed
	var reversing: bool = signf(torque_value) != signf(angular_velocity)
	if can_accelerate or reversing:
		apply_torque(torque_value)
	# Корректор оборотов — физический аналог регулятора двигателя. Torque даёт
	# реакцию через контакт, а целевая скорость гарантирует видимое вращение и
	# исключает «замёрзшее» колесо при жёстком контакте GrooveJoint2D.
	var target_speed: float = signf(torque_value) * max_angular_speed
	var response_rate: float = absf(torque_value) / 50000.0
	var blend: float = 1.0 - exp(-response_rate * delta)
	angular_velocity = lerpf(angular_velocity, target_speed, blend)

func set_visual_variant(variant_index: int) -> void:
	var wheel_sprite: Sprite2D = get_node_or_null("Sprite2D") as Sprite2D
	if wheel_sprite == null:
		return
	match variant_index % 3:
		0:
			wheel_sprite.texture = WHEEL_SMALL
			wheel_sprite.scale = Vector2(0.48, 0.48)
		1:
			wheel_sprite.texture = WHEEL_MEDIUM
			wheel_sprite.scale = Vector2(0.31, 0.31)
		_:
			wheel_sprite.texture = WHEEL_BIG
			wheel_sprite.scale = Vector2(0.24, 0.24)
