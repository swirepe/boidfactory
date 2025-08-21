#!/usr/bin/env bash

MODEL="gpt-oss:20b"

declare -a REFINEMENTS_LIST=()
declare -a OUT_FILE_LIST=()
TIMES=10
PARALLEL_JOBS=5
THINKING_ARG="--think=false"
VERBOSE_OUTPUT="/dev/null"

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
OUT_DIR="runs/boids_$TIMESTAMP"
LOG_FILE="$OUT_DIR/boids.log"
UUID="$(uuidgen)"
LOCKFILE="/tmp/ollama-tee-$UUID.lock"

FILE_INFO=""
FIX=0
ADDED_TWISTS=0
ADDED_INVENTIONS=0
ADDED_JUICE=0

EDITOR="${EDITOR:-vim}"

trap '{ rm -f -- "$LOCKFILE"; }' EXIT

PROMPT=""
PROMPT_SIMPLE="Write an interactive boids simulation as a single file in html, css, and javascript."
PROMPT_DARK_THEME=$(cat << EndOfMessage
Let's write an beautiful, interactive, highly-configurable and informative boids simulation.

Let's write this as a single page in html, css, and javascript. Let's not use any external libraries.

Let's use a dark theme. Let's have a color selector with an optional url parameter "hue" that we use to generate a color scheme. I want the page to take any number of optional "header" and "subheader" url parameters for displaying as text on the canvas. I want the canvas to be full screen, with all configuration and stats behind toggle-able overlays. I want lots of slick animations, and for the action to begin as soon as the page loads. I want it to work well on both desktop and mobile. I want it display the frame rate.

I want all configuration available as optional url parameters.  Whenever a configuration changes on the page, I want it to be updated in the url.  I want an optional url parameter "debug" that shows all configuration values in the url and enables additional logging.

I want all overlays to start hidden.

I want all overlays to have a close button.

I want a help overlay that includes (but is not limited to) a description of this project, documentation for all configuration, specs, a detailed change log, and a comprehensive prompt log that includes this entire prompt.

EndOfMessage
)

PROMPT_WITH_JUICE=$(cat << EndOfMessage
Let's write an beautiful, interactive, highly-configurable and informative boids simulation.

Really juice the visuals.  I want it to be beautiful, sleek, and dynamic.

Let's write this as a single page in html, css, and javascript. Let's not use any external libraries.

Let's use a dark theme. Let's have a color selector with an optional url parameter "hue" that we use to generate a color scheme. I want the page to take any number of optional "header" and "subheader" url parameters for displaying as text on the canvas. I want the canvas to be full screen, with all configuration and stats behind toggle-able overlays. I want lots of slick animations, and for the action to begin as soon as the page loads. I want it to work well on both desktop and mobile. I want it display the frame rate.

I want all configuration available as optional url parameters.  Whenever a configuration changes on the page, I want it to be updated in the url.  I want an optional url parameter "debug" that shows all configuration values in the url and enables additional logging.

I want all overlays to start hidden.

I want all overlays to have a close button.

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

I want all overlays to have a close button.

I want an info overlay that contains an overview of the new rule, complete with equations or pseudocode.  Assume the audience is highly technical.

I want a help overlay that includes (but is not limited to) a description of this project, documentation for all configuration, specs, a detailed change log, and a comprehensive prompt log that includes this entire prompt.

EndOfMessage
)


ADD_TWIST_TO_PROMPT=$(cat <<- EOM
Invent ONE entirely new, creative rule that changes the boids' behavior in a surprising and interesting way.
- This rule should be mechanically different from standard boids rules.
- It should create emergent, unpredictable, and visually compelling results.
- It should be fully configurable.
- It should be fully documented.
- Give this rule a short, descriptive name.

Add that to the existing prompt and return the entire prompt.

EOM
)

