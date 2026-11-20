#!/usr/bin/env python3
"""校验仓库内所有 .jsonc / .json 是否结构合法（容忍 // 注释、/* */ 注释与尾逗号）。

四层配置里既有 fastfetch 的 JSONC（带注释），也有 VS Code 的纯 JSON；
这个脚本用一个小状态机剥掉注释后再交给标准 json，既能发现真错误，也不会误报。

用法：
    python3 tests/validate-configs.py          # 扫整个仓库
    python3 tests/validate-configs.py 01-fastfetch 03-vscode
退出码：0 全部通过；1 有文件解析失败。
"""

from __future__ import annotations

import json
import pathlib
import re
import sys

SKIP_DIRS = {".git", ".testhome", "node_modules"}


def strip_jsonc(text: str) -> str:
    """去掉注释与尾逗号，字符串内容原样保留。"""
    out: list[str] = []
    i, n = 0, len(text)
    in_str = False
    esc = False

    while i < n:
        ch = text[i]

        if in_str:
            out.append(ch)
            if esc:
                esc = False
            elif ch == "\\":
                esc = True
            elif ch == '"':
                in_str = False
            i += 1
            continue

        if ch == '"':
            in_str = True
            out.append(ch)
            i += 1
            continue

        if ch == "/" and i + 1 < n and text[i + 1] == "/":
            while i < n and text[i] != "\n":
                i += 1
            continue

        if ch == "/" and i + 1 < n and text[i + 1] == "*":
            i += 2
            while i + 1 < n and not (text[i] == "*" and text[i + 1] == "/"):
                i += 1
            i += 2
            continue

        out.append(ch)
        i += 1

    return re.sub(r",(\s*[}\]])", r"\1", "".join(out))


def collect(targets: list[pathlib.Path]) -> list[pathlib.Path]:
    files: list[pathlib.Path] = []
    for target in targets:
        if target.is_file():
            files.append(target)
            continue
        if not target.is_dir():
            print(f"路径不存在: {target}", file=sys.stderr)
            continue
        for pattern in ("*.jsonc", "*.json"):
            for path in sorted(target.rglob(pattern)):
                if any(part in SKIP_DIRS for part in path.parts):
                    continue
                files.append(path)
    return sorted(set(files))


def main() -> int:
    if len(sys.argv) > 1:
        targets = [pathlib.Path(arg) for arg in sys.argv[1:]]
    else:
        targets = [pathlib.Path(__file__).resolve().parent.parent]

    files = collect(targets)
    if not files:
        print("没有找到 .jsonc / .json 文件", file=sys.stderr)
        return 1

    failed = 0
    for path in files:
        try:
            data = json.loads(strip_jsonc(path.read_text(encoding="utf-8")))
        except json.JSONDecodeError as exc:
            failed += 1
            print(f"✗ {path}: 第 {exc.lineno} 行第 {exc.colno} 列: {exc.msg}")
            continue

        hint = []
        if isinstance(data, dict):
            if "modules" in data:
                hint.append(f"{len(data['modules'])} 个模块")
            if "logo" in data:
                logo_type = data["logo"].get("type", "?") if isinstance(data["logo"], dict) else "?"
                hint.append(f"logo.type={logo_type}")
        suffix = f"  ({', '.join(hint)})" if hint else ""
        print(f"✓ {path}{suffix}")

    print(f"\n{len(files) - failed}/{len(files)} 通过")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
