class_name Checkpoint
extends Area2D
## Невидимый маркер прогресса. Он не влияет на физику и пригоден для будущих
## заданий/заездов; сейчас служит честной отметкой дистанции.

signal reached(distance_m: float)

var distance_m: float = 0.0
var triggered: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if triggered:
		return
	var car: Car = body as Car
	if car == null:
		car = body.get_parent() as Car
	if car == null:
		return
	triggered = true
	reached.emit(distance_m)
