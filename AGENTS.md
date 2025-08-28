# Repository Guidelines
## Agent Logging
- Append all prompts you receive to `agents.log`.
- Sign the guest book.
- You may edit this file at any time.

## Project Structure & Modules
- `boidfactory.sh`, `boidfactory-parallel.sh`, `ollama-parallel.sh`, `pipe*.sh`: Shell pipelines that generate single‑file Boids HTML via local Ollama models.
- `build-link-viewer.sh` (Python): Scans a folder and builds a link viewer `index.html` using `template.html`.
- `build-runs-index.sh`: Recursively generates viewers for all subfolders in `runs/`.
- `aider/`: Reference/example HTML outputs.
- `runs/`: Generated artifacts (timestamped folders with `*-impl.html` and logs).
- `eslint.config.js`, `template.html`: Lint config and HTML template for the viewer.

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
