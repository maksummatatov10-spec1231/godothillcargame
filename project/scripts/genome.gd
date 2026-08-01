class_name Genome
extends RefCounted
## Геном не содержит игровых объектов: только структуру сети, веса и fitness.

var layers: Array[int] = []
var genes: PackedFloat32Array = PackedFloat32Array()
var fitness: float = 0.0

static func create_random(
	layout: Array[int], random: RandomNumberGenerator, spread: float = 1.0
) -> Genome:
	var result: Genome = Genome.new()
	result.layers = layout.duplicate()
	result.genes.resize(NeuralNetwork.gene_count_for(layout))
	var index: int = 0
	while index < result.genes.size():
		result.genes[index] = random.randf_range(-spread, spread)
		index += 1
	return result

func duplicate_genome() -> Genome:
	var result: Genome = Genome.new()
	result.layers = layers.duplicate()
	result.genes = genes.duplicate()
	result.fitness = fitness
	return result

static func crossover(
	first_parent: Genome, second_parent: Genome, random: RandomNumberGenerator
) -> Genome:
	var result: Genome = Genome.new()
	result.layers = first_parent.layers.duplicate()
	result.genes.resize(first_parent.genes.size())
	var index: int = 0
	while index < result.genes.size():
		var from_first: bool = random.randf() < 0.5
		var second_value: float = first_parent.genes[index]
		if index < second_parent.genes.size():
			second_value = second_parent.genes[index]
		result.genes[index] = first_parent.genes[index] if from_first else second_value
		index += 1
	return result

func mutate(random: RandomNumberGenerator, probability: float, strength: float) -> void:
	var index: int = 0
	while index < genes.size():
		if random.randf() < probability:
			genes[index] = clampf(genes[index] + random.randfn(0.0, strength), -4.0, 4.0)
		index += 1
