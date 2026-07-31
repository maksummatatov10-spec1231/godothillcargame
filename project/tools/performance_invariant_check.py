#!/usr/bin/env python3
"""Проверяет оптимизации, не меняющие состав игры и её физический тик.

Инструмент не измеряет FPS без устройства пользователя. Он охраняет конкретные
структурные причины нагрузки: raycast-опрос каждой ИИ-машины, перерисовку
визуализации, Line2D невыбранных машин, физику уже погибших тел и избыточную
перекраску всех 150 машин на каждом тике. Комментарии исключаются до анализа.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path


def fail(message: str) -> None:
    print(f"ОШИБКА ПРОИЗВОДИТЕЛЬНОСТИ: {message}", file=sys.stderr)
    raise SystemExit(1)


def strip_comments(text: str) -> str:
    lines: list[str] = []
    for line in text.splitlines(keepends=True):
        in_string = False
        escaped = False
        result: list[str] = []
        for char in line:
            if char == '"' and not escaped:
                in_string = not in_string
            if char == "#" and not in_string:
                result.extend(" " for _ in line[len(result):])
                break
            result.append(char)
            escaped = char == "\\" and not escaped
            if char != "\\":
                escaped = False
        lines.append("".join(result))
    return "".join(lines)


def function_body(text: str, function_name: str) -> str:
    match = re.search(rf"(?m)^func {re.escape(function_name)}\([^\n]*\)[^\n]*:\n", text)
    if not match:
        fail(f"не найдена функция {function_name}")
    after = text[match.end():]
    next_function = re.search(r"(?m)^func ", after)
    return after[:next_function.start()] if next_function else after


def require(text: str, expression: str, description: str) -> None:
    if not re.search(expression, text, re.MULTILINE):
        fail(description)


def main() -> None:
    root = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
    ai = strip_comments((root / "scripts/ai_car_controller.gd").read_text(encoding="utf-8"))
    car = strip_comments((root / "scripts/car.gd").read_text(encoding="utf-8"))
    evolution = strip_comments((root / "scripts/evolution_manager.gd").read_text(encoding="utf-8"))
    network = strip_comments((root / "scripts/network_visualizer.gd").read_text(encoding="utf-8"))

    require(ai, r"const DECISION_INTERVAL: float = 1\.0 / 30\.0", "ИИ должен опрашивать raycast-сенсоры в 30 Гц")
    ai_tick = function_body(ai, "_physics_process")
    gate_index = ai_tick.find("if decision_elapsed < DECISION_INTERVAL")
    input_index = ai_tick.find("_collect_inputs()")
    if gate_index < 0 or input_index < 0 or gate_index > input_index:
        fail("проверка интервала ИИ должна выполняться до _collect_inputs()")

    require(network, r"const REDRAW_INTERVAL: float = 1\.0 / 30\.0", "визуализация сети должна иметь лимит redraw")
    network_tick = function_body(network, "_process")
    redraw_guard = network_tick.find("if redraw_elapsed >= REDRAW_INTERVAL")
    redraw_call = network_tick.find("queue_redraw()")
    if redraw_guard < 0 or redraw_call < 0 or redraw_guard > redraw_call:
        fail("queue_redraw() сети должен быть защищён интервалом")

    car_idle = function_body(car, "_process")
    require(car_idle, r"if visual_detail_enabled:\n\s+_update_suspension_visuals\(\)", "Line2D должны обновляться только у выбранной машины")
    die_body = function_body(car, "die")
    if die_body.count("_freeze_component(") < 3:
        fail("после смерти должны замораживаться кузов и оба колеса")
    freeze_body = function_body(car, "_freeze_component")
    require(freeze_body, r"component\.freeze = true", "мёртвое тело должно выключаться из физики")
    require(freeze_body, r"component\.collision_layer = 0", "мёртвое тело должно уходить из collision layer")
    require(freeze_body, r"component\.collision_mask = 0", "мёртвое тело должно уходить из collision mask")

    evolution_tick = function_body(evolution, "_physics_process")
    if "_update_target()" in evolution_tick:
        fail("нельзя перекрашивать всю популяцию через _update_target() каждый тик")
    require(evolution, r"const STATISTICS_INTERVAL: float = 0\.10", "HUD эволюции должен иметь ограничение частоты")
    require(evolution_tick, r"if statistics_elapsed >= STATISTICS_INTERVAL", "статистика должна обновляться по интервалу")
    target_body = function_body(evolution, "_update_target")
    require(target_body, r"car\.set_visual_detail_enabled\(is_selected\)", "детали подвески должны оставаться только у выбранной машины")

    print("ИНВАРИАНТЫ ПРОИЗВОДИТЕЛЬНОСТИ: успешно")
    print("  ИИ: raycast/сеть 30 Гц при сохранении физики на каждом тике")
    print("  UI: сеть и статистика обновляются с лимитом частоты")
    print("  Популяция: невыбранные Line2D не обновляются, погибшие тела заморожены")


if __name__ == "__main__":
    main()
