#!/usr/bin/env python3
"""
Boids Multi-File Generator (DOD + Quadtree)

Generates a boids simulation split into three single files:
  - index.html
  - style.css
  - app.js

Features:
- Data-oriented design using typed arrays (SoA for positions/velocities/etc.)
- Quadtree neighbor queries for performance + on-canvas visualization (enabled by default)
- URL params: hue (0–360), header, subheader
- Strong, juicy interactions: shockwaves on pointer events that push boids and bloom visuals
- Visuals: motion trails, additive blending, glow, speed tinting, shock rings

Usage:
  python3 agents/boids-multifile-generator.py
  python3 agents/boids-multifile-generator.py --out-dir runs/boids-demo
"""

import argparse
import os
from datetime import datetime


HTML = """<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Boids · Data-Oriented + Quadtree</title>
    <link rel="stylesheet" href="style.css" />
  </head>
  <body>
    <canvas id="scene"></canvas>
    <div class="overlay">
      <div class="title" id="title"></div>
      <div class="subtitle" id="subtitle"></div>
      <div class="hud" id="hud"></div>
    </div>
    <script src="app.js"></script>
  </body>
  </html>
"""


CSS = """
html, body { height: 100%; margin: 0; }
body {
  background: #05070a;
  color: #e6edf3;
  overflow: hidden;
  font-family: ui-sans-serif, system-ui, -apple-system, Segoe UI, Roboto, Helvetica, Arial, "Apple Color Emoji", "Segoe UI Emoji";
}

/* Fullscreen canvas */
#scene { display: block; width: 100vw; height: 100vh; }

.overlay {
  position: fixed;
  inset: 0;
  pointer-events: none;
  display: grid;
  grid-template-rows: auto 1fr auto;
}
.title {
  margin: 18px 20px 2px;
  font-weight: 700;
  font-size: clamp(18px, 3vw, 28px);
  letter-spacing: 0.2px;
  color: var(--accent, #7dd3fc);
  text-shadow: 0 0 10px color-mix(in oklab, var(--accent, #7dd3fc) 80%, #000 20%);
}
.subtitle {
  margin: 0 20px 10px;
  font-weight: 500;
  font-size: clamp(12px, 2vw, 16px);
  opacity: 0.85;
}
.hud {
  position: fixed;
  left: 12px;
  bottom: 12px;
  padding: 8px 10px;
  border-radius: 10px;
  border: 1px solid #00000040;
  background: #0b1220cc;
  backdrop-filter: blur(8px) saturate(120%);
  font-size: 12px;
  line-height: 1.4;
}
.hud strong { color: var(--accent, #7dd3fc); }
"""


