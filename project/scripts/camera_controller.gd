class_name CameraController
extends Camera2D
## Камера сглаживает только собственное положение. Она не меняет transform
## машины и не вмешивается в физику её колёс.

var target_car: Car
var look_ahead: float = 170.0
var height_offset: float = -115.0
var follow_rate: float = 5.0

func set_target(new_target: Car) -> void:
	target_car = new_target

func _process(delta: float) -> void:
	if target_car == null or not is_instance_valid(target_car):
		return
	var desired: Vector2 = target_car.global_position + Vector2(look_ahead, height_offset)
	var blend: float = 1.0 - exp(-follow_rate * delta)
	global_position = global_position.lerp(desired, blend)
