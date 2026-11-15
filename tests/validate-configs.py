#!/usr/bin/env python3
"""校验 config/ 下所有 .jsonc 是否结构合法（容忍 // 注释、/* */ 注释与尾逗号）。

fastfetch 的配置是 JSONC，`jq` 之类的严格解析器会直接报错；
这个脚本用一个小状态机剥掉注释后再交给标准 json，既能发现真错误，也不会误报。

用法：python3 tests/validate-configs.py [目录，默认 config/]
退出码：0 全部通过；1 有文件解析失败。
"""

from __future__ import annotations

import json
import pathlib
import re
import sys


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

        # 行注释
        if ch == "/" and i + 1 < n and text[i + 1] == "/":
            while i < n and text[i] != "\n":
                i += 1
            continue

        # 块注释
        if ch == "/" and i + 1 < n and text[i + 1] == "*":
            i += 2
            while i + 1 < n and not (text[i] == "*" and text[i + 1] == "/"):
                i += 1
            i += 2
            continue

        out.append(ch)
        i += 1

    return re.sub(r",(\s*[}\]])", r"\1", "".join(out))


def main() -> int:
    target = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "config")
    if not target.is_dir():
        print(f"目录不存在: {target}", file=sys.stderr)
        return 1

    files = sorted(target.rglob("*.jsonc"))
    if not files:
        print(f"{target} 下没有 .jsonc 文件", file=sys.stderr)
        return 1

    failed = 0
    for path in files:
        try:
            data = json.loads(strip_jsonc(path.read_text(encoding="utf-8")))
        except json.JSONDecodeError as exc:
            failed += 1
            print(f"✗ {path}: 第 {exc.lineno} 行第 {exc.colno} 列: {exc.msg}")
            continue

        # 结构提示：logo / modules 是 fastfetch 配置的核心字段
        keys = set(data) if isinstance(data, dict) else set()
        hint = []
        if "modules" in keys:
            hint.append(f"{len(data['modules'])} 个模块")
        if "logo" in keys:
            logo_type = data["logo"].get("type", "?") if isinstance(data["logo"], dict) else "?"
            hint.append(f"logo.type={logo_type}")
        suffix = f"  ({', '.join(hint)})" if hint else ""
        print(f"✓ {path}{suffix}")

    print(f"\n{len(files) - failed}/{len(files)} 通过")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
