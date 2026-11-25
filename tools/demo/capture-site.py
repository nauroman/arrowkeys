# Captures the website's live keyboard demo as two animated WebP files for the README, one for GitHub's
# light theme and one for its dark theme: docs/images/readme-demo-light.webp and readme-demo-dark.webp.
# Each frame is the state of the demo after the first n steps of its tour, so the result does not depend
# on timing. Needs Google Chrome (set CHROME to use another Chromium browser).
# Usage: python3 tools/demo/capture-site.py
import base64, functools, http.server, json, os, re, shutil, subprocess, sys, tempfile, threading

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
CHROME = os.environ.get("CHROME", "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome")
TOUR = ["i", "j", "j", "j", "j", "l", "l", "k", "j", "j", "l"]  # the tour in docs/index.html
# (steps done, last key lit, milliseconds on screen)
FRAMES = [(0, False, 900)] + [(n, lit, 300 if lit else 650) for n in range(1, len(TOUR) + 1) for lit in (True, False)]
THEMES = {"light": ("1", "#ffffff"), "dark": ("0", "#0d1117")}  # Chrome's preferredColorScheme, GitHub's page colour

CSS = """
  /* README capture: only the live keyboard demo, crisp states, GitHub's page colour behind it. */
  header, .skip, .hero-copy, main > *:not(.hero), footer, .device-bar, #hint-body { display: none !important; }
  .hero .wrap { display: block !important; padding: 20px !important; max-width: none !important; }
  *, *::before, *::after { animation: none !important; transition: none !important; }
  body, .band.hero { background: var(--capture-bg) !important; }
"""
DRIVER = """<script>
  (function () {
    var q = new URLSearchParams(location.search), n = +(q.get("n") || 0), lit = q.get("lit") === "1";
    document.documentElement.style.setProperty("--capture-bg", q.get("bg"));
    var tour = %s, codes = { i: "KeyI", j: "KeyJ", k: "KeyK", l: "KeyL" };
    document.fonts.ready.then(function () {
      for (var s = 0; s < n; s++) document.dispatchEvent(new KeyboardEvent("keydown", { code: codes[tour[s]], key: tour[s], altKey: true, bubbles: true, cancelable: true }));
      setTimeout(function () {
        document.querySelectorAll(".pad .on").forEach(function (e) { e.classList.remove("on"); });
        if (lit && n > 0) {
          document.getElementById("caps-key").classList.add("on");
          document.querySelector('.pad [data-k="' + tour[n - 1] + '"]').classList.add("on");
        }
      }, 800);
    });
  })();
</script>
</body>""" % json.dumps(TOUR)
ENCODE = """<!doctype html><meta charset="utf-8"><body>working</body><script>
  const names = %s, out = {}; let left = names.length;
  for (const name of names) {
    const img = new Image();
    img.onload = () => {
      const c = document.createElement("canvas"); c.width = img.naturalWidth; c.height = img.naturalHeight;
      c.getContext("2d").drawImage(img, 0, 0); out[name] = c.toDataURL("image/webp", 0.9);
      if (--left === 0) document.body.textContent = "JSON:" + JSON.stringify(out);
    };
    img.src = name + ".png";
  }
</script>"""


class QuietHandler(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *args):
        pass


def chrome(profile, *args):
    subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars", "--user-data-dir=" + profile, *args],
                   check=True, capture_output=True)


def main():
    tmp = tempfile.mkdtemp(prefix="arrowkeys-demo-")
    try:
        site = os.path.join(tmp, "site")
        shutil.copytree(os.path.join(ROOT, "docs"), site)
        page = open(os.path.join(site, "index.html"), encoding="utf-8").read()
        page = page.replace("</style>", CSS + "</style>", 1).replace("</body>", DRIVER, 1)
        open(os.path.join(site, "index.html"), "w", encoding="utf-8").write(page)
        server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), functools.partial(QuietHandler, directory=site))
        threading.Thread(target=server.serve_forever, daemon=True).start()
        base = "http://127.0.0.1:%d/" % server.server_address[1]
        sys.path.insert(0, HERE)
        import animate

        for theme, (scheme, bg) in THEMES.items():
            names = []
            for i, (n, lit, _) in enumerate(FRAMES, 1):
                name = "%s-%02d" % (theme, i)
                chrome(os.path.join(tmp, "profile-" + name), "--window-size=720,336", "--force-device-scale-factor=2",
                       "--blink-settings=preferredColorScheme=" + scheme, "--force-prefers-reduced-motion",
                       "--virtual-time-budget=4000", "--screenshot=" + os.path.join(site, name + ".png"),
                       base + "?n=%d&lit=%d&bg=%s" % (n, lit, bg.replace("#", "%23")))
                names.append(name)
            open(os.path.join(site, "encode.html"), "w").write(ENCODE % json.dumps(names))
            dom = subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--user-data-dir=" + os.path.join(tmp, "profile-encode-" + theme),
                                  "--virtual-time-budget=30000", "--dump-dom", base + "encode.html"], check=True, capture_output=True, text=True).stdout
            encoded = json.loads(re.search(r"JSON:(\{.*?\})</body>", dom, re.S).group(1))
            folder = os.path.join(tmp, theme)
            os.makedirs(folder)
            png = open(os.path.join(site, names[0] + ".png"), "rb").read(24)
            width, height = int.from_bytes(png[16:20], "big"), int.from_bytes(png[20:24], "big")
            manifest = {"width": width, "height": height, "frames": []}
            for name, (_, _, ms) in zip(names, FRAMES):
                open(os.path.join(folder, name + ".webp"), "wb").write(base64.b64decode(encoded[name].split(",", 1)[1]))
                manifest["frames"].append({"file": name + ".png", "x": 0, "y": 0, "width": width, "height": height, "duration": ms})
            json.dump(manifest, open(os.path.join(folder, "frames.json"), "w"))
            animate.main(folder, os.path.join(ROOT, "docs", "images", "readme-demo-%s.webp" % theme))
        server.shutdown()
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


if __name__ == "__main__":
    main()
