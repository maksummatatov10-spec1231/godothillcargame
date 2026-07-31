#!/usr/bin/env python3
"""Ловит известные несовместимые с GDScript Godot 4.3 конструкции.

Это не замена компилятора Godot. Он проверяет именно формы, уже доказанно
сломавшие проект: Packed*Array(...) в const, несуществующие LayoutPreset,
скрытие нативного ParallaxBackground, shadowing CanvasItem.material и двойное
объявление переменной цикла. Комментарии исключаются до анализа.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

BAD_PRESETS = {
    "PRESET_LEFT_BOTTOM": "PRESET_BOTTOM_LEFT",
    "PRESET_RIGHT_BOTTOM": "PRESET_BOTTOM_RIGHT",
    "PRESET_RIGHT_TOP": "PRESET_TOP_RIGHT",
}
NATIVE_CLASS_NAMES = {"ParallaxBackground"}


def source_without_comments(text: str) -> str:
    """Сохраняет номера строк, удаляя только однострочные комментарии GDScript."""
    cleaned: list[str] = []
    for line in text.splitlines(keepends=True):
        in_string = False
        escaped = False
        result: list[str] = []
        for char in line:
            if char == '"' and not escaped:
                in_string = not in_string
            if char == "#" and not in_string:
                # Пробелы оставляют номера колонок, а перевод строки — строк.
                tail = line[len(result):]
                has_newline = tail.endswith("\n")
                result.extend(" " * (len(tail) - (1 if has_newline else 0)))
                if has_newline:
                    result.append("\n")
                break
            result.append(char)
            escaped = char == "\\" and not escaped
            if char != "\\":
                escaped = False
        cleaned.append("".join(result))
    return "".join(cleaned)


def line_number(text: str, index: int) -> int:
    return text.count("\n", 0, index) + 1


def main() -> None:
    root = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
    scripts = sorted((root / "scripts").rglob("*.gd"))
    if not scripts:
        raise SystemExit("ОШИБКА: scripts/*.gd не найдены")

    problems: list[str] = []
    for script in scripts:
        raw = script.read_text(encoding="utf-8")
        text = source_without_comments(raw)
        relative = script.relative_to(root)

        for match in re.finditer(r"(?m)^\s*const\s+\w+[^\n=]*=\s*Packed\w+Array\s*\(", text):
            problems.append(
                f"{relative}:{line_number(text, match.start())}: "
                "Packed*Array(...) нельзя использовать как const в GDScript 4.3"
            )
        for wrong, correct in BAD_PRESETS.items():
            for match in re.finditer(rf"\bControl\.{wrong}\b", text):
                problems.append(
                    f"{relative}:{line_number(text, match.start())}: "
                    f"Control.{wrong} не существует; нужно Control.{correct}"
                )
        class_match = re.search(r"(?m)^\s*class_name\s+(\w+)", text)
        if class_match and class_match.group(1) in NATIVE_CLASS_NAMES:
            problems.append(
                f"{relative}:{line_number(text, class_match.start())}: "
                f"class_name {class_match.group(1)} скрывает нативный класс Godot"
            )
        for match in re.finditer(r"(?m)^\s*var\s+material\b", text):
            problems.append(
                f"{relative}:{line_number(text, match.start())}: "
                "локальная material затеняет CanvasItem.material"
            )
        for match in re.finditer(
            r"(?m)^\s*var\s+(\w+)\s*(?::[^\n=]+)?(?:=[^\n]*)?\n\s*for\s+\1\s+in\b",
            text,
        ):
            problems.append(
                f"{relative}:{line_number(text, match.start())}: "
                f"переменная цикла {match.group(1)} объявлена дважды в одной области"
            )

    if problems:
        print("ОШИБКИ СОВМЕСТИМОСТИ GODOT 4.3:", file=sys.stderr)
        print("\n".join(problems), file=sys.stderr)
        raise SystemExit(1)

    print("СОВМЕСТИМОСТЬ GODOT 4.3: успешно")
    print(f"  проверено GDScript-файлов: {len(scripts)}")
    print("  исключены: Packed-константы, неверные LayoutPreset, shadowing и class collision")


if __name__ == "__main__":
    main()
