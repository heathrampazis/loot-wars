# Core must not import SpriteKit, and must not name a type declared in Render/ or UI/.
import pathlib, re
# The code folder, found from this script, so the check works from anywhere.
# It used to be ".", which from the repo root found no Core folder at all and
# reported clean without checking anything.
root = pathlib.Path(__file__).resolve().parent.parent / "Loot Wars Shared"
assert (root/"Core").is_dir(), f"no Core folder under {root}"
render = {}
for folder in ("Render", "UI", "App"):
    for p in (root/folder).rglob("*.swift"):
        for m in re.finditer(r'\b(?:final class|class|struct|enum|protocol)\s+(\w+)', p.read_text()):
            name = m.group(1)
            # "class func newMenuScene()" is a method, not a type.
            if not name[:1].isupper(): continue
            render[name] = f"{folder}/{p.name}"

# A name Core declares for itself (Bomb.Kind, Shop.Tab) is Core's own, even if
# a type somewhere in Render/UI happens to share it.
core_types = set()
for p in (root/"Core").rglob("*.swift"):
    for m in re.finditer(r'\b(?:final class|class|struct|enum|protocol)\s+(\w+)', p.read_text()):
        core_types.add(m.group(1))
for name in core_types:
    render.pop(name, None)

bad = []
for p in (root/"Core").rglob("*.swift"):
    src = p.read_text()
    if re.search(r'^\s*import\s+(SpriteKit|UIKit)', src, re.M):
        bad.append(f"{p}: imports a rendering framework")
    code = "\n".join(l.split("//")[0] for l in src.split("\n"))
    for name, where in render.items():
        if re.search(rf'\b{name}\b', code):
            bad.append(f"{p}: names {name} (declared in {where})")

print("Core-purity check:", "clean" if not bad else "")
for b in bad: print("  ", b)
print(f"\ntypes found in Render/UI/App: {len(render)}")
