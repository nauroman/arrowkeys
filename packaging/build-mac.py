"""Bundle the launcher and its two data files in one Finder-executable command."""
import json
import sys
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile, ZipInfo

mac = Path(__file__).resolve().parents[1] / "macos"
name = "Install ArrowKeys.command"
launcher = (mac / name).read_text(encoding="utf-8")
marker = "trap cleanup EXIT\n"
assert launcher.count(marker) == 1
resources = ['cd "$tempdir"']
json.loads((mac / "arrowkeys.json").read_text(encoding="utf-8"))
for filename in ("arrowkeys.json", "configure.js"):
    contents = (mac / filename).read_text(encoding="utf-8").rstrip("\n")
    assert "ARROWKEYS_RESOURCE" not in contents.splitlines()
    resources.extend([f"cat > {filename} <<'ARROWKEYS_RESOURCE'", contents, "ARROWKEYS_RESOURCE"])
launcher = launcher.replace(marker, marker + "\n".join(resources) + "\n")
output = Path(sys.argv[1])
output.parent.mkdir(parents=True, exist_ok=True)
with ZipFile(output, "w") as archive:
    entry = ZipInfo(name)
    entry.create_system = 3
    entry.external_attr = 0o100755 << 16
    archive.writestr(entry, launcher.encode("utf-8"), compress_type=ZIP_DEFLATED)
