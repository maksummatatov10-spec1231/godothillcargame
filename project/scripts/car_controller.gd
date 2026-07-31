class_name CarController
extends Node
## Ручной контроллер. Клавиши опрашиваются напрямую, поэтому работают без
## устаревших записей InputMap из Godot 3.

var car: Car
var hud: HUD

func setup(controlled_car: Car, manual_hud: HUD) -> void:
	car = controlled_car
	hud = manual_hud

func _physics_process(_delta: float) -> void:
	if car == null or not is_instance_valid(car) or car.dead:
		return
	var gas_key: bool = Input.is_key_pressed(KEY_D)
	gas_key = gas_key or Input.is_key_pressed(KEY_RIGHT)
	gas_key = gas_key or Input.is_key_pressed(KEY_SPACE)
	var brake_key: bool = Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)
	var gas_touch: bool = hud != null and hud.accelerate_pressed
	var brake_touch: bool = hud != null and hud.brake_pressed
	var throttle: float = 1.0 if gas_key or gas_touch else 0.0
	var brake: float = 1.0 if brake_key or brake_touch else 0.0
	car.set_controls(throttle, brake)
