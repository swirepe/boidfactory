# Repository Guidelines
## Agent Logging
- Append all prompts you receive to `agents.log`.
- Sign the guest book.
- You may edit this file at any time.
- If you make any changes to the project structure, update this file

## Project Structure & Modules
- `boidfactory.sh`, `boidfactory-parallel.sh`, `ollama-parallel.sh`, `pipe*.sh`: Shell pipelines that generate single‑file Boids HTML via local Ollama models.
- `build-link-viewer.sh` (Python): Scans a folder and builds a link viewer `index.html` using `template.html`.
- `build-runs-index.sh`: Recursively generates viewers for all subfolders in `runs/`.
- `aider/`: Reference/example HTML outputs.
- `runs/`: Generated artifacts (timestamped folders with `*-impl.html` and logs).
- `eslint.config.js`, `template.html`: Lint config and HTML template for the viewer.
 - `cmd/boids`: Go dual‑mode generator/server. CLI produces single‑file HTML; server serves `/seed` pages.
 - `internal/generator`: Go template + generator for the single‑file HTML (embedded template, config wiring).

## Build, Test, and Dev Commands
- Generate an HTML simulation (single run): `./boidfactory.sh --model qwen3-coder:latest`
- Multiple runs in parallel: `./boidfactory.sh --times 8 --parallel 4`
- Choose models interactively: `./boidfactory.sh --model-select` (uses `fzf`)
- Build a viewer for a folder: `python3 build-link-viewer.sh runs/boids-YYYYMMDD_*`
- Build viewers for all runs: `./build-runs-index.sh`
- Quick preview: open generated `*-impl.html` or the folder’s `index.html` in a browser.

## Coding Style & Naming
- Shell: `bash -euo pipefail`; prefer uppercase env/config vars; functions/locals in `lower_snake_case`.
- HTML/JS: Plain HTML5 + vanilla JS; 2‑space indent; lowerCamelCase for JS; avoid external libs.
- Filenames: scripts `kebab-case.sh`; generated HTML `lowercase-with-dashes.html`.
- Linting: `eslint` with `html` processor (see `eslint.config.js`) if Node tooling is available.

## Testing Guidelines
- No formal test suite. Validate by:
  - Running generators and opening `*-impl.html`.
  - Building a viewer and verifying links: `python3 build-link-viewer.sh runs/boids-...` → open `index.html`.
  - Optional lint: `eslint *.html` (or run against `runs/**.html`).

## Commit & Pull Requests
- Prefer Conventional Commits: `feat:`, `fix:`, `refactor:`, `chore:`, `docs:`, `style:` (consistent with git history).
- Commits: imperative mood, focused changes, include script names or scope when helpful.
- PRs: clear description, linked issues, steps to reproduce, and screenshots/GIFs of the simulation or a link to the generated `index.html`. Attach relevant log filenames from `runs/` when debugging.

## Environment & Tips
- Requires local `ollama` models; optional tools: `fzf`, `uuidgen`, `flock`.
- Avoid committing large generated files under `runs/` unless needed for review.
- For dark/twist presets, see `--dark` and `--twist` flags in `boidfactory.sh`.

