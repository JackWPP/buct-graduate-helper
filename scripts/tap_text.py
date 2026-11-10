#!/usr/bin/env python3
"""Print the center of a uiautomator node matching text or content-desc.

Reads the XML hierarchy from stdin:
    adb exec-out cat /sdcard/window.xml | python3 scripts/tap_text.py 课表
    adb exec-out cat /sdcard/window.xml | python3 scripts/tap_text.py --bottom 课表

Flutter exposes labels through content-desc rather than text, so both
attributes are checked. With --bottom the lowest matching node wins, which is
what bottom navigation tabs need when the same word also appears in content.
"""

import re
import sys
import xml.etree.ElementTree as ET


def main() -> int:
    args = sys.argv[1:]
    bottom = False
    if args and args[0] == "--bottom":
        bottom = True
        args = args[1:]
    if len(args) != 1:
        print("usage: tap_text.py [--bottom] <text>", file=sys.stderr)
        return 2

    needle = args[0]
    try:
        root = ET.fromstring(sys.stdin.read())
    except ET.ParseError:
        print("could not parse uiautomator dump", file=sys.stderr)
        return 1

    matches: list[tuple[int, int]] = []
    for node in root.iter("node"):
        label = f"{node.get('text') or ''} {node.get('content-desc') or ''}"
        if needle not in label:
            continue
        match = re.match(r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]", node.get("bounds") or "")
        if not match:
            continue
        x1, y1, x2, y2 = map(int, match.groups())
        matches.append(((x1 + x2) // 2, (y1 + y2) // 2))
        if not bottom:
            break

    if not matches:
        print(f"text not found: {needle}", file=sys.stderr)
        return 1
    if bottom:
        matches.sort(key=lambda point: point[1])
    print(*matches[-1] if bottom else matches[0])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
