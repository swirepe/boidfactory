#!/usr/bin/env bash

MODEL="gpt-oss:20b"

declare -a REFINEMENTS_LIST=()
TIMES=10
PARALLEL_JOBS=5
THINKING_ARG="--think=false"
VERBOSE_OUTPUT="/dev/null"

UUID="$(uuidgen)"
LOCKFILE="/tmp/ollama-tee-$UUID.lock"

EDITOR="${EDITOR:-vim}"

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

I want an info overlay that contains an overview of the new rule, complete with equations or pseudocode.  Assume the audience is highly technical.

I want a help overlay that includes (but is not limited to) a description of this project, documentation for all configuration, specs, a detailed change log, and a comprehensive prompt log that includes this entire prompt.

EndOfMessage
)

PROMPT_TO_SPEC=$(cat <<-EOM
Write a comprehensive spec this prompt.

Core requirements:
- MUST be a single file containing html, css, and javascript
- MUST NOT use any external libraries
- MUST work well on desktop and mobile
EOM
)



SPEC_TO_IMPLEMENTATION=$(cat <<-EOM
Implement this specification as a single file in html, css, and javascript.

Core requirements:
- MUST be a single file containing html, css, and javascript
- MUST NOT use any external libraries
- MUST work well on desktop and mobile

Respond only with a COMPLETE, valid HTML5 document.  Include the full implementation.
Do not include any commentary, explanations, or text outside the HTML tags.
Begin immediately with <!DOCTYPE html>.

Do not wrap the HTML in Markdown code fences.
Output raw HTML only.
EOM
)






function select_model() {
    MODEL=$(ollama list | tail -n +2 | sort -k2 -h -r | column -t | \
    fzf --prompt="Select a model to write this spec: " \
        --preview-window=right:60%:wrap \
        --preview='ollama show {1}' \
        --header="NAME           SIZE    MODIFIED" | awk '{print $1}')
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --model)
            MODEL="$2";
            shift 2
            ;;
        --model-select)
            select_model
            shift
            ;;
        --dark)
            PROMPT="${PROMPT_DARK_THEME}"
            shift
            ;;
        --twist)
            PROMPT="${PROMPT_WITH_TWIST}"
            shift
            ;;
        --prompt)
            PROMPT="${PROMPT}${2}"
            shift 2
            ;;
        --prompt-file)
            PROMPT="$(cat $2)"
            shift 2
            ;;
        --prompt-edit)
            PROMPT_FILE=$(mktemp)
            $EDITOR "$PROMPT_FILE" || exit 0
            PROMPT="$(cat $PROMPT_FILE)"
            shift
            ;;
        --spec)
            REFINEMENTS_LIST+=("$PROMPT_TO_SPEC")
            REFINEMENTS_LIST+=("$SPEC_TO_IMPLEMENTATION")
            shift
            ;;
        --think|"--think=true")
            THINKING_ARG="--think=true"
            shift 
           ;;
        --times)
            TIMES="$2"
            shift 2
            ;;
        --parallel) 
            PARALLEL_JOBS="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE_OUTPUT=/dev/stderr
            shift
            ;;
        -h|--help)
            show_help; exit 0 ;;
        *)
            echo "[ERROR] Unknown option: $1" >&2
            show_help
            exit 1
            ;;
    esac
done


OUT_DIR="runs"
mkdir -p "$OUT_DIR"
UUID="$(uuidgen)"
SAFE_MODEL=$(echo "$MODEL" |  tr '[:/]' _)
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")



function ollama_pipe {
    local first=$1
    shift
    echo "$first" >> "$VERBOSE_OUTPUT"
    if (($#)); then
        tee "$VERBOSE_OUTPUT" | ollama run "$MODEL" "$first" $THINKING_ARG | ollama_pipe "$@"
    else
        ollama run "$MODEL" "$first" $THINKING_ARG
    fi
}

export -f ollama_pipe
export OUT_DIR MODEL SAFE_MODEL TIMESTAMP TIMES UUID REFINEMENTS_LIST LOCKFILE PROMPT VERBOSE_OUTPUT THINKING_ARG

function run_ollama {
    i="$1"
    OUT_FILE="boids-${SAFE_MODEL}-$TIMESTAMP-$UUID-$i.html"
    # Try to acquire the lock without waiting
    if flock -n 200; then
        echo "[INFO] ($i/$TIMES) Running $MODEL → $OUT_FILE"
        #time ollama run "$MODEL" "$PROMPT" $THINKING_ARG $HIDE_THINKING_ARG| tee "$OUTFILE"
         echo "$PROMPT" | ollama_pipe "${REFINEMENTS_LIST[@]}" | sed -n '/<!DOCTYPE/,/<\/html>/p' | tee "$OUT_DIR/$OUT_FILE"

    else
       echo "$PROMPT" | \
            ollama_pipe "${REFINEMENTS_LIST[@]}" | sed -n '/<!DOCTYPE/,/<\/html>/p' > "$OUT_DIR/$OUT_FILE" 2>/dev/null
        
    fi 200>"$LOCKFILE"

    
    #JS_ERRORS=$(jshint --extract always "$OUT_DIR/$OUT_FILE")
    #if [[ ! -z "$JS_ERRORS"]]
    #ollama run "Fix these errors and return the full implementation." 
}
export -f run_ollama

echo  "$OUT_DIR/$OUT_FILE" >> "$VERBOSE_OUTPUT"

# https://github.com/ollama/ollama/blob/main/cmd/cmd.go#L364
# the stdin prompt is prepended 

# Check to see if a pipe exists on stdin.
if [ -p /dev/stdin ]; then
    PROMPT="${PROMPT} $(cat)"
    # cat | ollama run "$MODEL" "$PROMPT" | ollama_pipe "${REFINEMENTS_LIST[@]}" | sed -n '/<!DOCTYPE/,/<\/html>/p' | tee "$OUT_DIR/$OUT_FILE"

#else

    # echo "$PROMPT" | ollama_pipe "${REFINEMENTS_LIST[@]}" | tee "$VERBOSE_OUTPUT" | sed -n '/<!DOCTYPE/,/<\/html>/p' | tee "$OUT_DIR/$OUT_FILE"
fi

seq "$TIMES" | xargs -n1 -P"$PARALLEL_JOBS" bash -c 'run_ollama "$@"' _

