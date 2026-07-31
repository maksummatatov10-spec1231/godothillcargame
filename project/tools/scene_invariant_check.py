#!/usr/bin/env python3
"""Инварианты сцен, которые нельзя надёжно проверить только gdparse.

Проверяет механизм, вызвавший разрыв машины и пропажу меню: независимые
RigidBody2D должны быть соседями под нейтральной сборкой, anchors Joint2D
должны создаваться после выставления позиции, а фиксированные панели не должны
получать растягивающий LayoutPreset. Комментарии исключаются до анализа.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path


def fail(message: str) -> None:
    print(f"ОШИБКА ИНВАРИАНТА: {message}", file=sys.stderr)
    raise SystemExit(1)


def without_comments(text: str) -> str:
    result: list[str] = []
    for line in text.splitlines(keepends=True):
        in_string = False
        escaped = False
        cut = len(line)
        for index, char in enumerate(line):
            if char == '"' and not escaped:
                in_string = not in_string
            if char == "#" and not in_string:
                cut = index
                break
            escaped = char == "\\" and not escaped
            if char != "\\":
                escaped = False
        suffix = "\n" if line.endswith("\n") else ""
        result.append(line[:cut] + " " * (len(line[cut:]) - len(suffix)) + suffix)
    return "".join(result)


def require(text: str, expression: str, description: str) -> None:
    if not re.search(expression, text, re.MULTILINE):
        fail(description)


def main() -> None:
    root = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
    car_scene = (root / "scenes/Car.tscn").read_text(encoding="utf-8")
    game = without_comments((root / "scripts/game.gd").read_text(encoding="utf-8"))
    evolution = without_comments((root / "scripts/evolution_manager.gd").read_text(encoding="utf-8"))
    menu = without_comments((root / "scripts/UI/main_menu.gd").read_text(encoding="utf-8"))
    main_script = without_comments((root / "scripts/main.gd").read_text(encoding="utf-8"))
    config = without_comments((root / "scripts/config.gd").read_text(encoding="utf-8"))

    require(car_scene, r'^\[node name="Car" type="Node2D"\]$', "Car должен иметь нейтральный Node2D-корень")
    require(car_scene, r'^\[node name="Chassis" type="RigidBody2D" parent="\."\]$', "Chassis должен быть RigidBody2D-соседом колёс")
    for wheel_name in ("RearWheel", "FrontWheel"):
        require(
            car_scene,
            rf'^\[node name="{wheel_name}" parent="\." instance=',
            f"{wheel_name} должен быть RigidBody2D-соседом, а не ребёнком кузова",
        )
    require(car_scene, r'node_a = NodePath\("\.\./Chassis"\)', "Joint2D должен быть привязан к Chassis")
    require(car_scene, r'node_b = NodePath\("\.\./RearWheel"\)', "задний Joint2D должен быть привязан к RearWheel")
    require(car_scene, r'node_b = NodePath\("\.\./FrontWheel"\)', "передний Joint2D должен быть привязан к FrontWheel")
    if re.search(r'parent="Chassis" instance=.*Wheel', car_scene):
        fail("колесо снова вложено в физический кузов")

    require(
        game,
        r'manual_car\.position = Vector2\(spawn_x, spawn_y\)\s*\n\s*add_child\(manual_car\)',
        "manual_car.position должна задаваться до add_child(manual_car)",
    )
    require(
        evolution,
        r'car\.position = Vector2\(spawn_x, spawn_y\)\s*\n\s*vehicle_parent\.add_child\(car\)',
        "позиция ИИ-машины должна задаваться до add_child",
    )
    require(config, r'var suspension_length: float = 42\.0', "длина пружины должна совпадать с anchors сцены")

    if re.search(r'set_anchors_preset\(Control\.PRESET_(LEFT_WIDE|RIGHT_WIDE)\)', menu):
        fail("фиксированная карточка меню использует растягивающий LayoutPreset")
    require(menu, r'panel\.set_anchors_preset\(Control\.PRESET_TOP_LEFT\)', "главная карточка должна иметь TOP_LEFT anchors")
    require(menu, r'settings_card\.set_anchors_preset\(Control\.PRESET_TOP_RIGHT\)', "карточка настроек должна иметь TOP_RIGHT anchors")
    require(main_script, r'active_game\.mode = selected_mode as Game\.Mode', "int должен явно приводиться к Game.Mode")

    print("ИНВАРИАНТЫ СЦЕН: успешно")
    print("  Car: независимые кузов и колёса, anchors привязаны к правильным телам")
    print("  spawn: позиция устанавливается до входа Joint2D в дерево")
    print("  UI: фиксированные карточки не используют растягивающие anchors")


if __name__ == "__main__":
    main()
