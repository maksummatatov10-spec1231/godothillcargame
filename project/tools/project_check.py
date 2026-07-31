#!/usr/bin/env python3
"""Статическая проверка состава Hill Motion без запуска редактора Godot.

Проверка не подменяет запуск игры: она намеренно ограничена тем, что может
доказать по файлам — целостностью res:// ссылок, сцен, class_name и чистотой
архива. Выход с ошибкой означает конкретную нарушенную инварианту.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

TEXT_EXTENSIONS = {".gd", ".tscn", ".godot", ".md"}
RESOURCE_PATTERN = re.compile(r"res://([^\"'\)\]\s]+)")
CLASS_PATTERN = re.compile(r"^class_name\s+(\w+)", re.MULTILINE)


def fail(message: str) -> None:
    print(f"ОШИБКА: {message}", file=sys.stderr)
    raise SystemExit(1)


def main() -> None:
    root = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
    if not (root / "project.godot").is_file():
        fail(f"{root}: отсутствует project.godot")

    text_files = [
        path for path in root.rglob("*")
        if path.is_file() and path.suffix.lower() in TEXT_EXTENSIONS
    ]
    references: list[tuple[Path, str]] = []
    class_definitions: dict[str, list[Path]] = {}
    forbidden_nodes: list[Path] = []
    inferred_declarations: list[Path] = []

    for path in text_files:
        content = path.read_text(encoding="utf-8")
        if path.suffix == ".gd":
            # В этом проекте нет $Node: только безопасный get_node_or_null.
            if re.search(r"(?m)^\s*(?:@onready\s+)?var\s+\w+.*=\s*\$", content):
                forbidden_nodes.append(path)
            # := от Variant был причиной каскадной ошибки в предыдущих версиях.
            if ":=" in content:
                inferred_declarations.append(path)
            class_match = CLASS_PATTERN.search(content)
            if class_match:
                class_definitions.setdefault(class_match.group(1), []).append(path)
        # Документация может упоминать буквальное «res://»; это не путь.
        # Комментарии GDScript тоже вырезаются, чтобы описание бага не делало
        # проверку зелёной или красной само по себе.
        if path.suffix in {".gd", ".tscn", ".godot"}:
            searchable = re.sub(r"(?m)#.*$", "", content) if path.suffix == ".gd" else content
            for resource in RESOURCE_PATTERN.findall(searchable):
                references.append((path, resource))

    for source, resource in references:
        if not (root / resource).is_file():
            fail(f"битая ссылка res://{resource} в {source.relative_to(root)}")
    if forbidden_nodes:
        fail("найден небезопасный $Node: " + ", ".join(str(p.relative_to(root)) for p in forbidden_nodes))
    if inferred_declarations:
        fail("найдено :=: " + ", ".join(str(p.relative_to(root)) for p in inferred_declarations))
    duplicates = {name: paths for name, paths in class_definitions.items() if len(paths) > 1}
    if duplicates:
        formatted = "; ".join(f"{name}: {paths}" for name, paths in duplicates.items())
        fail("повторяющиеся class_name: " + formatted)

    banned_names = {".godot", "release", "PhysicsCarGameAssets.zip"}
    forbidden = [path for path in root.rglob("*") if path.name in banned_names]
    if forbidden:
        fail("в проект попали служебные/релизные файлы: " + ", ".join(str(p.relative_to(root)) for p in forbidden))

    required = [
        "scenes/Main.tscn", "scenes/Game.tscn", "scenes/Car.tscn",
        "scripts/game.gd", "scripts/evolution_manager.gd", "scripts/neural_network.gd",
    ]
    for relative in required:
        if not (root / relative).is_file():
            fail(f"отсутствует обязательный файл {relative}")

    print("ПРОВЕРКА ПРОЕКТА: успешно")
    print(f"  текстовых файлов: {len(text_files)}")
    print(f"  res:// ссылок: {len(references)}")
    print(f"  уникальных class_name: {len(class_definitions)}")


if __name__ == "__main__":
    main()
