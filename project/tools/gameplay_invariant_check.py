#!/usr/bin/env python3
"""Проверяет правила заезда: проигрыш, топливо, карта и общие ИИ-канистры.

Это структурная проверка, не заменяющая живой прогон Godot. Она охраняет
механизмы, из-за которых игрок уже получил неверное поведение: медленный расход,
пропущенное касание головы, скопление топлива и исчезновение общей канистры
после первой ИИ-машины. Комментарии исключаются до анализа.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path


def fail(message: str) -> None:
    print(f"ОШИБКА ГЕЙМПЛЕЯ: {message}", file=sys.stderr)
    raise SystemExit(1)


def strip_comments(text: str) -> str:
    result: list[str] = []
    for line in text.splitlines(keepends=True):
        quote = False
        escaped = False
        output: list[str] = []
        for char in line:
            if char == '"' and not escaped:
                quote = not quote
            if char == "#" and not quote:
                output.extend(" " for _ in line[len(output):])
                break
            output.append(char)
            escaped = char == "\\" and not escaped
            if char != "\\":
                escaped = False
        result.append("".join(output))
    return "".join(result)


def body(text: str, name: str) -> str:
    match = re.search(rf"(?m)^func {re.escape(name)}\([^\n]*\)[^\n]*:\n", text)
    if not match:
        fail(f"не найдена функция {name}")
    tail = text[match.end():]
    next_function = re.search(r"(?m)^func ", tail)
    return tail[:next_function.start()] if next_function else tail


def require(text: str, expression: str, description: str) -> None:
    if not re.search(expression, text, re.MULTILINE):
        fail(description)


def main() -> None:
    root = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
    car = strip_comments((root / "scripts/car.gd").read_text(encoding="utf-8"))
    game = strip_comments((root / "scripts/game.gd").read_text(encoding="utf-8"))
    fuel = strip_comments((root / "scripts/fuel_can.gd").read_text(encoding="utf-8"))
    car_scene = (root / "scenes/Car.tscn").read_text(encoding="utf-8")
    evolution = strip_comments((root / "scripts/evolution_manager.gd").read_text(encoding="utf-8"))
    terrain = strip_comments((root / "scripts/terrain_generator.gd").read_text(encoding="utf-8"))
    config = strip_comments((root / "scripts/config.gd").read_text(encoding="utf-8"))

    require(car, r"\(0\.25 \+ absf\(signed_drive\) \* 1\.08\) \* 3\.0", "расход топлива должен быть ускорен в 3 раза")
    require(car, r"func _check_head_overlap", "нужна резервная проверка перекрытия головы")
    require(car_scene, r"\[node name=\"HeadCollision\" type=\"CollisionShape2D\" parent=\"Chassis\"\]", "голова должна иметь физическую форму")
    require(car, r"head_sensor\.get_overlapping_bodies\(\)", "голова должна проверять устойчивое перекрытие")
    require(car, r"func _head_touches_terrain", "голова должна иметь shape-проверку стены")
    head_overlap = body(car, "_check_head_overlap")
    require(head_overlap, r"if _head_touches_terrain\(\):", "shape-проверка стены должна вызываться при наклоне")
    require(car, r"space_state\.intersect_shape\(query, 1\)", "shape-проверка головы должна искать карту")
    require(car, r"die\(\"Водитель коснулся земли\"\)", "касание головы должно завершать заезд")
    require(car, r"die\(\"Машина перевернулась\"\)", "переворот должен завершать заезд")

    require(game, r"var next_fuel_x: float", "канистры ручного режима должны иметь отдельный планировщик")
    manual_spawner = body(game, "_spawn_manual_content_ahead")
    require(manual_spawner, r"while next_fuel_x < desired_x", "канистры должны распределяться по дистанции")
    if "fuel_density * 0.17" in manual_spawner:
        fail("случайный спавн топлива снова допускает кластеры")
    require(game, r"func _manual_fuel_spacing", "для топлива нужен минимальный шаг по дистанции")

    require(fuel, r"var shared_per_car: bool = false", "канистра должна поддерживать индивидуальный подбор")
    require(fuel, r"var collected_car_ids: Dictionary", "канистра должна помнить получившие её машины")
    shared_branch = body(fuel, "_on_body_entered")
    require(shared_branch, r"if shared_per_car:", "отсутствует ветка общей канистры")
    require(shared_branch, r"if collected_car_ids\.has\(car_id\)", "повторный подбор одной машиной должен блокироваться")
    require(shared_branch, r"collected_car_ids\[car_id\] = true", "подбор должен быть индивидуально записан")
    shared_start = shared_branch.find("if shared_per_car:")
    shared_end = shared_branch.find("taken = true", shared_start)
    if "queue_free()" in shared_branch[shared_start:shared_end]:
        fail("общая канистра исчезает после первой ИИ-машины")
    require(evolution, r"fuel_can\.configure_shared_for_cars\(38\.0\)", "эволюция должна создавать общие канистры")

    require(config, r"var initial_genome_spread: float = 0\.28", "первое поколение должно стартовать без сильной стратегии")
    require(evolution, r"Genome\.create_random\(layout, random, Config\.initial_genome_spread\)", "первое поколение должно получать нейтральные случайные гены")
    genome = strip_comments((root / "scripts/genome.gd").read_text(encoding="utf-8"))
    require(genome, r"random\.randf_range\(-spread, spread\)", "разброс стартовых генов должен применяться")

    require(config, r"var track_length_m: float = 0\.0", "настройка длины карты должна существовать")
    require(config, r"func track_end_x", "нужен перевод длины карты в координаты")
    require(terrain, r"minf\(world_x \+ KEEP_AHEAD, Config\.track_end_x\(\)\)", "генератор должен учитывать длину карты")
    require(game, r"evolution\.apply_track_length_and_restart\(\)", "длину карты нужно применять прямо в режиме эволюции")

    print("ИНВАРИАНТЫ ГЕЙМПЛЕЯ: успешно")
    print("  Проигрыш: голова и переворот защищены двумя независимыми путями")
    print("  Топливо: расход x3, ручной спавн разнесён, ИИ-подбор индивидуален")
    print("  Карта: длина ограничивает генерацию и применяется из панели")


if __name__ == "__main__":
    main()
