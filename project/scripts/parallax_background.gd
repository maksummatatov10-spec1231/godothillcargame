class_name ParallaxBackground
extends Parallax2D
## Два слоя из архива: дальние горы движутся медленнее камеры, облака — ещё
## медленнее. Повтор по X не оставляет пустого неба на длинной трассе.

const BACKDROP: Texture2D = preload("res://assets/sprites/background/SceneBG.png")
const CLOUDS: Texture2D = preload("res://assets/sprites/background/Clouds.png")

func _ready() -> void:
	repeat_size = Vector2(3000.0, 0.0)
	scroll_scale = Vector2(0.16, 0.0)
	var mountains: Sprite2D = Sprite2D.new()
	mountains.texture = BACKDROP
	mountains.position = Vector2(0.0, 470.0)
	mountains.z_index = -30
	add_child(mountains)
	var cloud_layer: Parallax2D = Parallax2D.new()
	cloud_layer.repeat_size = Vector2(3000.0, 0.0)
	cloud_layer.scroll_scale = Vector2(0.06, 0.0)
	var clouds: Sprite2D = Sprite2D.new()
	clouds.texture = CLOUDS
	clouds.position = Vector2(0.0, 230.0)
	clouds.modulate = Color(1.0, 1.0, 1.0, 0.72)
	clouds.z_index = -31
	cloud_layer.add_child(clouds)
	add_child(cloud_layer)