ADD_INVENTION_TO_PROMPT=$(cat <<- EOM
Invent ONE entirely new, creative rule inspired by the classic rules of separation, alignment, and cohesion.
- This rule should be mechanically different from standard boids rules.
- This rule MAY be inspired by nature, physics, math, or computer science.
- It should create emergent, unpredictable, and visually compelling results.
- It should be fully configurable.
- It should be fully documented.
- Give this rule a short, descriptive name.

Add that to the existing prompt and return the entire prompt.

EOM
)

ADD_JUICE_TO_PROMPT=$(cat <<- EOM
Update this prompt to juice the visuals.  Make it beautiful, dynamic, and slick.  Return the entire prompt.
EOM
)


PROMPT_TO_SPEC=$(cat <<-EOM
Write a comprehensive spec for this prompt.

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
            FILE_INFO="${FILE_INFO}dark_"
            shift
            ;;
        --twist)
            PROMPT="${PROMPT_WITH_TWIST}"
            FILE_INFO="${FILE_INFO}twist_"
            shift
            ;;
        --juice)
            PROMPT="${PROMPT_WITH_JUICE}"
            FILE_INFO="${FILE_INFO}juice_"
            shift
            ;;
        --add-twist|--add-twists)
            ADDED_TWISTS="$2"
            shift 2
            ;;
        --add-invention|--add-inventions)
            ADDED_INVENTIONS="$2"
            shift 2
            ;;
        --add-juice)
            ADDED_JUICE="$2"
            shift 2
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
            FILE_INFO="${FILE_INFO}spec_"
            REFINEMENTS_LIST+=("$PROMPT_TO_SPEC")
            REFINEMENTS_LIST+=("$SPEC_TO_IMPLEMENTATION")
            shift
            ;;
        --think|"--think=true")
            THINKING_ARG="--think=true --hidethinking"
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
        --fix)
            FIX=1
            shift
            ;;
        --out|--output)
            OUT_DIR="$2"
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

ollama pull "$MODEL"

FILE_INFO="${FILE_INFO}j${ADDED_JUICE}t${ADDED_TWISTS}i${ADDED_INVENTIONS}"

if [ -p /dev/stdin ]; then
    PROMPT="${PROMPT} $(cat)"
fi


if [[ -z "$PROMPT" ]]; then
    PROMPT="$PROMPT_SIMPLE"
fi

mkdir -p "$OUT_DIR"
echo "$PROMPT" > "$OUT_DIR/prompt.txt"
echo "$0 --prompt-file $OUT_DIR/prompt.txt $THINKING_ARG --model $MODEL --verbose --add-twists $ADDED_TWISTS --add-inventions $ADDED_INVENTIONS" | tee -a "$LOG_FILE" > /dev/stderr
echo "$MODEL" | tee -a "$LOG_FILE" > /dev/stderr
ollama show "$MODEL" | tee -a "$LOG_FILE" > /dev/stderr

while (( ADDED_JUICE > 0 )); do
  echo "Adding juice: $ADDED_JUICE"
  REFINEMENTS_LIST=("${ADD_JUICE_TO_PROMPT}" "${REFINEMENTS_LIST[@]}")
  ((ADDED_JUICE--))
done


while (( ADDED_TWISTS > 0 )); do
  echo "Adding twist: $ADDED_TWISTS"
  REFINEMENTS_LIST=("${ADD_TWIST_TO_PROMPT}" "${REFINEMENTS_LIST[@]}")
  ((ADDED_TWISTS--))
done

while (( ADDED_INVENTIONS > 0 )); do
  echo "Adding invention: $ADDED_INVENTIONS"
  REFINEMENTS_LIST=("${ADD_INVENTION_TO_PROMPT}" "${REFINEMENTS_LIST[@]}")
  ((ADDED_INVENTIONS--)) 
done

SEED_PROMPT==$(cat<<- EndOfMessage
${PROMPT}

${REFINEMENTS_LIST[0]}
EndOfMessage
)

REFINEMENTS_LIST[0]="${SEED_PROMPT}"

