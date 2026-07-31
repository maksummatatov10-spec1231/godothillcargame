class_name NeuralNetwork
extends RefCounted
## Небольшая полносвязная сеть. Веса хранятся плоскими массивами: это удобно
## для генома, сериализации и визуализации без зависимости от узлов игры.

var layers: Array[int] = []
var weights: Array[PackedFloat32Array] = []
var biases: Array[PackedFloat32Array] = []
var activations: Array[PackedFloat32Array] = []
var activation_name: String = "tanh"

func configure(layout: Array[int], genes: PackedFloat32Array, activation: String) -> void:
	layers = layout.duplicate()
	activation_name = activation
	weights.clear()
	biases.clear()
	activations.clear()
	var offset: int = 0
	var layer_index: int = 1
	while layer_index < layers.size():
		var input_count: int = layers[layer_index - 1]
		var output_count: int = layers[layer_index]
		var matrix: PackedFloat32Array = PackedFloat32Array()
		var layer_biases: PackedFloat32Array = PackedFloat32Array()
		matrix.resize(input_count * output_count)
		layer_biases.resize(output_count)
		var weight_index: int = 0
		while weight_index < matrix.size():
			matrix[weight_index] = genes[offset] if offset < genes.size() else 0.0
			offset += 1
			weight_index += 1
		var bias_index: int = 0
		while bias_index < layer_biases.size():
			layer_biases[bias_index] = genes[offset] if offset < genes.size() else 0.0
			offset += 1
			bias_index += 1
		weights.append(matrix)
		biases.append(layer_biases)
		layer_index += 1

func forward(input_values: PackedFloat32Array) -> PackedFloat32Array:
	if layers.is_empty():
		return PackedFloat32Array()
	var current: PackedFloat32Array = PackedFloat32Array()
	current.resize(layers[0])
	var input_index: int = 0
	while input_index < current.size():
		current[input_index] = input_values[input_index] if input_index < input_values.size() else 0.0
		input_index += 1
	activations.clear()
	activations.append(current)
	var layer_index: int = 1
	while layer_index < layers.size():
		var output_count: int = layers[layer_index]
		var next_values: PackedFloat32Array = PackedFloat32Array()
		next_values.resize(output_count)
		var output_index: int = 0
		while output_index < output_count:
			var total: float = biases[layer_index - 1][output_index]
			var previous_index: int = 0
			while previous_index < current.size():
				var weight_offset: int = output_index * current.size() + previous_index
				total += weights[layer_index - 1][weight_offset] * current[previous_index]
				previous_index += 1
			next_values[output_index] = _activate(total)
			output_index += 1
		activations.append(next_values)
		current = next_values
		layer_index += 1
	return current

func _activate(value: float) -> float:
	if activation_name == "relu":
		return clampf(maxf(0.0, value), 0.0, 1.0)
	return tanh(value)

static func gene_count_for(layout: Array[int]) -> int:
	var total: int = 0
	var layer_index: int = 1
	while layer_index < layout.size():
		total += layout[layer_index] * (layout[layer_index - 1] + 1)
		layer_index += 1
	return total
