"""Export Windows shell and listing sizes from the selected transparent artwork."""

from pathlib import Path
import sys

from PIL import Image, ImageOps


def export_icons(source: Path, assets: Path, output: Path) -> None:
    assets.mkdir(parents=True, exist_ok=True)
    with Image.open(source) as source_image:
        rgba = source_image.convert("RGBA")
    side = max(rgba.size)
    master = Image.new("RGBA", (side, side))
    master.alpha_composite(rgba, ((side - rgba.width) // 2, (side - rgba.height) // 2))
    master.save(output / "ArrowKeys.ico", sizes=[(n, n) for n in (16, 20, 24, 32, 40, 48, 64, 128, 256)])
    for name, size in (("StoreLogo", 50), ("Square44x44Logo", 44), ("Square150x150Logo", 150)):
        for scale in (100, 125, 150, 200, 400):
            pixels = int(size * scale / 100 + 0.5)
            filename = f"{name}.png" if scale == 100 else f"{name}.scale-{scale}.png"
            master.resize((pixels, pixels), Image.Resampling.LANCZOS).save(assets / filename)
    for size in (16, 20, 24, 32, 48, 64, 256):
        icon = master.resize((size, size), Image.Resampling.LANCZOS)
        icon.save(assets / f"Square44x44Logo.targetsize-{size}_altform-unplated.png")
    ImageOps.contain(master, (300, 300), Image.Resampling.LANCZOS).save(output / "StoreLogo300.png")


if __name__ == "__main__":
    export_icons(*(Path(value) for value in sys.argv[1:]))
