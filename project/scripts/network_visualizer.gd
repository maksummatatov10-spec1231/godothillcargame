class_name NetworkVisualizer
extends Control
## Компактный рендер сети: толщина связи зависит от |веса|, зелёный —
## положительная связь, красный — отрицательная, заливка — активация.

const REDRAW_INTERVAL: float = 1.0 / 30.0

# PackedStringArray(...) нельзя объявить как const в GDScript 4.3: это вызов
# конструктора, а не constant expression. Подписи малы и создаются раз на UI.
var input_names: PackedStringArray = PackedStringArray([
	"Vx", "Vy", "ω", "угол", "высота", "кол. П", "кол. З", "ω П", "ω З",
	"луч 1", "луч 2", "луч 3", "луч 4", "луч 5", "луч 6", "луч 7",
	"топливо", "дист."
])
var output_names: PackedStringArray = PackedStringArray(["газ", "тормоз"])

var network: NeuralNetwork
var visible_network: bool = true
var redraw_elapsed: float = 0.0

func _ready() -> void:
	custom_minimum_size = Vector2(370.0, 260.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_network(new_network: NeuralNetwork) -> void:
	network = new_network
	queue_redraw()

func set_network_visible(value: bool) -> void:
	visible_network = value
	visible = value

func _process(delta: float) -> void:
	if not visible_network or network == null:
		return
	# Активности сети меняются в ИИ-контроллере 30 раз в секунду. Рисовать их
	# чаще бессмысленно и дорого при высоком FPS на мобильном устройстве.
	redraw_elapsed += delta
	if redraw_elapsed >= REDRAW_INTERVAL:
		redraw_elapsed = fmod(redraw_elapsed, REDRAW_INTERVAL)
		queue_redraw()

func _draw() -> void:
	if network == null or network.layers.size() < 2:
		return
	var backdrop: Rect2 = Rect2(Vector2.ZERO, size)
	draw_style_box(UIStyle.panel_style(Color("0d1723de"), 14), backdrop)
	var font: Font = ThemeDB.fallback_font
	draw_string(
		font, Vector2(14.0, 20.0), "Сеть выбранной машины",
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, UIStyle.MUTED
	)
	var coordinates: Array[PackedVector2Array] = []
	var layer_count: int = network.layers.size()
	var layer_index: int = 0
	while layer_index < layer_count:
		var node_positions: PackedVector2Array = PackedVector2Array()
		var node_count: int = network.layers[layer_index]
		var x_value: float = 43.0 + (size.x - 86.0) * float(layer_index) / float(maxi(1, layer_count - 1))
		var node_index: int = 0
		while node_index < node_count:
			var y_value: float = 40.0 + (size.y - 62.0) * float(node_index) / float(maxi(1, node_count - 1))
			node_positions.append(Vector2(x_value, y_value))
			node_index += 1
		coordinates.append(node_positions)
		layer_index += 1
	var edge_layer: int = 1
	while edge_layer < layer_count:
		var destination_index: int = 0
		while destination_index < coordinates[edge_layer].size():
			var source_index: int = 0
			while source_index < coordinates[edge_layer - 1].size():
				var weight_index: int = destination_index * coordinates[edge_layer - 1].size() + source_index
				var weight: float = network.weights[edge_layer - 1][weight_index]
				var connection_color: Color = Color("55df9a") if weight >= 0.0 else Color("f06b78")
				connection_color.a = 0.18 + minf(0.70, absf(weight) * 0.32)
				var line_start: Vector2 = coordinates[edge_layer - 1][source_index]
				var line_end: Vector2 = coordinates[edge_layer][destination_index]
				var line_width: float = 0.6 + minf(2.3, absf(weight) * 1.2)
				draw_line(line_start, line_end, connection_color, line_width, true)
				source_index += 1
			destination_index += 1
		edge_layer += 1
	var node_layer: int = 0
	while node_layer < layer_count:
		var node_index: int = 0
		while node_index < coordinates[node_layer].size():
			var value: float = 0.0
			var has_activation: bool = node_layer < network.activations.size()
			has_activation = has_activation and node_index < network.activations[node_layer].size()
			if has_activation:
				value = network.activations[node_layer][node_index]
			var fill: Color = Color("3bcfa2") if value >= 0.0 else Color("ed6b7a")
			fill.a = 0.35 + minf(0.65, absf(value))
			draw_circle(coordinates[node_layer][node_index], 5.1, fill)
			draw_arc(coordinates[node_layer][node_index], 5.1, 0.0, TAU, 16, UIStyle.INK, 0.9, true)
			if node_layer == 0 and node_index < input_names.size():
				var input_label_pos: Vector2 = coordinates[node_layer][node_index]
				input_label_pos += Vector2(-32.0, 3.5)
				draw_string(
					font, input_label_pos, input_names[node_index],
					HORIZONTAL_ALIGNMENT_LEFT, 30.0, 8, UIStyle.MUTED
				)
			elif node_layer == layer_count - 1 and node_index < output_names.size():
				var output_label_pos: Vector2 = coordinates[node_layer][node_index]
				output_label_pos += Vector2(9.0, 3.5)
				draw_string(
					font, output_label_pos, output_names[node_index],
					HORIZONTAL_ALIGNMENT_LEFT, 42.0, 9, UIStyle.INK
				)
			node_index += 1
		node_layer += 1
