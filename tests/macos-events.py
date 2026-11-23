"""Run from an empty directory. Pass Karabiner 16.3.0's overwrite_expected_results binary."""
import json
import subprocess
import sys
from pathlib import Path


def write(path, value):
    Path(path).write_text(json.dumps(value))


prefix = Path("json/manipulator_manager")
prefix.mkdir(parents=True)
asset = Path(__file__).resolve().parents[1] / "macos" / "arrowkeys.json"
write("rules.json", json.loads(asset.read_text())["rules"][0]["manipulators"])
cases = []
expected = []


def chord(keys, output, modifiers, reverse=False):
    number = len(cases)
    events = []
    for kind, sequence in (("key_down", keys), ("key_up", keys if reverse else keys[::-1])):
        for key in sequence:
            event = {"type": "momentary_switch_event", "momentary_switch_event": {"key_code": key}}
            events.append({"device_id": 1, "event": event, "original_event": event, "event_type": kind,
                           "event_time_stamp": {"time_stamp": 100 * (1 + len(events))}})
    write(f"in{number}.json", events)
    cases.append({"description": "+".join(keys), "rules": ["rules.json"],
                  "input_event_queue": f"in{number}.json", "expected_event_queue": f"out{number}.json"})
    expected.append((output, set(modifiers)))


for layer in ("caps_lock", "left_option", "right_option"):
    for letter, direction, mods in [
        ("j", "left", []), ("k", "down", []), ("l", "right", []), ("i", "up", []),
        ("u", "left", ["left_command"]), ("o", "right", ["left_command"]),
        ("h", "left", ["left_option"]), ("semicolon", "right", ["left_option"]),
    ]:
        for reverse in (False, True):
            chord([layer, letter], direction + "_arrow", mods, reverse)
chord(["caps_lock"], None, [])
chord(["caps_lock", "a"], "a", ["left_option"])
for letter in ("j", "k", "l", "i", "u", "o", "h", "semicolon"):
    chord([letter], letter, [])
for extra in ("left_shift", "left_control", "left_command"):
    chord([extra, "caps_lock", "j"], "j", [extra, "left_option"])

write(prefix / "tests.json", cases)
subprocess.run([sys.argv[1]], check=True)
for index, (key, modifiers) in enumerate(expected):
    held = set()
    downs = []
    ups = []
    option_presses = 0
    for event in json.loads(Path(f"out{index}.json").read_text()):
        code = event["event"]["momentary_switch_event"]["key_code"]
        assert code != "caps_lock", cases[index]
        down = event["event_type"] == "key_down"
        if down and code == "left_option":
            option_presses += 1
        is_modifier = code in ("left_option", "right_option", "left_command", "left_shift", "left_control")
        if down:
            if not is_modifier:
                downs.append((code, held.copy()))
            held.add(code)
        else:
            if not is_modifier:
                ups.append(code)
            held.discard(code)
    assert not held, (cases[index], held)
    assert downs == ([(key, modifiers)] if key else []), (cases[index], downs)
    assert ups == ([key] if key else []), (cases[index], ups)
    if key is None:
        assert option_presses == 1, cases[index]
print(f"Passed {len(cases)} Karabiner event sequences.")
