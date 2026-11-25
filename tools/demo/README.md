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

## Other website images

The other images on the website are still WebP files. macOS can't encode WebP itself, so they go through
a browser: copy `encode.html` and `server.py` next to the PNG files, run `python3 server.py 8766` there and
open http://localhost:8766/encode.html. In the browser console, run for example:

```js
await encodeAll([["keyboard.png", "keyboard.webp", 0.9]]);
```

The server saves the results into `out/`.
