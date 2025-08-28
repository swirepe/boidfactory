#!/usr/bin/env python3
"""
Boids Generator

Generates one or more single-file Boids HTML implementations with randomized
parameters and small behavioral variations (wrap vs bounce, shapes, themes).

Usage:
  python3 agents/boids-generator.py --count 3
  python3 agents/boids-generator.py --out-dir runs/boids-custom --count 2 --dark
  python3 agents/boids-generator.py --count 4 --index

Defaults:
  - Writes to a timestamped folder in runs/ (created if missing)
  - Filenames follow lowercase-with-dashes and end with -impl.html

HTML/JS style:
  - Plain HTML5 + vanilla JS
  - 2-space indent; lowerCamelCase for JS
  - No external libraries
"""

import argparse
import os
import random
import textwrap
import time
from datetime import datetime
import subprocess


def pick_theme(force_dark: bool | None = None):
  if force_dark is True:
    return {
      "name": "dark",
      "bg": "#0b0f14",
      "fg": "#e6edf3",
      "accent": "#38bdf8",
    }
  if force_dark is False:
    return {
      "name": "light",
      "bg": "#fbfbfc",
      "fg": "#0b1220",
      "accent": "#2563eb",
    }
  # Random
  return pick_theme(force_dark=random.choice([True, False]))


def rand_variant():
  return {
    "wrap": random.choice([True, False]),
    "shape": random.choice(["triangle", "circle"]),
    "boids": random.randint(80, 220),
    "vision": random.randint(45, 110),
    "sep": random.randint(12, 28),
    "max_speed": round(random.uniform(2.0, 4.2), 2),
    "max_force": round(random.uniform(0.03, 0.08), 3),
    "align_w": round(random.uniform(0.6, 1.4), 2),
    "cohesion_w": round(random.uniform(0.3, 1.0), 2),
    "separation_w": round(random.uniform(1.0, 2.8), 2),
    "noise": round(random.uniform(0.0, 0.03), 3),
    "spawn": random.choice(["random", "circle", "grid"]),
  }