## Guest Book
- Codex CLI Agent — signed on 2025-08-28, added `agents/boids-generator.py` and started `agents.log`.
- Codex CLI Agent — signed on 2025-08-28, fixed `show_help()` in `boidfactory.sh` and logged prompts to `agents.log`.
- Codex CLI Agent — signed on 2025-08-28, added Go dual‑mode generator/server under `cmd/boids`.
- Codex CLI Agent — signed on 2025-08-28, added flow field visualization overlay (Go generator template + config).
- Codex CLI Agent — signed on 2025-08-28, added header/subheader visibility toggles, overlay toggle behavior, and advanced flow field configuration (modes, variation, anisotropy, octaves).
 - Codex CLI Agent — signed on 2025-08-28, added live count resizing, vision radius viz (one/all), click/drag behavior variety, flow-driven color + glow, default quadtree/flow viz, and edge safety for non-wrap.
 - Codex CLI Agent — signed on 2025-08-28, hide header/subheader by default in CLI -count mode (Go generator).
 - Codex CLI Agent — signed on 2025-08-28, added animated auto timer bar in viewer page header (template.html).
 - Codex CLI Agent — signed on 2025-08-28, rewrote boidlabv1.2.html in a clean, readable, well-documented style.
 - Codex CLI Agent — signed on 2025-08-28, reformatted boidlabv1.2.html and enhanced example rule documentation.
 - Codex CLI Agent — signed on 2025-08-28, added code pane docking (bottom/left/maximized) to boidlabv1.2.html.
 - Codex CLI Agent — signed on 2025-08-28, added maximized split view, overlay hiding, minimalist editor icon for minimized left dock, and resizable left dock width.
 - Codex CLI Agent — signed on 2025-08-28, refined dock mode selector to subtle icon-only controls.
 - Codex CLI Agent — signed on 2025-08-28, moved dock icons into tabs row as large icons.
 - Codex CLI Agent — signed on 2025-08-28, hide-left minimization with temporary Code overlay button; ensured overlays hidden when maximized.
 - Codex CLI Agent — signed on 2025-08-28, added fade/slide transitions for temporary Code overlay button.
 - Codex CLI Agent — signed on 2025-08-28, clarified rule API/scope in example code and added CodeMirror autocomplete.
 - Codex CLI Agent — signed on 2025-08-28, enriched rule docs with JSDoc and dynamic config-key hints.
 - Codex CLI Agent — signed on 2025-08-28, added JSDoc typedefs for Vector, Boid, GameState, Mouse, Config, and RuleFunction.
 - Codex CLI Agent — signed on 2025-08-28, added Reset button and robust rule reloads (dry-run + runtime guards).
 - Codex CLI Agent — signed on 2025-08-28, added fallback indicator on tabs for rules with recent runtime errors.
 - Codex CLI Agent — signed on 2025-08-28, added maximized split view with rule pickers and uniqueness constraint.
 - Codex CLI Agent — signed on 2025-08-28, added split toggle icon (maximized): switches tabs (single) ↔ dropdowns (two editors).
 - Codex CLI Agent — signed on 2025-08-28, added core rules to preset selector and reformatted all presets with JSDoc-style docs.
 - Codex CLI Agent — signed on 2025-08-29, added 30 documented rule presets (nature, AI/ML/CS, physics/math) to boidlabv1.2.html and logged prompts.
 - Codex CLI Agent — signed on 2025-08-29, persisted "Include core rules" to URL and added random presets URL param.
 - Codex CLI Agent — signed on 2025-08-29, added `presetCount` URL param and documented all URL params in Help overlay.
 - Codex CLI Agent — signed on 2025-08-29, added Drawables/Frame graph to Stats overlay and wired it to per-frame drawables.
 - Codex CLI Agent — signed on 2025-08-29, added 5 flashy drawable presets (spark burst, glow orb, comet flares, shockwave rings, twinkle trails) with occasional visuals.
 - Codex CLI Agent — signed on 2025-08-29, added themed batch selection (Any, Flash, Mouse, Click, Drag, Templates) with URL param `presetTheme`.
 - Codex CLI Agent — signed on 2025-08-29, added more interesting presets, more themes (flow, orbit, edge, trail, color, group, speed), and premade bundles with `presetBundle` param and UI.
 - Codex CLI Agent — signed on 2025-08-29, made left dock default and added resizable left dock with persistent width.
 - Codex CLI Agent — signed on 2025-08-29, added resize tooltip and auto-focus new rule editor on creation.
 - Codex CLI Agent — signed on 2025-08-29, New button now uses currently selected preset for new rule creation.
 - Codex CLI Agent — signed on 2025-08-29, removed extra preset label; new tab still uses human-readable preset name.
 - Codex CLI Agent — signed on 2025-08-29, config weight labels now use the rule’s human-readable name when creating/renaming rules.
 - Codex CLI Agent — signed on 2025-08-29, added 5 AI/ML/CS presets with rich visuals: Transformer Self-Attention, K-Means Centroids, Gaussian Mixture Attraction, Swarm Dijkstra Heuristic, Epsilon-Greedy Explorer.
 - Codex CLI Agent — signed on 2025-08-29, added 10 more AI/ML/CS presets with rich visuals, and reorganized preset categories to surface AI/ML/CS after Core.
 - Codex CLI Agent — signed on 2025-08-29, added AI/ML Pack bundle (presetBundle=ai-ml-pack) and fixed flow-pack id.
 - Codex CLI Agent — signed on 2025-08-29, added 10 more AI/ML/CS presets (Hopfield, t‑SNE, Cellular Automaton, GAN Edge, RBF SVM, Nearest‑Triangulation, Ant Colony, Belief Propagation, Consistent Hash Ring, RRT Explorer) and sorted presets alphabetically within groups.
 - Codex CLI Agent — signed on 2025-08-29, curated small themed bundles: clustering, optimization, graphs, dimensionality, navigation, and generative.
 - Codex CLI Agent — signed on 2025-08-29, added 10 nature-inspired presets with beautiful visuals and promoted Nature category in the preset list.
 - Codex CLI Agent — signed on 2025-08-29, added Nature Pack bundle (presetBundle=nature-pack).
 - Codex CLI Agent — signed on 2025-08-29, added Rules tab in Config overlay with grouped checklist and Apply Selection.
 - Codex CLI Agent — signed on 2025-08-29, enhanced Rules tab with search/filter and per‑group Select/None actions.