JS = r"""
'use strict';

// URL parameters
const params = new URLSearchParams(location.search);
const BASE_HUE = clampInt(parseInt(params.get('hue')), 0, 360, Math.floor(Math.random()*360));
const HEADER = params.get('header') || 'Boids — Data-Oriented + Quadtree';
const SUBHEADER = params.get('subheader') || 'Shockwaves on click/drag · quadtree viz on';
const SHOW_QT = params.get('qt') !== '0'; // enabled by default

// DOM
const canvas = document.getElementById('scene');
const ctx = canvas.getContext('2d', { alpha: false });
const titleEl = document.getElementById('title');
const subtitleEl = document.getElementById('subtitle');
const hudEl = document.getElementById('hud');

// Style hook
document.documentElement.style.setProperty('--accent', `hsl(${BASE_HUE}, 85%, 62%)`);
titleEl.textContent = HEADER;
subtitleEl.textContent = SUBHEADER;

// Config
const CFG = Object.freeze({
  count: 280,
  vision: 84,
  sep: 18,
  maxSpeed: 3.2,
  maxForce: 0.06,
  alignW: 1.0,
  cohesionW: 0.76,
  separationW: 1.8,
  trailAlpha: 0.12, // motion trail strength
  qtCap: 8,         // quadtree capacity per node
});

// Canvas sizing with DPR
let DPR = Math.max(1, Math.min(2, window.devicePixelRatio || 1));
function resize() {
  DPR = Math.max(1, Math.min(2, window.devicePixelRatio || 1));
  canvas.width = Math.floor(innerWidth * DPR);
  canvas.height = Math.floor(innerHeight * DPR);
  ctx.setTransform(DPR, 0, 0, DPR, 0, 0);
  clearHard();
}
addEventListener('resize', resize);
resize();

function clearHard() {
  ctx.fillStyle = '#05070a';
  ctx.fillRect(0, 0, innerWidth, innerHeight);
}

function clampInt(n, lo, hi, fallback) {
  n = Number.isFinite(n) ? n : fallback;
  return Math.max(lo, Math.min(hi, n));
}

// Seeded PRNG for subtle determinism from BASE_HUE
let _seed = (BASE_HUE * 9301 + 49297) % 233280;
function rnd() { _seed = (1103515245 * _seed + 12345) & 0x7fffffff; return (_seed >>> 8) / 0x7fffff; }
function rand(min, max) { return rnd() * (max - min) + min; }

// Data-Oriented State (SoA)
const N = CFG.count;
const px = new Float32Array(N);
const py = new Float32Array(N);
const vx = new Float32Array(N);
const vy = new Float32Array(N);
const ax = new Float32Array(N);
const ay = new Float32Array(N);
const hue = new Float32Array(N);
const spd = new Float32Array(N);
const prevx = new Float32Array(N);
const prevy = new Float32Array(N);

for (let i = 0; i < N; i++) {
  px[i] = rand(0, innerWidth); py[i] = rand(0, innerHeight);
  vx[i] = rand(-1, 1); vy[i] = rand(-1, 1);
  const m = Math.hypot(vx[i], vy[i]) || 1; vx[i] *= 2.0/m; vy[i] *= 2.0/m;
  hue[i] = (BASE_HUE + rand(-30, 30)) % 360;
  prevx[i] = px[i]; prevy[i] = py[i];
}

// Quadtree implementation
class QTNode {
  constructor(x, y, w, h, cap) {
    this.x = x; this.y = y; this.w = w; this.h = h;
    this.cap = cap; this.count = 0; this.idx = new Int32Array(cap);
    this.ptsx = new Float32Array(cap); this.ptsy = new Float32Array(cap);
    this.divided = false; this.children = null;
  }
}

class Quadtree {
  constructor(x, y, w, h, cap) {
    this.root = new QTNode(x, y, w, h, cap);
    this.cap = cap;
  }

  insert(i, x, y, node = this.root) {
    if (x < node.x || y < node.y || x >= node.x + node.w || y >= node.y + node.h) return false;
    if (node.count < node.cap && !node.divided) {
      const j = node.count++; node.idx[j] = i; node.ptsx[j] = x; node.ptsy[j] = y; return true;
    }
    if (!node.divided) this.subdivide(node);
    return this.insert(i, x, y, node.children[ (y < node.y + node.h/2 ? 0 : 2) + (x < node.x + node.w/2 ? 0 : 1) ]);
  }

  subdivide(node) {
    node.divided = true;
    const hw = node.w/2, hh = node.h/2;
    node.children = [
      new QTNode(node.x,       node.y,       hw, hh, this.cap), // NW
      new QTNode(node.x+hw,    node.y,       hw, hh, this.cap), // NE
      new QTNode(node.x,       node.y+hh,    hw, hh, this.cap), // SW
      new QTNode(node.x+hw,    node.y+hh,    hw, hh, this.cap), // SE
    ];
    // reinsert existing points
    for (let k = 0; k < node.count; k++) {
      const i = node.idx[k]; const x = node.ptsx[k]; const y = node.ptsy[k];
      this.insert(i, x, y, node.children[ (y < node.y + node.h/2 ? 0 : 2) + (x < node.x + node.w/2 ? 0 : 1) ]);
    }
    node.count = 0; // clear leaf storage
  }

  query(cx, cy, r, out) {
    this._queryNode(this.root, cx, cy, r, out);
  }
  _queryNode(node, cx, cy, r, out) {
    // circle-rect quick reject
    const rx=node.x, ry=node.y, rw=node.w, rh=node.h;
    let nx = Math.max(rx, Math.min(cx, rx+rw));
    let ny = Math.max(ry, Math.min(cy, ry+rh));
    const dist = (cx-nx)*(cx-nx)+(cy-ny)*(cy-ny);
    if (dist > r*r) return;

    if (!node.divided) {
      for (let k=0;k<node.count;k++) { out.push(node.idx[k]); }
      return;
    }
    for (let c=0;c<4;c++) this._queryNode(node.children[c], cx, cy, r, out);
  }

  draw(ctx) {
    ctx.save();
    ctx.strokeStyle = `hsl(${(BASE_HUE+180)%360} 80% 70% / 0.14)`;
    ctx.lineWidth = 1;
    this._drawNode(ctx, this.root);
    ctx.restore();
  }
  _drawNode(ctx, node) {
    ctx.strokeRect(node.x, node.y, node.w, node.h);
    if (node.divided) for (let c=0;c<4;c++) this._drawNode(ctx, node.children[c]);
  }
}

// Interaction effects
const effects = []; // {x,y,t,life,sign}
let mouseDown = false;
addEventListener('pointerdown', e => { mouseDown = true; spawnShock(e.clientX, e.clientY, +1); });
addEventListener('pointerup',   e => { mouseDown = false; spawnShock(e.clientX, e.clientY, -1); });
addEventListener('pointermove', e => { if (mouseDown) spawnShock(e.clientX, e.clientY, +1); });

function spawnShock(x, y, sign) {
  effects.push({ x, y, t: 0, life: 1.2, sign });
}

// Physics helpers
function limit(vx, vy, max) {
  const m2 = vx*vx + vy*vy; if (m2 > max*max) {
    const m = Math.sqrt(m2) || 1; const s = max / m; return [vx*s, vy*s];
  } return [vx, vy];
}

// Main loop
let last = performance.now();
function frame(t) {
  const dt = Math.min(32, t - last) * 0.001; // clamp
  last = t;

  // trails: translucent fill
  ctx.globalCompositeOperation = 'source-over';
  ctx.fillStyle = 'rgba(5,7,10,' + CFG.trailAlpha + ')';
  ctx.fillRect(0, 0, innerWidth, innerHeight);

  // Build quadtree
  const qt = new Quadtree(0, 0, innerWidth, innerHeight, CFG.qtCap);
  for (let i=0;i<N;i++) qt.insert(i, px[i], py[i]);

  // Apply flocking via neighbor queries
  const vision = CFG.vision; const sep = CFG.sep;
  for (let i=0;i<N;i++) { ax[i]=0; ay[i]=0; }
  let tmp = [];
  for (let i=0;i<N;i++) {
    tmp.length = 0; qt.query(px[i], py[i], vision, tmp);
    let cx=0, cy=0, vxsum=0, vysum=0, sx=0, sy=0, total=0, sclose=0;
    for (let k=0;k<tmp.length;k++) {
      const j = tmp[k]; if (j===i) continue;
      const dx = px[j]-px[i]; const dy = py[j]-py[i];
      const d2 = dx*dx + dy*dy; if (d2 === 0) continue;
      const d = Math.sqrt(d2);
      if (d < vision) { total++; cx += px[j]; cy += py[j]; vxsum += vx[j]; vysum += vy[j]; }
      if (d < sep) { sclose++; sx -= dx/(d||1); sy -= dy/(d||1); }
    }
    if (total>0) {
      // alignment
      let axv = (vxsum/total) - vx[i]; let ayv = (vysum/total) - vy[i];
      [axv, ayv] = limit(axv, ayv, CFG.maxForce); ax[i] += axv * CFG.alignW; ay[i] += ayv * CFG.alignW;
      // cohesion
      let cxv = (cx/total - px[i]); let cyv = (cy/total - py[i]);
      [cxv, cyv] = limit(cxv, cyv, CFG.maxForce); ax[i] += cxv * CFG.cohesionW; ay[i] += cyv * CFG.cohesionW;
    }
    if (sclose>0) {
      let sxv = sx; let syv = sy; [sxv, syv] = limit(sxv, syv, CFG.maxForce*1.5);
      ax[i] += sxv * CFG.separationW; ay[i] += syv * CFG.separationW;
    }
  }

  // Interaction shocks: push/pull and draw rings
  ctx.save();
  ctx.globalCompositeOperation = 'lighter';
  for (let e=effects.length-1; e>=0; e--) {
    const E = effects[e]; E.t += dt; const k = E.t / E.life;
    const r = 30 + k * 260; const str = 1.0 - k; // strength fade
    // push/pull
    let tmp2 = []; qt.query(E.x, E.y, r, tmp2);
    for (let ii=0; ii<tmp2.length; ii++) {
      const i = tmp2[ii]; const dx = px[i]-E.x; const dy = py[i]-E.y; const d = Math.hypot(dx, dy)||1;
      const f = (E.sign > 0 ? +1 : -1) * (1.8 * (1 - Math.min(1, d/r)));
      ax[i] += (dx/d) * f; ay[i] += (dy/d) * f;
      hue[i] = (hue[i] + 120 * (1 - Math.min(1, d/r))) % 360; // color burst
    }
    // ring visual
    const g = ctx.createRadialGradient(E.x, E.y, Math.max(1, r*0.6), E.x, E.y, r);
    g.addColorStop(0.0, `hsla(${BASE_HUE}, 95%, 65%, ${0.25*str})`);
    g.addColorStop(0.6, `hsla(${(BASE_HUE+40)%360}, 95%, 55%, ${0.18*str})`);
    g.addColorStop(0.9, `hsla(${(BASE_HUE+80)%360}, 95%, 60%, 0)`);
    ctx.fillStyle = g; ctx.beginPath(); ctx.arc(E.x, E.y, r, 0, Math.PI*2); ctx.fill();
    if (k >= 1) effects.splice(e, 1);
  }
  ctx.restore();

  // Integrate and draw boids with glow and trails
  ctx.save();
  ctx.globalCompositeOperation = 'lighter';
  ctx.lineWidth = 1.6;
  for (let i=0;i<N;i++) {
    // integrate
    vx[i] += ax[i]; vy[i] += ay[i];
    [vx[i], vy[i]] = limit(vx[i], vy[i], CFG.maxSpeed);
    prevx[i] = px[i]; prevy[i] = py[i];
    px[i] += vx[i]; py[i] += vy[i];

    // wrap
    if (px[i] < -5) px[i] = innerWidth + 5; else if (px[i] > innerWidth+5) px[i] = -5;
    if (py[i] < -5) py[i] = innerHeight + 5; else if (py[i] > innerHeight+5) py[i] = -5;

    // speed-based tint
    spd[i] = Math.hypot(vx[i], vy[i]);
    const L = 50 + Math.min(45, spd[i]*8);
    const S = 80 + Math.min(20, spd[i]*6);
    ctx.strokeStyle = `hsl(${hue[i]}, ${S}%, ${L}%)`;
    ctx.shadowColor = `hsl(${hue[i]}, 90%, 60%)`;
    ctx.shadowBlur = 18 + Math.min(24, spd[i]*8);

    // trail segment
    ctx.beginPath();
    ctx.moveTo(prevx[i], prevy[i]);
    ctx.lineTo(px[i], py[i]);
    ctx.stroke();

    // comet head
    const ang = Math.atan2(vy[i], vx[i]);
    ctx.fillStyle = `hsl(${hue[i]}, 95%, ${L}%)`;
    ctx.beginPath();
    const s=6.5; // triangle size
    ctx.moveTo(px[i] + Math.cos(ang)*s*1.6, py[i] + Math.sin(ang)*s*1.6);
    ctx.lineTo(px[i] + Math.cos(ang+2.6)*s,  py[i] + Math.sin(ang+2.6)*s);
    ctx.lineTo(px[i] + Math.cos(ang-2.6)*s,  py[i] + Math.sin(ang-2.6)*s);
    ctx.closePath(); ctx.fill();
  }
  ctx.restore();

  // Quadtree visualization (default on)
  if (SHOW_QT) qt.draw(ctx);

  // HUD
  hudEl.innerHTML = `<strong>Boids</strong> · N=${N} vision=${CFG.vision} sep=${CFG.sep} ` +
    `· qtCap=${CFG.qtCap} · hue=${BASE_HUE} · qtViz=${SHOW_QT?'on':'off'}`;

  requestAnimationFrame(frame);
}
requestAnimationFrame(frame);

// keyboard: toggle quadtree viz
addEventListener('keydown', (e) => {
  if (e.key.toLowerCase() === 'q') {
    const url = new URL(location.href); url.searchParams.set('qt', SHOW_QT ? '0' : '1'); location.href = url.toString();
  }
});
"""