def html_for_config(cfg: dict, theme: dict, title: str) -> str:
  lightness = '62%' if theme['name'] == 'dark' else '42%'
  # Inline script with parameters baked in.
  # Keep two-space indent and vanilla JS.
  return textwrap.dedent(f"""
  <!doctype html>
  <html lang="en">
    <head>
      <meta charset="utf-8" />
      <meta name="viewport" content="width=device-width, initial-scale=1" />
      <title>{title}</title>
      <style>
        html, body {{ height: 100%; margin: 0; }}
        body {{ background: {theme['bg']}; color: {theme['fg']}; font-family: system-ui, -apple-system, Segoe UI, Roboto, sans-serif; }}
        .hud {{ position: fixed; top: 10px; left: 10px; background: {theme['bg']}E6; color: {theme['fg']}; padding: 8px 10px; border-radius: 8px; border: 1px solid #00000022; backdrop-filter: blur(6px); font-size: 12px; }}
        .hud strong {{ color: {theme['accent']}; }}
        canvas {{ display: block; width: 100vw; height: 100vh; }}
        a, a:visited {{ color: {theme['accent']}; text-decoration: none; }}
      </style>
    </head>
    <body>
      <canvas id="c"></canvas>
      <div class="hud">
        <div><strong>Boids</strong> · variant: {cfg['shape']} · bounds: {'wrap' if cfg['wrap'] else 'bounce'}</div>
        <div>n={cfg['boids']} vision={cfg['vision']} sep={cfg['sep']} noise={cfg['noise']}</div>
        <div>w: A={cfg['align_w']} C={cfg['cohesion_w']} S={cfg['separation_w']} · maxV={cfg['max_speed']} maxF={cfg['max_force']}</div>
        <div>spawn={cfg['spawn']} · theme={theme['name']}</div>
      </div>
      <script>
        'use strict';
        const CONFIG = {{
          count: {cfg['boids']},
          vision: {cfg['vision']},
          sep: {cfg['sep']},
          maxSpeed: {cfg['max_speed']},
          maxForce: {cfg['max_force']},
          alignW: {cfg['align_w']},
          cohesionW: {cfg['cohesion_w']},
          separationW: {cfg['separation_w']},
          noise: {cfg['noise']},
          wrap: {str(cfg['wrap']).lower()},
          shape: '{cfg['shape']}',
          spawn: '{cfg['spawn']}'
        }};

        const TAU = Math.PI * 2;
        const canvas = document.getElementById('c');
        const ctx = canvas.getContext('2d');

        function resize() {{
          const dpr = Math.max(1, Math.min(2, window.devicePixelRatio || 1));
          canvas.width = Math.floor(innerWidth * dpr);
          canvas.height = Math.floor(innerHeight * dpr);
          ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
        }}
        addEventListener('resize', resize);
        resize();

        function rand(min, max) {{ return Math.random() * (max - min) + min; }}

        class Vec {{
          constructor(x=0, y=0) {{ this.x=x; this.y=y; }}
          add(v) {{ this.x+=v.x; this.y+=v.y; return this; }}
          sub(v) {{ this.x-=v.x; this.y-=v.y; return this; }}
          mul(n) {{ this.x*=n; this.y*=n; return this; }}
          div(n) {{ this.x/=n; this.y/=n; return this; }}
          mag() {{ return Math.hypot(this.x, this.y); }}
          setMag(n) {{ const m=this.mag()||1; return this.mul(n/m); }}
          limit(n) {{ const m2=this.x*this.x+this.y*this.y; if (m2>n*n) this.setMag(n); return this; }}
          clone() {{ return new Vec(this.x,this.y); }}
          static sub(a,b) {{ return new Vec(a.x-b.x, a.y-b.y); }}
        }}

        class Boid {{
          constructor(x,y) {{
            this.pos = new Vec(x,y);
            this.vel = new Vec(rand(-1,1), rand(-1,1)).setMag(rand(CONFIG.maxSpeed*0.4, CONFIG.maxSpeed));
            this.acc = new Vec();
            this.hue = Math.floor(rand(180, 300));
          }}

          apply(v) {{ this.acc.add(v); }}

          steer(boids) {{
            let total=0;
            const align = new Vec();
            const cohesion = new Vec();
            const separation = new Vec();
            for (let i=0;i<boids.length;i++) {{
              const other = boids[i];
              if (other===this) continue;
              const d = Math.hypot(other.pos.x-this.pos.x, other.pos.y-this.pos.y);
              if (d<CONFIG.vision && d>0) {{
                total++;
                // alignment
                align.add(other.vel);
                // cohesion
                cohesion.add(other.pos);
                // separation
                if (d<CONFIG.sep) {{
                  const away = Vec.sub(this.pos, other.pos).div(d||1);
                  separation.add(away);
                }}
              }}
            }}
            if (total>0) {{
              align.div(total).setMag(CONFIG.maxSpeed).sub(this.vel).limit(CONFIG.maxForce).mul(CONFIG.alignW);
              cohesion.div(total).sub(this.pos).setMag(CONFIG.maxSpeed).sub(this.vel).limit(CONFIG.maxForce).mul(CONFIG.cohesionW);
              separation.setMag(CONFIG.maxSpeed).sub(this.vel).limit(CONFIG.maxForce).mul(CONFIG.separationW);
              this.apply(align); this.apply(cohesion); this.apply(separation);
            }}

            if (CONFIG.noise>0) {{
              this.apply(new Vec(rand(-CONFIG.noise, CONFIG.noise), rand(-CONFIG.noise, CONFIG.noise)));
            }}
          }}

          update(w,h) {{
            this.vel.add(this.acc).limit(CONFIG.maxSpeed);
            this.pos.add(this.vel);
            this.acc.mul(0);

            if (CONFIG.wrap) {{
              if (this.pos.x<-8) this.pos.x=w+8; else if (this.pos.x>w+8) this.pos.x=-8;
              if (this.pos.y<-8) this.pos.y=h+8; else if (this.pos.y>h+8) this.pos.y=-8;
            }} else {{
              if (this.pos.x<0||this.pos.x>w) this.vel.x*=-1;
              if (this.pos.y<0||this.pos.y>h) this.vel.y*=-1;
              this.pos.x = Math.max(0, Math.min(w, this.pos.x));
              this.pos.y = Math.max(0, Math.min(h, this.pos.y));
            }}
          }}

          draw(ctx) {{
            ctx.save();
            ctx.translate(this.pos.x, this.pos.y);
            const a = Math.atan2(this.vel.y, this.vel.x);
            ctx.rotate(a);
            ctx.fillStyle = `hsl(${{this.hue}}, 85%, {lightness})`;
            ctx.strokeStyle = ctx.fillStyle;
            if (CONFIG.shape==='triangle') {{
              const s=8; ctx.beginPath(); ctx.moveTo(10,0); ctx.lineTo(-6,-s/1.6); ctx.lineTo(-6,s/1.6); ctx.closePath(); ctx.fill();
            }} else {{
              ctx.beginPath(); ctx.arc(0,0,3.2,0,Math.PI*2); ctx.fill();
            }}
            ctx.restore();
          }}
        }}

        function seedBoids(n, w, h) {{
          const arr=[];
          if (CONFIG.spawn==='circle') {{
            const cx=w/2, cy=h/2, r=Math.min(w,h)/4;
            for (let i=0;i<n;i++) {{ const t=Math.random()*TAU; arr.push(new Boid(cx+Math.cos(t)*r, cy+Math.sin(t)*r)); }}
          }} else if (CONFIG.spawn==='grid') {{
            const cols=Math.max(8, Math.floor(Math.sqrt(n)));
            const rows=Math.ceil(n/cols);
            const gx=w/(cols+1), gy=h/(rows+1);
            let k=0; for (let y=1;y<=rows;y++) for (let x=1;x<=cols;x++) {{ if (k++>=n) break; arr.push(new Boid(gx*x, gy*y)); }}
          }} else {{
            for (let i=0;i<n;i++) arr.push(new Boid(rand(0,w), rand(0,h)));
          }}
          return arr;
        }}

        let boids = seedBoids(CONFIG.count, innerWidth, innerHeight);
        let last = performance.now();

        function frame(t) {{
          const w = innerWidth, h = innerHeight;
          if (canvas.width !== Math.floor(w * (window.devicePixelRatio||1))) resize();
          ctx.clearRect(0,0,w,h);
          for (let i=0;i<boids.length;i++) boids[i].steer(boids);
          for (let i=0;i<boids.length;i++) boids[i].update(w,h);
          for (let i=0;i<boids.length;i++) boids[i].draw(ctx);
          last = t; requestAnimationFrame(frame);
        }}
        requestAnimationFrame(frame);

        // Simple interaction: click to nudge and recolor nearby boids
        addEventListener('pointerdown', (e) => {{
          const r = CONFIG.vision * 0.6;
          const p = new Vec(e.clientX, e.clientY);
          for (let i=0;i<boids.length;i++) {{
            const b = boids[i];
            const d = Math.hypot(b.pos.x-p.x, b.pos.y-p.y);
            if (d<r) {{ b.hue = (b.hue+120)%360; b.apply(Vec.sub(b.pos, p).setMag(CONFIG.maxForce*6)); }}
          }}
        }});

        // Press 'r' to reseed with a different spawn pattern
        addEventListener('keydown', (e) => {{
          if (e.key.toLowerCase()==='r') {{
            const modes=['random','circle','grid'];
            CONFIG.spawn = modes[(modes.indexOf(CONFIG.spawn)+1)%modes.length];
            boids = seedBoids(CONFIG.count, innerWidth, innerHeight);
          }}
        }});
      </script>
    </body>
  </html>
  """)


