class_name Wheel
extends RigidBody2D
## Физическое колесо. Контакт читается непосредственно из физического шага,
## поэтому ИИ не получает устаревшее значение из визуального кадра.

const WHEEL_SMALL: Texture2D = preload("res://assets/sprites/car/Wheel.png")
const WHEEL_MEDIUM: Texture2D = preload("res://assets/sprites/car/WheelMedium.png")
const WHEEL_BIG: Texture2D = preload("res://assets/sprites/car/WheelBig.png")

var grounded: bool = false
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
	grounded = state.get_contact_count() > 0

func apply_drive_torque(torque_value: float) -> void:
	if absf(angular_velocity) < max_angular_speed or signf(torque_value) != signf(angular_velocity):
		apply_torque(torque_value)

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