echo "${REFINEMENTS_LIST[@]}" | tee -a "$LOG_FILE" > "$VERBOSE_OUTPUT"



SAFE_MODEL=$(echo "$MODEL" |  tr '[:/]' _)

function ollama_pipe {
    local prompt=$1
    shift

    echo -e "\n---- PROMPT: $prompt"  >> "$VERBOSE_OUTPUT"

    if (($#)); then
        # RECURSIVE CASE: More prompts left.
        # Run ollama, send its output to both the screen/next pipe AND the log file,
        # then pipe it into the next call of the function.
        ollama run "$MODEL" "$prompt" $THINKING_ARG | tee -a "$VERBOSE_OUTPUT" | ollama_pipe "$@"
    else
        # BASE CASE: This is the last prompt in the chain.
        # It receives input from the previous command and runs.
        # We use `tee` here as well for consistent logging of the final answer.
        ollama run "$MODEL" "$prompt" $THINKING_ARG | tee -a "$VERBOSE_OUTPUT"
    fi
}

export REFINEMENT_DEFINITION="$(declare -p REFINEMENTS_LIST)"

export -f ollama_pipe
export OUT_DIR MODEL SAFE_MODEL TIMESTAMP TIMES UUID REFINEMENT_DEFINITION LOCKFILE PROMPT VERBOSE_OUTPUT THINKING_ARG FILE_INFO LOG_FILE

function run_ollama {
    i="$1"
    OUT_FILE="boids-${SAFE_MODEL}-$TIMESTAMP-$FILE_INFO-$UUID-$i.html"

    echo "${REFINEMENTS_LIST[@]}"
    # Try to acquire the lock without waiting
    if flock -n 200; then
        echo "[INFO] ($i/$TIMES) Running $MODEL → $OUT_DIR/$OUT_FILE"
        #time ollama run "$MODEL" "$PROMPT" $THINKING_ARG $HIDE_THINKING_ARG| tee "$OUTFILE"
        ollama_pipe "${REFINEMENTS_LIST[@]}" | tee -a "$LOG_FILE" | sed -n '/<!DOCTYPE/,/<\/html>/p' | tee "$OUT_DIR/$OUT_FILE" 

    else
        ollama_pipe "${REFINEMENTS_LIST[@]}" | tee -a "$LOG_FILE" |  sed -n '/<!DOCTYPE/,/<\/html>/p' > "$OUT_DIR/$OUT_FILE" 2>/dev/null
        
    fi 200>"$LOCKFILE"

    if [[ "$FIX" ]]
    then
FIX_PROMPT=$(cat <<- EOM
Fix this and return the full implementation.
Errors:
$(jshint --extract always "$OUT_DIR/$OUT_FILE" 2>&1)
-----
Implementation:
$(cat $OUT_DIR/$OUT_FILE)


Respond only with a COMPLETE, valid HTML5 document.  Include the full implementation.
Do not include any commentary, explanations, or text outside the HTML tags.
Begin immediately with <!DOCTYPE html>.

Do not wrap the HTML in Markdown code fences.
Output raw HTML only.
EOM
)
            ollama run "$MODEL" "$FIX_PROMPT" $THINKING_ARG | tee -a "$LOG_FILE" | \
            sed -n '/<!DOCTYPE/,/<\/html>/p' > "$OUT_DIR/fix_$OUT_FILE" 2>/dev/null
    fi
    
}
export -f run_ollama

echo  "$OUT_DIR/$OUT_FILE" >> "$VERBOSE_OUTPUT"

# https://github.com/ollama/ollama/blob/main/cmd/cmd.go#L364
# the stdin prompt is prepended 


# Check to see if a pipe exists on stdin.


seq "$TIMES" | xargs -n1 -P"$PARALLEL_JOBS" bash -c 'eval "$REFINEMENT_DEFINITION"; run_ollama "$@"' _

./build-link-viewer.sh "$OUT_DIR"