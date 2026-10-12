#!/usr/bin/env python3
"""Sketch-against-app scan: pairs each registered view's rendered app picture
with the sketch frames the register names for it, scores the pair and writes
a side-by-side image with a difference map.

Inputs (all produced beforehand):
  <sketch_dir>  tools/sketch_render.mjs        (<key>.png + report.json)
  <shots_dir>   test/views/design_states/app_shots_test.dart  (*_light|dark.png)
Usage: python3 tools/sketch_scan.py <sketch_dir> <shots_dir> <out_dir>

The scores rank pairs; they do not judge them. Text, photos and sample data
always differ between a sketch and the app, so the three numbers are
colour mood (palette overlap), vertical rhythm (where ink sits down the page)
and block layout (coarse grey-level difference). Read the picture before
trusting a number.
"""
import json
import re
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

SKETCH, SHOTS, OUT = (Path(a) for a in sys.argv[1:4])
OUT.mkdir(parents=True, exist_ok=True)
ROOT = Path(__file__).resolve().parent.parent

register = json.loads((ROOT / "design/screen-register.json").read_text())["views"]
report = json.loads((SKETCH / "report.json").read_text())
theme_of = {r["key"]: r["theme"] for r in report["rendered"]}
rows = json.loads((ROOT / "test/fixtures/design/ux-beteende-53.json").read_text())["rows"]

ALIASES = {
    "host_minaRecept": "lib/views/mina_recept_view.dart",
    "host_more": "lib/views/more/more_view.dart",
    "host_pantry": "lib/views/pantry/pantry_view.dart",
    "host_syncQueue": "lib/views/sync/sync_queue_view.dart",
}
shot_of_file = {}
for stem, f in ALIASES.items():
    shot_of_file.setdefault(f, []).append(stem)
for r in rows:
    if r["TILLSTAND"] == "DEFAULT":
        slug = re.sub(r"[^a-z0-9åäö]+", "_", r["VY"].lower()).strip("_")
        shot_of_file.setdefault(r["HOST_FILE"], []).append("row_" + slug)
for f in register:
    p = ROOT / f
    if not p.exists():
        continue
    for cls in re.findall(r"^(?:abstract\s+)?class\s+(\w+)", p.read_text(), re.M):
        stem = "host_" + re.sub(r"[^a-z0-9åäö]+", "_", cls.lower()).strip("_")
        if (SHOTS / f"{stem}_light.png").exists():
            shot_of_file.setdefault(f, []).append(stem)

W = 360


def load_sketch(key):
    im = Image.open(SKETCH / (key.replace("#", "_") + ".png")).convert("RGB")
    if not 300 <= im.width <= 460:
        return None
    im = im.crop((0, 40, im.width, im.height))  # status bar is the OS's
    return im.resize((W, round(im.height * W / im.width)), Image.LANCZOS)


def load_app(path):
    im = Image.open(path).convert("RGB")
    return im.resize((W, round(im.height * W / im.width)), Image.LANCZOS)


def bg_of(a):
    flat = (a // 8).reshape(-1, 3)
    vals, counts = np.unique(flat, axis=0, return_counts=True)
    return vals[counts.argmax()] * 8


def palette(a):
    q = (a // 32).reshape(-1, 3)
    idx = q[:, 0] * 64 + q[:, 1] * 8 + q[:, 2]
    h = np.bincount(idx, minlength=512).astype(float)
    return h / h.sum()


def rhythm(a, n=60):
    bg = bg_of(a)
    ink = (np.abs(a.astype(int) - bg).sum(axis=2) > 60).mean(axis=1)
    xs = np.linspace(0, len(ink), n + 1).astype(int)
    return np.array([ink[xs[i] : max(xs[i + 1], xs[i] + 1)].mean() for i in range(n)])


def blocks(a, bw=36, bh=80):
    g = np.asarray(Image.fromarray(a).convert("L").resize((bw, bh), Image.BILINEAR), float) / 255
    return g


def score(sk, ap):
    a, b = np.asarray(sk), np.asarray(ap)
    pal = np.minimum(palette(a), palette(b)).sum()
    ra, rb = rhythm(a), rhythm(b)
    cor = 0.0 if ra.std() < 1e-6 or rb.std() < 1e-6 else float(np.corrcoef(ra, rb)[0, 1])
    rhy = max(0.0, cor)
    lay = 1 - float(np.abs(blocks(a) - blocks(b)).mean()) * 2.5
    lay = max(0.0, lay)
    return round(pal * 100), round(rhy * 100), round(lay * 100)


def panel(sk, ap, label):
    h = max(sk.height, ap.height)
    def pad(im):
        c = Image.new("RGB", (W, h), (255, 255, 255))
        c.paste(im, (0, 0))
        return c

    s, a = pad(sk), pad(ap)
    d = np.abs(np.asarray(s, int) - np.asarray(a, int)).sum(axis=2)
    heat = np.clip(d * 2, 0, 255).astype(np.uint8)
    diff = Image.fromarray(np.stack([255 - heat, 255 - heat // 2, 255 - heat], axis=2))
    out = Image.new("RGB", (W * 2 + 20, h + 30), (255, 255, 255))
    for i, im in enumerate((s, a)):
        out.paste(im, (i * (W + 20), 30))
    ImageDraw.Draw(out).text((4, 8), f"{label}     skiss | app", fill=(0, 0, 0))
    return out, diff


results = []
skipped = []
for f, v in sorted(register.items()):
    stems = list(dict.fromkeys(shot_of_file.get(f, [])))
    if not stems:
        skipped.append({"view": f, "status": v["status"], "why": "ingen app-bild (värd saknas)"})
        continue
    for stem in stems:
        for mode in ("light", "dark"):
            shot = SHOTS / f"{stem}_{mode}.png"
            if not shot.exists():
                continue
            ap = load_app(shot)
            cands = []
            for key in v["frames"]:
                if theme_of.get(key, "light") != mode:
                    continue
                sk = load_sketch(key)
                if sk is None:
                    continue
                cands.append((key, sk, score(sk, ap)))
            if not cands:
                skipped.append({"view": f, "status": v["status"], "why": f"ingen telefonram i {mode}"})
                continue
            key, sk, (pal, rhy, lay) = max(cands, key=lambda c: sum(c[2]))
            name = f"{Path(f).stem}__{stem}__{mode}.png"
            pair, diff = panel(sk, ap, f"{Path(f).name} · {key} · {mode}")
            pair.save(OUT / name)
            diff.save(OUT / name.replace(".png", "__diff.png"))
            results.append(
                {
                    "view": f,
                    "register_status": v["status"],
                    "host": stem,
                    "mode": mode,
                    "frame": key,
                    "frames_tried": len(cands),
                    "palette": pal,
                    "rhythm": rhy,
                    "layout": lay,
                    "score": round((pal + rhy + lay) / 3),
                    "image": name,
                }
            )
results.sort(key=lambda r: r["score"])
(OUT / "scan.json").write_text(json.dumps({"results": results, "skipped": skipped}, ensure_ascii=False, indent=1))
print(f"pairs {len(results)}, views without a pair {len({s['view'] for s in skipped})}")
