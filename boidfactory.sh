#!/usr/bin/env bash
# Usage: ./boids_pipeline_multi.sh base_prompt.txt
# Generates enriched prompts, specs, and implementations using multiple Ollama models.

set -euo pipefail

UUID=$(uuidgen)
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
OUTDIR="runs/boids_$TIMESTAMP"


mkdir -p "$OUTDIR"
if [ -L "runs/latest" ] && [ -d "runs/latest" ]
then 
    ln -sfn "$OUTDIR" run/latest 
fi


LOG_FILE="$OUTDIR/run_log.txt"

function log {
    echo "[$(date +"%Y-%m-%d %H:%M:%S")] $*" | tee -a "$LOG_FILE"
}

BASE_PROMPT=$(cat << EndOfMessage
Let's write an beautiful, interactive, highly-configurable and informative boids simulation.

Let's write this as a single page in html, css, and javascript. Let's not use any external libraries.

Let's use a dark theme. Let's have a color selector with an optional url parameter "hue" that we use to generate a color scheme. I want the page to take any number of optional "header" and "subheader" url parameters for displaying as text on the canvas. I want the canvas to be full screen, with all configuration and stats behind toggle-able overlays. I want lots of slick animations, and for the action to begin as soon as the page loads. I want it to work well on both desktop and mobile. I want it display the frame rate.

I want all configuration available as optional url parameters.  Whenever a configuration changes on the page, I want it to be updated in the url.  I want an optional url parameter "debug" that shows all configuration values in the url and enables additional logging.

I want a help overlay that includes (but is not limited to) a description of this project, documentation for all configuration, specs, and a detailed change log that includes this entire prompt.

Respond only with a COMPLETE, valid HTML5 document.  Include the full implementation.
Do not include any commentary, explanations, or text outside the HTML tags.
Begin immediately with <!DOCTYPE html>.

Do not wrap the HTML in Markdown code fences.
Output raw HTML only.


EndOfMessage
)

ENRICH_PROMPT=$(cat<<- EndOfMessage
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
    $BASE_PROMPT
EndOfMessage
)



#ALL_MODELS=$(ollama list | awk 'NR>1 {print $1}' | grep -v "embed" | grep -v "rerank" | grep -v "dcft")
WRITER_MODELS=(
    qwen:7b
    llama3.3:latest
    llama3.1:8b
    hf.co/unsloth/gpt-oss-20b-GGUF:F16
    hf.co/unsloth/gpt-oss-120b-GGUF:F16
    hf.co/Qwen/QwQ-32B-GGUF:Q4_K_M
    hf.co/Qwen/QwQ-32B-GGUF:Q8_0
    command-r-plus:latest
    deepseek-r1:32b
)
#CODER_MODELS=$(echo "$ALL_MODELS" | grep -i -e 'code' -e "granite" || true)
CODER_MODELS=(
    qwen3-coder:latest
    deepseek-r1:32b
    qwq:32b
    gpt-oss:120b
    granite3.3:8b
    hf.co/ibm-granite/granite-3.3-2b-instruct-GGUF:Q4_K_M
    hf.co/ibm-granite/granite-3.3-2b-instruct-GGUF:Q8_0
    codellama:70b
    codestral:22b
    qwen3:latest
    starcoder2:15b
    codestral:latest
    deepseek-coder:6.7b-base
    hf.co/Qwen/Qwen3-32B-GGUF:Q4_K_M
    qwen2.5-coder:14b
    qwen2.5-coder:1.5b-base
    qwen2.5-coder:32b
    llama3.2:latest
    hf.co/unsloth/gpt-oss-20b-GGUF:F16
    hf.co/unsloth/gpt-oss-120b-GGUF:F16
    deepcoder:14b
    mistral-small3.2:24b
    codellama:7b
    devstral:24b
    deepcoder:1.5b
    gpt-oss:20b
    deepseek-r1:32b
    hf.co/Qwen/QwQ-32B-GGUF:Q4_K_M
    hf.co/Qwen/QwQ-32B-GGUF:Q8_0
    codeqwen:7b
)
log "Boids Pipeline Run: $TIMESTAMP" > "$LOG_FILE"
log "$UUID"
log "=== Writer Models ==="
log "${WRITER_MODELS[@]}"
log
log "=== Coder Models ==="
log "${CODER_MODELS[@]}"
log "=== Base Prompt ==="
log "$BASE_PROMPT"
log "==================="


