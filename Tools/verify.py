#!/usr/bin/env python3
#
#  verify.py
#  Loot Wars
#
#  The sweep that runs before every commit.
#
#  There is no Swift toolchain on the machine these edits are made on, so nothing
#  here type-checks - Xcode is the first thing that ever tries to compile. That
#  makes this file the only line of defence against a class of mistake that is
#  invisible to every other kind of review: an edit that leaves the file looking
#  entirely reasonable and the program unbuildable.
#
#  Everything checked here was added the day it was needed. Nothing is speculative.
#
#  Usage:
#      python3 Tools/verify.py [--removed name,name,...]
#
#  --removed names declarations that were deleted ON PURPOSE by the change being
#  committed. Naming them is the point: see the lost-declarations check below.
#
import re, sys, subprocess, pathlib, collections, argparse

root = pathlib.Path("LOOT WARS 2D Shared")
bad = 0

parser = argparse.ArgumentParser()
parser.add_argument("--removed", default="")
removed = {n.strip() for n in parser.parse_args().removed.split(",") if n.strip()}
seen_removed = set()


def strip(t):
    """Source with string literals and comments blanked, so a brace inside either
    cannot throw the counts off."""
    t = re.sub(r'"(?:\\.|[^"\\])*"', '""', t)
    t = re.sub(r'//[^\n]*', '', t)
    return re.sub(r'/\*.*?\*/', '', t, flags=re.S)


# Every name a file promises to the rest of the program.
DECL = re.compile(r'\b(?:func|var|let|case|enum|struct|class|protocol|typealias)\s+(\w+)')

def declared(text):
    return collections.Counter(DECL.findall(strip(text)))


tracked = subprocess.run(["git", "ls-files", "-z"], capture_output=True, text=True).stdout.split("\0")
tracked = {f for f in tracked if f.endswith(".swift")}

for f in sorted(root.rglob("*.swift")):
    text = f.read_text()
    st = strip(text)

    for o, c, n in (('{', '}', 'brace'), ('(', ')', 'paren'), ('[', ']', 'bracket')):
        if st.count(o) != st.count(c):
            print(f"UNBALANCED {n}: {f} ({st.count(o)}/{st.count(c)})")
            bad = 1

    # Core knows nothing about how it is drawn. The whole architecture rests on
    # this one line staying true.
    if f.parts[1] == "Core" and "SpriteKit" in st:
        print(f"IMPURE: {f}")
        bad = 1

    key = str(f)
    if key not in tracked:
        continue
    old = subprocess.run(["git", "show", f"HEAD:{key}"], capture_output=True, text=True).stdout
    if not old:
        continue

    # SIZE SANITY. A brace check cannot see a file that has had a balanced block
    # spliced into it a million times - duplicated balanced text stays balanced -
    # so compare against what is committed. This is the check that would have
    # caught a 306MB AIBrain.swift.
    a, b = old.count("\n"), text.count("\n")
    if b > max(400, a * 3) or (a > 200 and b < a * 0.4):
        print(f"SIZE JUMP: {f} {a} -> {b} lines")
        bad = 1

    # LOST DECLARATIONS. The check machineStruck needed and did not get.
    #
    # Edits here are usually made by replacing a slice of a file between two
    # anchors. When the closing anchor is further down the file than intended, the
    # slice takes everything in between with it - and a function quietly deleted
    # this way trips NOTHING else in this file. Braces stay balanced, because a
    # whole function is balanced. The line count barely moves. Purity is untouched.
    # The first anyone hears of it is a call site failing to compile in Xcode.
    #
    # Deleting something on purpose is normal, so this is not a prohibition - it is
    # a requirement to SAY SO. Pass --removed with the names, having checked there
    # are no references left, and the run passes. What it refuses to do is let a
    # deletion through that nobody has looked at.
    was, now = declared(old), declared(text)
    for name in sorted(was):
        if was[name] > now.get(name, 0):
            if name in removed:
                seen_removed.add(name)
            else:
                print(f"LOST DECL: {f} '{name}' - intended? re-run with --removed {name}")
                bad = 1

    # A declaration repeated is the other tell of a bad splice.
    dupes = [n for n, c in collections.Counter(
        re.findall(r'\n    (?:private |static |final )*func (\w+)\(', text)).items() if c > 4]
    if dupes:
        print(f"REPEATED DECLS: {f} {dupes}")
        bad = 1

# An acknowledgement for something that did not actually go missing means the list
# is drifting out of date, which is how an allowlist stops being read.
for stale in sorted(removed - seen_removed):
    print(f"STALE --removed: '{stale}' is not missing from anything")
    bad = 1

print("FAIL" if bad else "all checks pass")
sys.exit(bad)
