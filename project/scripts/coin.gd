class_name Coin
extends Area2D
## Монета подбирается как кузовом, так и колесом. Значение задаёт Game при спавне.

signal collected(value: int)

var coin_value: int = 10
var taken: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func configure(value: int, texture: Texture2D) -> void:
	coin_value = value
	var icon: Sprite2D = get_node_or_null("Sprite2D") as Sprite2D
	if icon != null:
		icon.texture = texture

func _process(delta: float) -> void:
	rotation += delta * 1.8

func _on_body_entered(body: Node2D) -> void:
	if taken:
		return
	var car: Car = _car_from_body(body)
	if car == null or car.dead:
		return
	taken = true
	car.add_coins(coin_value)
	collected.emit(coin_value)
	queue_free()

func _car_from_body(body: Node2D) -> Car:
	if body is Car:
		return body as Car
	var owner_car: Car = body.get_parent() as Car
	return owner_car
