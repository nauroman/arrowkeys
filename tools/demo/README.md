# Demo animations

## README animation (from the website)

The README shows `docs/images/readme-demo-light.webp`, or `readme-demo-dark.webp` in GitHub's dark theme.
Both are captured from the live keyboard demo on the website, so they always match it. Rebuild them after
changing the demo in `docs/index.html`:

```sh
python3 tools/demo/capture-site.py
```

It needs Google Chrome (or set `CHROME` to another Chromium browser). Each frame is the demo's state
after the first steps of its tour, captured on GitHub's page colour, encoded to WebP by Chrome and joined
by `animate.py`. If you change the tour in `docs/index.html`, change `TOUR` in the script too.

## Drawn animation

`docs/images/demo.webp` is the earlier drawn animation; the README no longer uses it. macOS can't encode
WebP itself, so the frames go through a browser.

1. Render the frames:

   ```sh
   swift tools/demo/make-demo.swift /tmp/demo-frames
   ```

   This writes `frame-NN.png` and `frames.json`. The first frame is the whole picture, and each later frame is only the rectangle that changed.

2. Encode every frame to WebP in a browser. Copy `encode.html` and `server.py` next to the frames folder, then run `python3 server.py 8766` there and open http://localhost:8766/encode.html. In the browser console, run:

   ```js
   const m = await (await fetch("frames/frames.json")).json();
   await encodeAll(m.frames.map(f => ["frames/" + f.file, f.file.replace(".png", ".webp"), 0.9]));
   ```

   The server saves the results into `out/`. Copy `frames.json` into `out/` as well.

3. Join the frames into one animated WebP:

   ```sh
   python3 tools/demo/animate.py out docs/images/demo.webp
   ```

The other images on the website are still WebP files made with the same `encode()` function at quality 0.9.
