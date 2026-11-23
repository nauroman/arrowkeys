#!/bin/bash
set -euo pipefail
source_dir=$1
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT
cd "$test_dir"
export XDG_CONFIG_HOME="$test_dir/profile"
launcher="$source_dir/Enable ArrowKeys.command"
"$launcher" --configure-only
config="$XDG_CONFIG_HOME/karabiner/karabiner.json"
cp "$config" first.json
"$launcher" --configure-only
cmp first.json "$config"
echo '{"profiles":[{"name":"Work","selected":true,"complex_modifications":{"rules":[{"description":"Existing","manipulators":[]}]}},{"name":"Other"}],"global":{"check_for_updates_on_startup":false}}' > "$config"
cp "$config" before.json
"$launcher" --configure-only
cmp before.json "$XDG_CONFIG_HOME"/karabiner/karabiner.before-arrowkeys.*
python3 - "$config" <<'PY'
import json, sys
from pathlib import Path
original = json.loads(Path("before.json").read_text())
config = json.loads(Path(sys.argv[1]).read_text())
rule = config["profiles"][0]["complex_modifications"]["rules"].pop(0)
assert len(rule["manipulators"]) == 9 and config == original
PY
echo '{ /* existing JSONC */ "profiles": [] }' > "$config"
cp "$config" before.json
"$launcher" --configure-only | grep 'Add predefined rule'
cmp before.json "$config"
