# Renders the website's Caps Lock + I J K L keycaps (the keypad of the live demo in docs/index.html) as still
# PNG images, so the README, the Windows guide and the Mac App Store screenshot show exactly the keys on the
# website. Then it rebuilds the Mac App Store screenshot from packaging/mac-app-store/screenshot.html.
# Needs Google Chrome (set CHROME to use another Chromium browser).
# Usage: python3 tools/demo/render-keycaps.py
import functools, http.server, os, shutil, subprocess, tempfile, threading

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
CHROME = os.environ.get("CHROME", "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome")
PAD_W, PAD_H = 252, 101  # the keypad in CSS pixels: 96 + 3 × 46 + 3 × 6 wide, 2 × 46 + 6 + 3 (key shadow) high

# (file, scale, background or None for transparent, margin around the keys in CSS pixels)
KEYCAPS = [
    ("docs/images/keycaps.png", 3, None, 8),              # README (on GitHub's light and dark themes), App Store screenshot
    ("packaging/store/keycaps.png", 2.5, "#faf9f6", 4),   # the Windows Store guide window, on its BackColor
]
SCREENSHOT = ("packaging/mac-app-store/screenshot.html", "packaging/mac-app-store/ArrowKeys-Mac-App-Store.png", 1440, 900)

# Only the demo keypad, at rest, in the site's dark theme (the keys are the same in both themes; the dark
# theme's brighter orange arrows are the ones the keycaps image uses).
CSS = """
  header, .skip, .hero-copy, main > *:not(.hero), footer, .device-bar, .doc, .readout { display: none !important; }
  body::before { display: none !important; }
  html, body, .band.hero, .device, .device-foot { background: var(--capture-bg) !important; }
  body { margin: 0 !important; }
  .hero .wrap { display: block !important; padding: 0 !important; max-width: none !important; }
  .device { border: 0 !important; }
  .device-foot { display: block !important; border: 0 !important; padding: var(--capture-margin) !important; }
  *, *::before, *::after { animation: none !important; transition: none !important; }
"""
DRIVER = """<script>
  var q = new URLSearchParams(location.search), root = document.documentElement;
  root.style.setProperty("--capture-bg", q.get("bg"));
  root.style.setProperty("--capture-margin", q.get("margin") + "px");
  root.dataset.theme = "dark";
</script>
</body>"""


class QuietHandler(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *args):
        pass


def chrome(profile, width, height, scale, out, url, transparent=False):
    args = [CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars", "--force-prefers-reduced-motion",
            "--user-data-dir=" + profile, "--window-size=%d,%d" % (width, height), "--force-device-scale-factor=%g" % scale,
            "--virtual-time-budget=3000", "--screenshot=" + out, url]
    if transparent:
        args.insert(1, "--default-background-color=00000000")
    subprocess.run(args, check=True, capture_output=True)


def main():
    tmp = tempfile.mkdtemp(prefix="arrowkeys-keycaps-")
    try:
        site = os.path.join(tmp, "site")
        shutil.copytree(os.path.join(ROOT, "docs"), site)
        page = open(os.path.join(site, "index.html"), encoding="utf-8").read()
        page = page.replace("</style>", CSS + "</style>", 1).replace("</body>", DRIVER, 1)
        open(os.path.join(site, "index.html"), "w", encoding="utf-8").write(page)
        server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), functools.partial(QuietHandler, directory=site))
        threading.Thread(target=server.serve_forever, daemon=True).start()
        base = "http://127.0.0.1:%d/" % server.server_address[1]

        for n, (name, scale, background, margin) in enumerate(KEYCAPS):
            bg = "transparent" if background is None else background.replace("#", "%23")
            chrome(os.path.join(tmp, "profile-%d" % n), PAD_W + 2 * margin, PAD_H + 2 * margin, scale,
                   os.path.join(ROOT, name), base + "?bg=%s&margin=%d" % (bg, margin), transparent=background is None)
            print(name)
        server.shutdown()

        page, out, width, height = SCREENSHOT
        chrome(os.path.join(tmp, "profile-screenshot"), width, height, 1, os.path.join(ROOT, out),
               "file://" + os.path.join(ROOT, page), )
        print(out)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


if __name__ == "__main__":
    main()
