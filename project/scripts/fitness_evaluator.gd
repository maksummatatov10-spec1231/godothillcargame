class_name FitnessEvaluator
extends RefCounted
## Дистанция доминирует в оценке. Топливо и время нужны лишь как небольшой
## стимул для устойчивой, а не случайно далёкой траектории.

static func evaluate(car: Car) -> float:
	var distance_score: float = car.max_distance_m * 1000.0
	var fuel_score: float = car.fuel * 1.5
	var stability_score: float = minf(car.life_time, 30.0) * 3.0
	return distance_score + fuel_score + stability_score