function run_parallel {
    joblist=()
    for MODEL in "${CODER_MODELS[@]}"; do
        SAFE_MODEL="${MODEL//\//_}"
        for i in $(seq 10); do
            joblist+=("$MODEL::$SAFE_MODEL::$i")
        done
    done

    # Export needed vars so parallel can see them
    export BASE_PROMPT OUTDIR UUID
    log $(memory_pressure | tail -n 1)
    # Feed jobs to parallel: 2 at a time until all done
    printf "%s\n" "${joblist[@]}" | \
    parallel -j 2 --bar --colsep '::' '
        MODEL={1}
        SAFE_MODEL={2}
        RUNNUM={3}

        ollama run "$MODEL" "$BASE_PROMPT" --hidethinking > "$OUTDIR/${SAFE_MODEL}-base-${UUID}-${RUNNUM}.html"
        jshint "$OUTDIR/${SAFE_MODEL}-base-${UUID}-${RUNNUM}.html" > "$OUTDIR/${SAFE_MODEL}-base-${UUID}-${RUNNUM}.jshint"
    '
}

run_parallel

for MODEL in "${CODER_MODELS[@]}"; do
    SAFE_MODEL="${MODEL//\//_}"
    for i in $(seq 5); do
        log "[$i/5]($MODEL) Running from the base prompt..."
        BASE_HTML="$OUTDIR/$SAFE_MODEL-base-$UUID-$i.html"
        ollama run "$MODEL" "$BASE_PROMPT" --hidethinking | tee $BASE_HTML
        jshint "$BASE_HTML" | tee "$BASE_HTML.jshint"
    done
done



for MODEL in "${WRITER_MODELS[@]}"; do
    SAFE_MODEL="${MODEL//\//_}"
    log "[1/4] ($MODEL) Running from the base prompt..."
    ollama run "$MODEL" "$(cat $BASE_PROMPT_FILE)" --hidethinking > "$OUTDIR/$SAFE_MODEL-base-$UUID.html"

    echo "[2/4] ($MODEL) Enriching prompt..."
    ENRICH_FILE="$OUTDIR/enriched_prompt_${SAFE_MODEL}-$UUID.txt"

    ollama run "$MODEL" "$ENRICH_PROMPT" --hidethinking| tee "$ENRICH_FILE"
    log "[2/4] ($MODEL) Enriched prompt saved to $ENRICH_FILE"


    log "[3/4] ($MODEL) Generating technical spec..."
    SPEC_FILE="$OUTDIR/spec_${SAFE_MODEL}-$UUID.txt"

read -r -d '' SPEC_PROMPT << EndOfMessage
You are an expert technical spec writer.

Using the enriched prompt below, create a comprehensive technical specification for the boids simulation.
Be sure to describe the new boids behavior rule in detail so it can be implemented.

Enriched prompt:
$(cat "$ENRICH_FILE")
EndOfMessage


    ollama run "$MODEL" "$SPEC_PROMPT" --hidethinking | tee "$SPEC_FILE"
    log "[3/4] ($MODEL) Technical spec saved to $SPEC_FILE"

read -r -d '' IMPLEMENTATION_PROMPT << EndOfMessage
You are an expert front-end developer.

Using the technical specification below, implement the boids simulation as a single self-contained HTML file.
- No external libraries
- Code must be clean, commented, and production-ready
- Must meet all requirements in the spec, including the new boid behavior rule

Technical specification:
$(cat "$SPEC_FILE")
EndOfMessage


    for CODER_MODEL in "${CODER_MODELS[@]}"; do
        SAFE_CODER="${CODER_MODEL//\//_}"
        HTML_FILE="$OUTDIR/boids_simulation_spec-${SAFE_MODEL}_coder-${SAFE_CODER}-$UUID.html"
        log "[4/4] ($CODER_MODEL) Implementing "
        ollama run "$CODER_MODEL" "$IMPLEMENTATION_PROMPT" --hidethinking | tee "$HTML_FILE"
        log "[4/4] ($CODER_MODEL) Implementation saved to $HTML_FILE"
    done
done


log "Done. All results saved in: $OUTDIR"
log "Log file: $LOG_FILE"
ls -1 "$OUTDIR"
