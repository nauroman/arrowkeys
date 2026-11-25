# Joins still WebP frames into one animated WebP, following the WebP container specification
# (https://developers.google.com/speed/webp/docs/riff_container). Each frame comes from frames.json:
# its file, the rectangle it covers on the canvas and how long it stays, in milliseconds.
# Usage: python3 tools/demo/animate.py <folder with frames.json and frame-NN.webp> <output.webp>
import json, os, struct, sys


def chunks(data):
    """Yield (fourcc, payload) for each chunk of a still WebP file."""
    assert data[:4] == b"RIFF" and data[8:12] == b"WEBP", "not a WebP file"
    i = 12
    while i + 8 <= len(data):
        fourcc, size = data[i:i + 4], struct.unpack("<I", data[i + 4:i + 8])[0]
        yield fourcc, data[i + 8:i + 8 + size]
        i += 8 + size + (size & 1)


def chunk(fourcc, payload):
    return fourcc + struct.pack("<I", len(payload)) + payload + (b"\0" if len(payload) & 1 else b"")


def u24(value):
    assert 0 <= value < 1 << 24
    return struct.pack("<I", value)[:3]


def main(folder, output):
    manifest = json.load(open(os.path.join(folder, "frames.json")))
    frames, has_alpha = [], False
    for frame in manifest["frames"]:
        name = os.path.splitext(frame["file"])[0] + ".webp"
        image = [chunk(c, p) for c, p in chunks(open(os.path.join(folder, name), "rb").read()) if c in (b"ALPH", b"VP8 ", b"VP8L")]
        has_alpha = has_alpha or any(part.startswith(b"ALPH") for part in image)
        assert frame["x"] % 2 == 0 and frame["y"] % 2 == 0, "frame offsets must be even"
        header = u24(frame["x"] // 2) + u24(frame["y"] // 2) + u24(frame["width"] - 1) + u24(frame["height"] - 1)
        # Flags: do not blend with the previous canvas, and keep it when the next frame arrives.
        header += u24(frame["duration"]) + bytes([0b10])
        frames.append(chunk(b"ANMF", header + b"".join(image)))
    flags = 0b10 | (0b10000 if has_alpha else 0)
    vp8x = chunk(b"VP8X", bytes([flags, 0, 0, 0]) + u24(manifest["width"] - 1) + u24(manifest["height"] - 1))
    anim = chunk(b"ANIM", bytes([0, 0, 0, 255]) + struct.pack("<H", 0))  # opaque black background, loop forever
    body = b"WEBP" + vp8x + anim + b"".join(frames)
    with open(output, "wb") as f:
        f.write(b"RIFF" + struct.pack("<I", len(body)) + body)
    print(output, os.path.getsize(output), "bytes,", len(frames), "frames")


if __name__ == "__main__":
    main(*sys.argv[1:3])
