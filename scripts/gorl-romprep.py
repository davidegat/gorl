#!/usr/bin/env python3
"""GORL ROM preparation tool.

- Renames supported ROM files to safe DOS 8.3 filenames.
- Preserves titles already present in gametitles.txt.
- Asks only for ROMs that do not yet have a title.
- Rebuilds gametitles.txt from the ROMs currently present, removing stale entries.
"""

from __future__ import annotations

import os
import re
from pathlib import Path

EXTENSIONS = {".rom", ".scc", ".a8", ".a16", ".d2r"}
OUTPUT_NAME = "gametitles.txt"
RESERVED_DOS_NAMES = {
    "CON", "PRN", "AUX", "NUL",
    *(f"COM{i}" for i in range(1, 10)),
    *(f"LPT{i}" for i in range(1, 10)),
}


def is_rom(path: Path) -> bool:
    return path.is_file() and path.suffix.lower() in EXTENSIONS


def dos_stem(name: str) -> str:
    stem = re.sub(r"[^A-Z0-9_-]", "_", name.upper())
    stem = stem[:8] or "GAME"
    if stem in RESERVED_DOS_NAMES:
        stem = ("_" + stem)[:8]
    return stem


def read_titles(path: Path) -> dict[str, str]:
    titles: dict[str, str] = {}
    if not path.exists():
        return titles

    for raw in path.read_text(encoding="ascii", errors="replace").splitlines():
        line = raw.strip()
        if not line:
            continue
        parts = line.split(maxsplit=1)
        if len(parts) != 2:
            continue
        filename, title = parts
        title = title.strip()
        if title:
            titles[filename.casefold()] = title
    return titles


def ascii_title(text: str) -> str:
    text = " ".join(text.strip().split())
    return text.encode("ascii", errors="replace").decode("ascii")


def choose_unique(stem: str, ext: str, occupied: set[str]) -> str:
    candidate = f"{stem}.{ext}"
    if candidate.casefold() not in occupied:
        return candidate

    for n in range(1, 1000):
        suffix = f"_{n}"
        keep = max(1, 8 - len(suffix))
        candidate = f"{stem[:keep]}{suffix}.{ext}"
        if candidate.casefold() not in occupied:
            return candidate

    raise RuntimeError(f"Cannot create a unique DOS filename for {stem}.{ext}")


def rename_case_safely(source: Path, target: Path) -> None:
    if source.name == target.name:
        return

    # A temporary hop also handles case-only renames on case-insensitive filesystems.
    if source.name.casefold() == target.name.casefold():
        i = 0
        while True:
            temp = source.with_name(f".__GORLTMP_{os.getpid()}_{i}__")
            if not temp.exists():
                break
            i += 1
        source.rename(temp)
        temp.rename(target)
    else:
        source.rename(target)


def main() -> int:
    folder = Path.cwd()
    output = folder / OUTPUT_NAME
    old_titles = read_titles(output)

    snapshot = sorted(
        (p for p in folder.iterdir() if p.is_file()),
        key=lambda p: p.name.casefold(),
    )
    roms = [p for p in snapshot if is_rom(p)]

    # No ROMs left: gametitles.txt must not keep stale entries.
    if not roms:
        output.write_text("", encoding="ascii")
        print("No ROM files found.")
        print(f"Updated: {output}")
        print(f"Removed stale title entries: {len(old_titles)}")
        return 0

    occupied = {p.name.casefold() for p in snapshot}
    carried_titles: dict[str, str] = {}
    carried_sources: dict[str, str] = {}
    renamed = 0

    print("=== 1/3 - DOS 8.3 rename ===")
    for source in roms:
        occupied.discard(source.name.casefold())

        ext = source.suffix[1:].upper()
        target_name = choose_unique(dos_stem(source.stem), ext, occupied)
        target = folder / target_name

        # Preserve a title if the ROM already had one before this rename.
        source_key = source.name.casefold()
        target_key = target_name.casefold()
        title = old_titles.get(source_key)
        title_source = source_key if title is not None else None
        if title is None:
            title = old_titles.get(target_key)
            if title is not None:
                title_source = target_key
        if title:
            carried_titles[target_key] = title
            carried_sources[target_key] = title_source

        if source.name == target_name:
            print(f"[OK]     {source.name}")
        else:
            print(f"[RENAME] {source.name} -> {target_name}")
            rename_case_safely(source, target)
            renamed += 1

        occupied.add(target_name.casefold())

    print(f"\nRenamed files: {renamed}\n")
    print("=== 2/3 - Game titles ===")

    current_roms = sorted(
        (p for p in folder.iterdir() if is_rom(p)),
        key=lambda p: p.name.casefold(),
    )

    lines: list[str] = []
    kept = 0
    added = 0
    surviving_old_keys: set[str] = set()

    for rom in current_roms:
        key = rom.name.casefold()
        title = carried_titles.get(key)

        if title is not None:
            source_key = carried_sources.get(key)
            if source_key is not None:
                surviving_old_keys.add(source_key)
        elif key in old_titles:
            title = old_titles[key]
            surviving_old_keys.add(key)

        if title:
            kept += 1
            print(f"[KEEP]   {rom.name} -> {title}")
        else:
            print(f"\nROM: {rom.name}")
            try:
                entered = input(f"Full game title [Enter = {rom.stem}]: ")
            except EOFError:
                entered = ""
            title = entered.strip() or rom.stem
            added += 1

        title = ascii_title(title)
        if not title:
            title = rom.stem
        lines.append(f"{rom.name} {title}")

    print("\n=== 3/3 - gametitles.txt ===")
    temp = output.with_name(output.name + ".tmp")
    temp.write_text("\n".join(lines) + "\n", encoding="ascii", errors="replace", newline="\n")
    temp.replace(output)

    removed = len(set(old_titles) - surviving_old_keys)
    print(f"Updated: {output}")
    print(f"Existing titles kept: {kept}")
    print(f"New titles requested: {added}")
    print(f"Removed stale title entries: {removed}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