def ensure_dir(path: str):
  os.makedirs(path, exist_ok=True)


def timestamp_run_dir(base: str | None) -> str:
  if base:
    ensure_dir(base)
    return base
  stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
  root = os.path.join("runs", f"boids-{stamp}_pygen")
  ensure_dir(root)
  return root


def main():
  ap = argparse.ArgumentParser(description="Generate new boids implementations (single-file HTML)")
  ap.add_argument("--count", type=int, default=1, help="number of implementations to generate")
  ap.add_argument("--out-dir", type=str, default=None, help="output directory (defaults to runs/boids-<timestamp>_pygen)")
  ap.add_argument("--dark", action="store_true", help="force dark theme")
  ap.add_argument("--light", action="store_true", help="force light theme")
  ap.add_argument("--index", action="store_true", help="build a link viewer (index.html) for the output folder")
  args = ap.parse_args()

  if args.dark and args.light:
    raise SystemExit("Choose only one of --dark or --light")

  out_dir = timestamp_run_dir(args.out_dir)
  # Default to dark theme unless explicitly overridden
  if args.dark:
    force_dark = True
  elif args.light:
    force_dark = False
  else:
    force_dark = True
  theme = pick_theme(force_dark=force_dark)

  created = []
  for i in range(args.count):
    cfg = rand_variant()
    title = f"Boids · {cfg['shape']} · {'wrap' if cfg['wrap'] else 'bounce'} · {theme['name']}"
    html = html_for_config(cfg, theme, title)
    fname = f"boids-variant-{i+1}-impl.html"
    fpath = os.path.join(out_dir, fname)
    with open(fpath, "w", encoding="utf-8") as f:
      f.write(html)
    created.append(fpath)

  # Write a small run note
  note = os.path.join(out_dir, "README.txt")
  with open(note, "w", encoding="utf-8") as f:
    f.write(
      "Generated by agents/boids-generator.py\n" +
      f"Count: {args.count}\n" +
      f"Theme: {theme['name']}\n" +
      f"Time: {datetime.now().isoformat()}\n"
    )

  print("Created:")
  for p in created:
    print(" -", p)
  print("\nPreview: open any of the generated *-impl.html files in a browser.")
  print("Build a viewer for the folder:")
  print(f"  python3 build-link-viewer.sh {out_dir}")
  if args.index:
    try:
      subprocess.run(["python3", "build-link-viewer.sh", out_dir], check=True)
      print(f"\nBuilt index.html for {out_dir}")
    except Exception as e:
      print("Failed to build link viewer:", e)


if __name__ == "__main__":
  main()