def ensure_dir(path: str):
  os.makedirs(path, exist_ok=True)


def out_dir_path(custom: str | None) -> str:
  if custom:
    ensure_dir(custom)
    return custom
  stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
  path = os.path.join("runs", f"boids-{stamp}_multifile")
  ensure_dir(path)
  return path


def write_files(folder: str):
  with open(os.path.join(folder, 'index.html'), 'w', encoding='utf-8') as f:
    f.write(HTML)
  with open(os.path.join(folder, 'style.css'), 'w', encoding='utf-8') as f:
    f.write(CSS)
  with open(os.path.join(folder, 'app.js'), 'w', encoding='utf-8') as f:
    f.write(JS)


def main():
  ap = argparse.ArgumentParser(description='Generate a multi-file boids simulation (HTML/CSS/JS)')
  ap.add_argument('--out-dir', type=str, default=None, help='output directory (defaults to runs/boids-<timestamp>_multifile)')
  args = ap.parse_args()

  folder = out_dir_path(args.out_dir)
  write_files(folder)

  print('Created:')
  for name in ('index.html','style.css','app.js'):
    print(' -', os.path.join(folder, name))
  print('\nOpen index.html in a browser and try:')
  print('  ?hue=210&header=Hello&subheader=Quadtree+viz+%2B+shockwaves')


if __name__ == '__main__':
  main()

