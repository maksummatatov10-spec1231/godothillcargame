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
    for prefix, wheel_name, x_value in (
        ("Rear", "RearWheel", "-34"),
        ("Front", "FrontWheel", "34"),
    ):
        guide_pattern = (
            rf'\[node name="{prefix}Guide" type="GrooveJoint2D" parent="\."\]\n'
            rf'position = Vector2\({x_value}, 12\)\n'
            r'node_a = NodePath\("\.\./Chassis"\)\n'
            rf'node_b = NodePath\("\.\./{wheel_name}"\)\n'
            r'length = 54\.0\ninitial_offset = 26\.0'
        )
        require(
            car_scene,
            guide_pattern,
            f"{prefix}Guide должен направлять {wheel_name} по вертикали",
        )
        spring_pattern = (
            rf'\[node name="{prefix}Spring" type="DampedSpringJoint2D" parent="\."\]\n'
            rf'position = Vector2\({x_value}, -10\)\n'
            r'node_a = NodePath\("\.\./Chassis"\)\n'
            rf'node_b = NodePath\("\.\./{wheel_name}"\)\n'
            r'length = 48\.0\nrest_length = 58\.0\nstiffness = 750\.0\ndamping = 18\.0'
        )
        require(
            car_scene,
            spring_pattern,
            f"{prefix}Spring должен поддерживать {wheel_name} реальной пружиной",
        )
    if "PinJoint2D" in car_scene:
        fail("PinJoint2D фиксирует колесо намертво и не оставляет хода подвески")
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
    require(config, r'var engine_torque: float = 120000\.0', "базовая тяга двигателя должна быть повышена")
    require(config, r'var suspension_stiffness: float = 750\.0', "жёсткость подвески должна быть задана")
    require(config, r'var suspension_damping: float = 18\.0', "демпфирование подвески должно быть задано")
    require(config, r'var suspension_rest_length: float = 58\.0', "свободная длина пружины должна быть задана")
    car_script = without_comments((root / "scripts/car.gd").read_text(encoding="utf-8"))
    require(car_script, r'var front_guide: GrooveJoint2D', "Car должен хранить переднюю направляющую")
    require(car_script, r'var rear_guide: GrooveJoint2D', "Car должен хранить заднюю направляющую")
    require(car_script, r'var front_spring: DampedSpringJoint2D', "Car должен хранить переднюю пружину")
    require(car_script, r'var rear_spring: DampedSpringJoint2D', "Car должен хранить заднюю пружину")
    require(car_script, r'chassis\.apply_central_force', "тяга должна передаваться кузову вдоль поверхности")
    require(car_script, r'die\("Машина перевернулась"\)', "переворот должен завершать заезд")

    if re.search(r'set_anchors_preset\(Control\.PRESET_(LEFT_WIDE|RIGHT_WIDE)\)', menu):
        fail("фиксированная карточка меню использует растягивающий LayoutPreset")
    require(menu, r'panel\.set_anchors_preset\(Control\.PRESET_TOP_LEFT\)', "главная карточка должна иметь TOP_LEFT anchors")
    require(menu, r'settings_card\.set_anchors_preset\(Control\.PRESET_TOP_RIGHT\)', "карточка настроек должна иметь TOP_RIGHT anchors")
    require(main_script, r'active_game\.mode = selected_mode as Game\.Mode', "int должен явно приводиться к Game.Mode")

    print("ИНВАРИАНТЫ СЦЕН: успешно")
    print("  Car: независимые кузов и колёса, GrooveJoint2D + пружины образуют подвеску")
    print("  spawn: позиция устанавливается до входа Joint2D в дерево")
    print("  UI: фиксированные карточки не используют растягивающие anchors")


if __name__ == "__main__":
    main()
