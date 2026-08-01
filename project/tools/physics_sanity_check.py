#!/usr/bin/env python3
"""Численно проверяет стартовую геометрию, опору и тягу машины.

Это не симулятор Godot. Он подтверждает арифметические инварианты текущей
настройки: колесо лежит на направляющей и в точке B пружины, двух пружин хватает
для веса кузова, а тяговая сила достаточна для малого холма. Значения берутся
из реальных .tscn и config.gd, а не дублируются вручную.
"""
from __future__ import annotations

import math
import re
import sys
from pathlib import Path


def fail(message: str) -> None:
    print(f"ОШИБКА ФИЗИЧЕСКОЙ ПРОВЕРКИ: {message}", file=sys.stderr)
    raise SystemExit(1)


def number_from_config(text: str, name: str) -> float:
    match = re.search(rf"(?m)^var {re.escape(name)}: float = ([0-9.]+)", text)
    if match:
        return float(match.group(1))
    symbol_match = re.search(rf"(?m)^var {re.escape(name)}: float = (\w+)", text)
    if symbol_match:
        symbol = symbol_match.group(1)
        constant = re.search(rf"(?m)^const {re.escape(symbol)}: float = ([0-9.]+)", text)
        if constant:
            return float(constant.group(1))
    fail(f"не найдено числовое значение {name} в config.gd")
    return 0.0


def node_block(scene: str, node_name: str) -> str:
    match = re.search(rf"(?ms)^\[node name=\"{re.escape(node_name)}\"[^\]]*\]\n(.*?)(?=^\[node |\Z)", scene)
    if not match:
        fail(f"не найден узел {node_name}")
    return match.group(0)


def vector_property(block: str, property_name: str) -> tuple[float, float]:
    match = re.search(rf"(?m)^{re.escape(property_name)} = Vector2\((-?[0-9.]+), (-?[0-9.]+)\)", block)
    if not match:
        fail(f"не найдено Vector2-свойство {property_name}")
    return float(match.group(1)), float(match.group(2))


def float_property(block: str, property_name: str) -> float:
    match = re.search(rf"(?m)^{re.escape(property_name)} = ([0-9.]+)", block)
    if not match:
        fail(f"не найдено числовое свойство {property_name}")
    return float(match.group(1))


def verify_wheel(scene: str, prefix: str, wheel_name: str) -> None:
    wheel = node_block(scene, wheel_name)
    guide = node_block(scene, f"{prefix}Guide")
    spring = node_block(scene, f"{prefix}Spring")
    wheel_x, wheel_y = vector_property(wheel, "position")
    guide_x, guide_y = vector_property(guide, "position")
    guide_length = float_property(guide, "length")
    initial_offset = float_property(guide, "initial_offset")
    spring_x, spring_y = vector_property(spring, "position")
    spring_length = float_property(spring, "length")

    guide_anchor = (guide_x, guide_y + initial_offset)
    spring_anchor = (spring_x, spring_y + spring_length)
    if math.dist((wheel_x, wheel_y), guide_anchor) > 0.001:
        fail(f"{prefix}: центр колеса не совпадает с initial_offset GrooveJoint2D")
    if math.dist((wheel_x, wheel_y), spring_anchor) > 0.001:
        fail(f"{prefix}: центр колеса не совпадает с B-анкёром DampedSpringJoint2D")
    if not guide_y <= wheel_y <= guide_y + guide_length:
        fail(f"{prefix}: колесо находится вне хода GrooveJoint2D")


def main() -> None:
    root = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
    config = (root / "scripts/config.gd").read_text(encoding="utf-8")
    scene = (root / "scenes/Car.tscn").read_text(encoding="utf-8")
    car = (root / "scripts/car.gd").read_text(encoding="utf-8")

    verify_wheel(scene, "Rear", "RearWheel")
    verify_wheel(scene, "Front", "FrontWheel")

    body_mass = number_from_config(config, "body_mass")
    wheel_mass = number_from_config(config, "wheel_mass")
    gravity = number_from_config(config, "gravity")
    stiffness = number_from_config(config, "suspension_stiffness")
    rest_length = number_from_config(config, "suspension_rest_length")
    torque = number_from_config(config, "engine_torque")
    radius_match = re.search(r"const RADIUS: float = ([0-9.]+)", (root / "scripts/wheel.gd").read_text(encoding="utf-8"))
    ratio_match = re.search(r"const FRONT_DRIVE_RATIO: float = ([0-9.]+)", car)
    assist_match = re.search(r"const TRACTION_ASSIST_RATIO: float = ([0-9.]+)", car)
    if radius_match is None or ratio_match is None or assist_match is None:
        fail("не найдены радиус колеса или коэффициенты тяги")
    radius = float(radius_match.group(1))
    front_ratio = float(ratio_match.group(1))
    assist = float(assist_match.group(1))

    initial_spring_length = 48.0
    support_force = 2.0 * (rest_length - initial_spring_length) * stiffness
    weight = (body_mass + 2.0 * wheel_mass) * gravity
    if support_force < weight * 1.05:
        fail("двух пружин недостаточно для веса машины с запасом 5%")

    traction = torque * (1.0 + front_ratio) / radius * assist
    climb_sine = traction / weight
    if climb_sine < 0.37:
        fail("тяги недостаточно для уклона 22°; малый холм не будет преодолён")

    print("ФИЗИЧЕСКАЯ ПРОВЕРКА: успешно")
    print(f"  начальная опора пружин: {support_force:.0f} против веса {weight:.0f}")
    print(f"  тяга: {traction:.0f}; расчётный уклон без пробуксовки: {math.degrees(math.asin(min(climb_sine, 1.0))):.1f}°")


if __name__ == "__main__":
    main()
