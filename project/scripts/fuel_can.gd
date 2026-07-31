class_name FuelCan
extends Area2D
## Канистра восстанавливает топливо и остаётся независимой от HUD.

signal collected(amount: float)

var fuel_amount: float = 32.0
var taken: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	position.y += sin(Time.get_ticks_msec() * 0.004 + global_position.x * 0.01) * delta * 7.0

func _on_body_entered(body: Node2D) -> void:
	if taken:
		return
	var car: Car = _car_from_body(body)
	if car == null or car.dead:
		return
	taken = true
	car.add_fuel(fuel_amount)
	collected.emit(fuel_amount)
	queue_free()

func _car_from_body(body: Node2D) -> Car:
	if body is Car:
		return body as Car
	var owner_car: Car = body.get_parent() as Car
	return owner_car
