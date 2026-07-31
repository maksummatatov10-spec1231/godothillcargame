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
    wheel_scene = without_comments((root / "scenes/Wheel.tscn").read_text(encoding="utf-8"))
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
    for axle_name, wheel_name, axle_position in (
        ("RearAxle", "RearWheel", "-34, 38"),
        ("FrontAxle", "FrontWheel", "34, 38"),
    ):
        require(
            car_scene,
            rf'^\[node name="{axle_name}" type="PinJoint2D" parent="\."\]$',
            f"{axle_name} должен быть PinJoint2D под нейтральным Car",
        )
        require(
            car_scene,
            rf'\[node name="{axle_name}" type="PinJoint2D" parent="\."\]\nposition = Vector2\({axle_position}\)',
            f"{axle_name} должен стоять в центре соответствующего колеса",
        )
        require(
            car_scene,
            rf'\[node name="{axle_name}"[\s\S]*?node_a = NodePath\("\.\./Chassis"\)',
            f"{axle_name} должен быть привязан к Chassis",
        )
        require(
            car_scene,
            rf'\[node name="{axle_name}"[\s\S]*?node_b = NodePath\("\.\./{wheel_name}"\)',
            f"{axle_name} должен быть привязан к {wheel_name}",
        )
    if "DampedSpringJoint2D" in car_scene:
        fail("DampedSpringJoint2D без линейной направляющей снова допускает разъезд колёс")
    if re.search(r'parent="Chassis" instance=.*Wheel', car_scene):
        fail("колесо снова вложено в физический кузов")
    require(wheel_scene, r'continuous_cd = 2', "Wheel должен использовать непрерывную коллизию")

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
    require(config, r'var axle_stiffness: float = 110\.0', "жёсткость PinJoint2D должна быть задана")
    car_script = without_comments((root / "scripts/car.gd").read_text(encoding="utf-8"))
    require(car_script, r'var front_axle: PinJoint2D', "Car должен хранить переднюю ось PinJoint2D")
    require(car_script, r'var rear_axle: PinJoint2D', "Car должен хранить заднюю ось PinJoint2D")
    require(car_script, r'front_axle\.softness = axle_softness', "передняя ось должна получать физическую softness")
    require(car_script, r'rear_axle\.softness = axle_softness', "задняя ось должна получать физическую softness")

    if re.search(r'set_anchors_preset\(Control\.PRESET_(LEFT_WIDE|RIGHT_WIDE)\)', menu):
        fail("фиксированная карточка меню использует растягивающий LayoutPreset")
    require(menu, r'panel\.set_anchors_preset\(Control\.PRESET_TOP_LEFT\)', "главная карточка должна иметь TOP_LEFT anchors")
    require(menu, r'settings_card\.set_anchors_preset\(Control\.PRESET_TOP_RIGHT\)', "карточка настроек должна иметь TOP_RIGHT anchors")
    require(main_script, r'active_game\.mode = selected_mode as Game\.Mode', "int должен явно приводиться к Game.Mode")

    print("ИНВАРИАНТЫ СЦЕН: успешно")
    print("  Car: независимые кузов и колёса, оси PinJoint2D привязаны к правильным телам")
    print("  spawn: позиция устанавливается до входа Joint2D в дерево")
    print("  UI: фиксированные карточки не используют растягивающие anchors")


if __name__ == "__main__":
    main()
