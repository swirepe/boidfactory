#!/usr/bin/env bash
# Usage: ./boids_pipeline_multi.sh base_prompt.txt
# Generates enriched prompts, specs, and implementations using multiple Ollama models, in parallel,
# with detailed logging and color-coded terminal output.

set -euo pipefail

BASE_PROMPT_FILE="${1:-base_prompt.txt}"
if [[ ! -f "$BASE_PROMPT_FILE" ]]; then
    echo "Error: Base prompt file '$BASE_PROMPT_FILE' not found."
    exit 1
fi

# How many Ollama runs to allow at the same time
JOBS=4

# Colors
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
MAGENTA="\033[0;35m"
RESET="\033[0m"

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
OUTDIR="boids_build_$TIMESTAMP"
mkdir -p "$OUTDIR"

ALL_MODELS=$(ollama list | awk 'NR>1 {print $1}' | grep -v "embed" | grep -v "rank")
CODER_MODELS=$(echo "$ALL_MODELS" | grep -i 'code' || true)

echo -e "${CYAN}=== Found Models ===${RESET}"
echo "$ALL_MODELS"
echo
echo -e "${CYAN}=== Found Coder Models ===${RESET}"
echo "$CODER_MODELS"
echo

LOG_FILE="$OUTDIR/run_log.txt"
echo "Boids Pipeline Run: $TIMESTAMP" > "$LOG_FILE"
echo "Base prompt file: $BASE_PROMPT_FILE" >> "$LOG_FILE"
echo "Output directory: $OUTDIR" >> "$LOG_FILE"
echo "Models: $ALL_MODELS" >> "$LOG_FILE"
echo "Coder Models: $CODER_MODELS" >> "$LOG_FILE"
echo "============================================" >> "$LOG_FILE"

# Stage 1 & 2: Enrich & Spec
for MODEL in $ALL_MODELS; do
    SAFE_MODEL="${MODEL//\//_}"

    echo -e "${YELLOW}[1/3] ($MODEL) Enriching prompt...${RESET}"
    echo "[STAGE 1] MODEL: $MODEL — Enriching prompt" >> "$LOG_FILE"
    START_TIME=$(date +%s)

    ENRICHED_PROMPT=$(ollama run "$MODEL" <<EOF
You are an expert at enhancing creative coding prompts.

Take the following base prompt and:
1. Improve it with additional special rules that will:
   - Encourage elegant code structure and maintainability
   - Make visuals highly interactive and reactive
   - Include accessibility considerations
   - Include performance optimizations for large numbers of boids
   - Encourage clear internal documentation
   - Enhance UX polish, transitions, and animations

2. Invent ONE entirely new, creative rule that changes the boids' behavior in a surprising and interesting way.
   - This rule should be mechanically different from standard boids rules.
   - It should create emergent, unpredictable, and visually compelling results.
   - Give this rule a short, descriptive name.

Return ONLY the enriched prompt, with all rules (including the new boid behavior rule) clearly integrated into it.

Base prompt:
$(cat "$BASE_PROMPT_FILE")
EOF
)
    ENRICH_FILE="$OUTDIR/enriched_prompt_${SAFE_MODEL}.txt"
    echo "$ENRICHED_PROMPT" > "$ENRICH_FILE"
    END_TIME=$(date +%s)
    echo "    Saved enriched prompt: $ENRICH_FILE" >> "$LOG_FILE"
    echo "    Duration: $((END_TIME - START_TIME)) seconds" >> "$LOG_FILE"
    echo "--------------------------------------------" >> "$LOG_FILE"

    echo -e "${GREEN}✔ Enriched prompt saved:${RESET} $ENRICH_FILE"

    echo -e "${YELLOW}[2/3] ($MODEL) Generating technical spec...${RESET}"
    echo "[STAGE 2] MODEL: $MODEL — Generating technical spec" >> "$LOG_FILE"
    START_TIME=$(date +%s)

    SPEC=$(ollama run "$MODEL" <<EOF
You are an expert technical spec writer.

Using the enriched prompt below, create a comprehensive technical specification for the boids simulation.
Be sure to describe the new boids behavior rule in detail so it can be implemented.

Enriched prompt:
$ENRICHED_PROMPT
EOF
)
    SPEC_FILE="$OUTDIR/spec_${SAFE_MODEL}.txt"
    echo "$SPEC" > "$SPEC_FILE"
    END_TIME=$(date +%s)
    echo "    Saved spec: $SPEC_FILE" >> "$LOG_FILE"
    echo "    Duration: $((END_TIME - START_TIME)) seconds" >> "$LOG_FILE"
    echo "============================================" >> "$LOG_FILE"

    echo -e "${GREEN}✔ Spec saved:${RESET} $SPEC_FILE"
