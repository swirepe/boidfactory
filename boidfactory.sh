#!/usr/bin/env bash
set -euo pipefail

PARALLEL_JOBS=4
TIMES=1



SPEC_MODEL="gpt-oss:120b"
CODE_MODEL="qwen3-coder:latest"
THINKING_ARG="--think=false"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

OUT_DIR="runs/boids-${TIMESTAMP}"
UUID="$(uuidgen)"
LOG_FILE="boidfactory-${TIMESTAMP}-${UUID}.log"

HIDE_THINKING_ARG=""
SPEC_OUTPUT="/dev/null"
IMPL_OUTPUT="/dev/null"

LOCKFILE="/tmp/ollama-tee-$UUID.lock"
trap '{ rm -f -- "$LOCKFILE"; }' EXIT

PROMPT="Write an interactive boids simulation as a single file in html, css, and javascript."
PROMPT_DARK_THEME=$(cat << EndOfMessage
Let's write an beautiful, interactive, highly-configurable and informative boids simulation.

Let's write this as a single page in html, css, and javascript. Let's not use any external libraries.

Let's use a dark theme. Let's have a color selector with an optional url parameter "hue" that we use to generate a color scheme. I want the page to take any number of optional "header" and "subheader" url parameters for displaying as text on the canvas. I want the canvas to be full screen, with all configuration and stats behind toggle-able overlays. I want lots of slick animations, and for the action to begin as soon as the page loads. I want it to work well on both desktop and mobile. I want it display the frame rate.

I want all configuration available as optional url parameters.  Whenever a configuration changes on the page, I want it to be updated in the url.  I want an optional url parameter "debug" that shows all configuration values in the url and enables additional logging.

I want all overlays to start hidden.

I want a help overlay that includes (but is not limited to) a description of this project, documentation for all configuration, specs, a detailed change log, and a comprehensive prompt log that includes this entire prompt.

EndOfMessage
)

PROMPT_WITH_TWIST=$(cat<<- EndOfMessage
Let's write an interactive, informative, and beautiful boids simulation.

Invent ONE entirely new, creative rule that changes the boids' behavior in a surprising and interesting way.
- This rule should be mechanically different from standard boids rules.
- It should create emergent, unpredictable, and visually compelling results.
- It should be fully configurable.
- It should be fully documented.
- Give this rule a short, descriptive name.

Let's write this as a single page in html, css, and javascript. Let's not use any external libraries.

I want it to be highly interactive, colorful, and beautiful. Really juice the visuals. The user's click on the canvas should always be the most important and interesting interaction.

Let's use a dark theme, and let's have an optional url parameter "hue" that we use to generate a color scheme. I want the page to take any number of optional "header" and "subheader" url parameters for displaying as text on the canvas. I want the canvas to be full screen, with all configuration and stats behind toggle-able overlays. I want lots of slick animations, and for the action to begin as soon as the page loads. I want it to work well on both desktop and mobile. I want it display the frame rate.

I want all configuration available as optional url parameters.  Whenever a configuration changes on the page, I want it to be updated in the url.  I want an optional url parameter "debug" that shows all configuration values in the url and enables additional logging.

I want all overlays to start hidden.

I want a help overlay that includes (but is not limited to) a description of this project, documentation for all configuration, specs, a detailed change log, and a comprehensive prompt log that includes this entire prompt.

EndOfMessage
)


while [[ $# -gt 0 ]]; do
    case "$1" in
        --prompt)
            PROMPT="$2"
            shift 2
            ;;
        --prompt-file)
            PROMPT=$(cat "$2");
            shift 2 
            ;;
        --dark)
            PROMPT="$PROMPT_DARK_THEME"; shift 1;;
        --twist)
            PROMPT="$PROMPT_WITH_TWIST"; shift 1;;
        -code-model)
            CODE_MODEL="$2"
            shift 2
            ;;
         --code-model-select)
            CODE_MODEL=$(ollama list | tail -n +2 | sort -k2 -h -r | column -t | \
            fzf --prompt="Select a model for code generation: " \
                --preview-window=right:60%:wrap \
                --preview='ollama show {1}' \
                --header="NAME           SIZE    MODIFIED" | awk '{print $1}')
            shift 1
            ;;
        --spec-model)
            SPEC_MODEL="$2"
            shift
            ;;
        --spec-model-select)
            SPEC_MODEL=$(ollama list | tail -n +2 | sort -k2 -h -r | column -t | \
            fzf --prompt="Select a model for spec generation: " \
                --preview-window=right:60%:wrap \
                --preview='ollama show {1}' \
                --header="NAME           SIZE    MODIFIED" | awk '{print $1}')
            shift 1
            ;;
        --model)
            CODE_MODEL="$2"
            SPEC_MODEL=${CODE_MODEL}
            shift 2 
            ;;
        --model-select)
            CODE_MODEL=$(ollama list | tail -n +2 | sort -k2 -h -r | column -t | \
            fzf --prompt="Select a model (both spec and code generation): " \
                --preview-window=right:60%:wrap \
                --preview="ollama show {1}  ; echo -e '\n\n----\n${PROMPT}'" \
                --header="NAME           SIZE    MODIFIED" | awk '{print $1}')
            SPEC_MODEL=${CODE_MODEL}
            shift 1
            ;;
        --model-random) 
            CODE_MODEL="$(ollama list | cut -f1 -d' ' | grep -v -e 'embed' -e 'rank' | tail -n+2 | sort -R | head -n1)"
            SPEC_MODEL="$(ollama list | cut -f1 -d' ' | grep -v -e 'embed' -e 'rank' | tail -n+2 | sort -R | head -n1)"
            shift 1
            ;;
        --output-impl|--output)
            IMPL_OUTPUT="$2"; shift 2 ;;
        --output-spec)
            SPEC_OUTPUT="$2"; shift 2;;

        -v|--verbose)
            SPEC_OUTPUT="/dev/stderr"
            shift
            ;;
        --think|"--think=true")
            THINKING_ARG="--think=true"
            shift 
           ;;
        "--think=false")
            THINKING_ARG="--think=false"
            shift
            ;;        
        --hidethinking)
            HIDE_THINKING_ARG='--hidethinking'
            shift
            ;;
        --times)
            TIMES="$2"; shift 2 ;;
        --parallel)
            PARALLEL_JOBS="$2"; shift 2 ;;
        -h|--help)
            show_help; exit 0 ;;
        *)
            echo "[ERROR] Unknown option: $1" >&2
            show_help
            exit 1
            ;;

    esac
