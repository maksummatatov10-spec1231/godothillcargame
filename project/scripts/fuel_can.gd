class_name FuelCan
extends Area2D
## Обычная канистра исчезает после одного подбора. Канистра эволюции хранит
## набор машин, уже получивших топливо: один экземпляр виден всем, но запас
## топлива индивидуален и не отнимается у остальных особей.

signal collected(amount: float)

var fuel_amount: float = 38.0
var taken: bool = false
var shared_per_car: bool = false
var collected_car_ids: Dictionary = {}

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func configure_shared_for_cars(amount: float) -> void:
	fuel_amount = amount
	shared_per_car = true

func _process(delta: float) -> void:
	position.y += sin(Time.get_ticks_msec() * 0.004 + global_position.x * 0.01) * delta * 7.0

func _on_body_entered(body: Node2D) -> void:
	if taken:
		return
	var car: Car = _car_from_body(body)
	if car == null or car.dead:
		return
	if shared_per_car:
		var car_id: int = car.get_instance_id()
		if collected_car_ids.has(car_id):
			return
		collected_car_ids[car_id] = true
		car.add_fuel(fuel_amount)
		collected.emit(fuel_amount)
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