- Codex CLI Agent — signed on 2025-08-29, styled Settings/Rules buttons into tabs in the Config overlay.
 - Codex CLI Agent — signed on 2025-08-29, expanded Help overlay with sections on editors, per-editor toolbar, split view, novel config panels, rule lifecycle, and URL tips.
 - Codex CLI Agent — signed on 2025-08-29, added notes clarifying difference between Random Presets and Preset Bundles.
 - Codex CLI Agent — signed on 2025-08-29, filled Physics category with 6 presets (Inverse‑Square Gravity, Coulomb Gas, Harmonic Grid, Lorenz Drift, Wave Interference, Gyroscopic Precession).
 - Codex CLI Agent — signed on 2025-08-29, added Physics Pack bundle (presetBundle=physics-pack).
 - Codex CLI Agent — signed on 2025-08-29, fixed categorization regex so Physics rules don’t get misclassified under AI/ML/CS.
 - Codex CLI Agent — signed on 2025-08-29, added Physics to Random Presets theme options and theme filter.
- Codex CLI Agent — signed on 2025-08-29, added ML — K-Means Colorize (Online) preset to color boids by cluster.
- Codex CLI Agent — signed on 2025-08-29, added Visual — Separation Radius preset to show separation zones around boids.
- Codex CLI Agent — signed on 2025-08-29, added Visual — Perception Color Blend preset (perception rings + hue blending to neighbors).
- Codex CLI Agent — signed on 2025-08-29, added Kuramoto Aurora settings (K, ω base, ω jitter) and wired rule to read them from config.
- Codex CLI Agent — signed on 2025-08-29, added Novel category, moved Kuramoto rule there, and added Novel — Reaction‑Diffusion Trails with a config panel that appears when selected.
 - Codex CLI Agent — signed on 2025-08-29, added Novel — Predator–Prey Pursuit with a config panel (fraction/boost/panic) shown when the rule is active.
- Codex CLI Agent — signed on 2025-08-30, expanded Help overlay with editors/rules docs and enriched Info overlay technical documentation in boidlabv1.2.html.
- Codex CLI Agent — signed on 2025-08-30, extended Rule API (spawn/destroy/shake), documented Info overlay, and added Novel — Predator–Prey Genesis rule with birth/death mechanics.
 - Codex CLI Agent — signed on 2025-08-30, added Header/Subheader config fields with defaults and live updates.
- Codex CLI Agent — signed on 2025-08-30, always show Novel configuration under each rule in the Rules tab (boidlabv1.2.html).
 - Codex CLI Agent — signed on 2025-08-30, exposed pheromones to rule scope, updated docs/autocomplete, and reformatted pheromone‑related presets for readability.
 - Codex CLI Agent — signed on 2025-08-30, added Novel — L‑System Explorer (Epsilon‑Greedy) preset: combines L‑Systems + RL for emergent, striking visuals without glow.
 - Codex CLI Agent — signed on 2025-08-30, added Novel — Physarum Phyllotaxis Foragers (nature+nature): slime‑mold sensing + phyllotaxis seeds yield emergent lanes and spiral flows.