done

# Stage 3: Implementation function
generate_html() {
    local type="$1"
    local spec_model="$2"
    local coder_model="$3"
    local spec_file="$4"
    local enrich_file="$5"

    local safe_coder="${coder_model//\//_}"
    local output_file
    local prompt_content

    case "$type" in
        base)
            output_file="$OUTDIR/boids_from_base_spec-${spec_model}_coder-${safe_coder}.html"
            prompt_content="Base prompt:
$(cat "$BASE_PROMPT_FILE")"
            ;;
        enriched)
            output_file="$OUTDIR/boids_from_enriched_spec-${spec_model}_coder-${safe_coder}.html"
            prompt_content="Enriched prompt:
$(cat "$enrich_file")"
            ;;
        spec)
            output_file="$OUTDIR/boids_from_spec-spec-${spec_model}_coder-${safe_coder}.html"
            prompt_content="Technical specification:
$(cat "$spec_file")"
            ;;
    esac

    local start_time=$(date +%s)
    echo -e "${MAGENTA}[STAGE 3] $type → SPEC MODEL: $spec_model → CODER: $coder_model${RESET}"
    echo "[STAGE 3] TYPE: $type — SPEC MODEL: $spec_model — CODER MODEL: $coder_model" >> "$LOG_FILE"
    echo "    Starting at: $(date)" >> "$LOG_FILE"

    ollama run "$coder_model" <<EOF > "$output_file"
You are an expert front-end developer.

Using the following, implement the boids simulation as a single self-contained HTML file.
- No external libraries
- Code must be clean, commented, and production-ready

$prompt_content
EOF

    local end_time=$(date +%s)
    echo "    Saved HTML: $output_file" >> "$LOG_FILE"
    echo "    Duration: $((end_time - start_time)) seconds" >> "$LOG_FILE"
    echo "--------------------------------------------" >> "$LOG_FILE"

    echo -e "${GREEN}✔ HTML saved:${RESET} $output_file (${CYAN}$((end_time - start_time))s${RESET})"
}

export -f generate_html
export BASE_PROMPT_FILE OUTDIR LOG_FILE
export -f ollama
export GREEN RED YELLOW CYAN MAGENTA RESET

# Stage 3: Parallel execution
for SPEC_FILE in "$OUTDIR"/spec_*.txt; do
    SPEC_MODEL=$(basename "$SPEC_FILE" .txt | sed 's/^spec_//')
    ENRICH_FILE="$OUTDIR/enriched_prompt_${SPEC_MODEL}.txt"

    for CODER_MODEL in $CODER_MODELS; do
        parallel_jobs=(
            "generate_html base $SPEC_MODEL $CODER_MODEL $SPEC_FILE $ENRICH_FILE"
            "generate_html enriched $SPEC_MODEL $CODER_MODEL $SPEC_FILE $ENRICH_FILE"
            "generate_html spec $SPEC_MODEL $CODER_MODEL $SPEC_FILE $ENRICH_FILE"
        )
        printf "%s\n" "${parallel_jobs[@]}" | xargs -P "$JOBS" -I CMD bash -c CMD
    done
done

# Summary
TOTAL_ENRICH=$(ls "$OUTDIR"/enriched_prompt_*.txt 2>/dev/null | wc -l)
TOTAL_SPEC=$(ls "$OUTDIR"/spec_*.txt 2>/dev/null | wc -l)
TOTAL_HTML=$(ls "$OUTDIR"/*.html 2>/dev/null | wc -l)

echo -e "${CYAN}============================================${RESET}"
echo -e "${CYAN}Pipeline Completed: $(date)${RESET}"
echo -e "${GREEN}    Enriched prompts:${RESET} $TOTAL_ENRICH"
echo -e "${GREEN}    Specs:${RESET} $TOTAL_SPEC"
echo -e "${GREEN}    HTML implementations:${RESET} $TOTAL_HTML"
echo -e "${CYAN}Output directory:${RESET} $OUTDIR"
echo -e "${CYAN}============================================${RESET}"