done

PROMPT_TO_SPEC=$(cat <<-EOM
Write a comprehensive spec from this prompt.

Core requirements:
- MUST be a single file containing html, css, and javascript
- MUST NOT use any external libraries
- MUST work well on desktop and mobile
- MUST document the entire prompt
EOM
)

SPEC_TO_IMPLEMENTATION=$(cat <<-EOM
Implement this specification as a single file in html, css, and javascript.

Core requirements:
- MUST be a single file containing html, css, and javascript
- MUST NOT use any external libraries
- MUST work well on desktop and mobile
- MUST document the entire prompt

Respond only with a COMPLETE, valid HTML5 document.  Include the full implementation.
Do not include any commentary, explanations, or text outside the HTML tags.
Begin immediately with <!DOCTYPE html>.

Do not wrap the HTML in Markdown code fences.
Output raw HTML only.
EOM
)



function log {
    echo -e "$@" | tee -a "$LOG_FILE" > /dev/stderr
}
export -f log

SAFE_CODE_MODEL=$(echo "$CODE_MODEL" |  tr '[:/]' _)
SAFE_SPEC_MODEL=$(echo "$SPEC_MODEL" |  tr '[:/]' _)

SPEC_OUTPUT="${SAFE_SPEC_MODEL}-${TIMESTAMP}_${UUID}-spec.txt"
IMPL_OUTPUT="${SAFE_CODE_MODEL}-${TIMESTAMP}_${UUID}-impl.html"
function log_models {
    log "$UUID"
    log "$SPEC_OUTPUT"
    log "$IMPL_OUTPUT"
    log "Times: $TIMES"
    log "Parallel jobs: $PARALLEL_JOBS"
    log "spec: $SPEC_MODEL"
    ollama show "$SPEC_MODEL"  | tee -a "$LOG_FILE" > /dev/stderr
    log "code $CODE_MODEL" | tee -a "$LOG_FILE" > /dev/stderr
    ollama show "$CODE_MODEL" 
    log "$PROMPT"
    log "\n\n----------\n" 
}

log_models


if [[ $TIMES -eq 1 ]]
then
    echo "$PROMPT" | \
        ollama run "$SPEC_MODEL" "$PROMPT_TO_SPEC" --think=true $HIDE_THINKING_ARG | tee "$SPEC_OUTPUT" | \
        ollama run "$CODE_MODEL" "$SPEC_TO_IMPLEMENTATION" $THINKING_ARG $HIDE_THINKING_ARG | tee "$IMPL_OUTPUT" | tee -a "$LOG_FILE"

    exit 0
fi

export LOG_FILE LOCKFILE PROMPT SPEC_MODEL SAFE_SPEC_MODEL PROMPT_TO_SPEC SPEC_TO_IMPLEMENTATION CODE_MODEL SAFE_CODE_MODEL HIDE_THINKING_ARG THINKING_ARG  TIMES OUT_DIR UUID

mkdir -p "$OUT_DIR"

run_ollama() {
    i="$1"

    SPEC_OUTPUT="${OUT_DIR}/${SAFE_SPEC_MODEL}-${TIMESTAMP}_${UUID}-${i}-spec.txt"
    IMPL_OUTPUT="${OUT_DIR}/${SAFE_CODE_MODEL}-${TIMESTAMP}_${UUID}-${i}-impl.html"


    # ollama run "$MODEL" "$PROMPT" --hidethinking > "$OUTFILE"
    # Try to acquire the lock without waiting
    if flock -n 200; then
    log "($i/$TIMES) $SPEC_OUTPUT $IMPL_OUTPUT"
    echo "$PROMPT" | \
        ollama run "$SPEC_MODEL" "$PROMPT_TO_SPEC" --think=true $HIDE_THINKING_ARG | tee "$SPEC_OUTPUT" | \
        ollama run "$CODE_MODEL" "$SPEC_TO_IMPLEMENTATION" $THINKING_ARG $HIDE_THINKING_ARG | tee "$IMPL_OUTPUT" | tee -a "$LOG_FILE"
    else

      echo "$PROMPT" | \
        ollama run "$SPEC_MODEL" "$PROMPT_TO_SPEC" --think=true $HIDE_THINKING_ARG | tee "$SPEC_OUTPUT" | \
        ollama run "$CODE_MODEL" "$SPEC_TO_IMPLEMENTATION" $THINKING_ARG $HIDE_THINKING_ARG >"$IMPL_OUTPUT" 2>/dev/null
    fi 200>"$LOCKFILE"

    
}
export -f run_ollama



seq "$TIMES" | xargs -n1 -P"$PARALLEL_JOBS" bash -c 'run_ollama "$@"' _