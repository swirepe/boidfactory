#!/usr/bin/env bash
set -euo pipefail

MODEL="gpt-oss:20b"



PROMPT=$(cat << EndOfMessage
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
PROMPT="Write an interactive boids simulation as a single file in html, css, and javascript."
ENRICH_PROMPT=$(cat<<- EndOfMessage
    Take the following base prompt and invent ONE entirely new, creative rule that changes the boids' behavior in a surprising and interesting way.
    - This rule should be mechanically different from standard boids rules.
    - It should create emergent, unpredictable, and visually compelling results.
    - It should be fully configurable.
    - It should be fully documented.
    - Give this rule a short, descriptive name.

    Return ONLY the enriched prompt, with all rules (including the new boid behavior rule) clearly integrated into it.
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
        --model)
            MODEL="$2"
            shift 2 
            ;;
        --model-select)
            MODEL=$(ollama list | tail -n +2 | sort -k2 -h -r | column -t | \
            fzf --prompt="Select a model to write this spec: " \
                --preview-window=right:60%:wrap \
                --preview='ollama show {1}' \
                --header="NAME           SIZE    MODIFIED" | awk '{print $1}')
            shift 1
            ;;
        --model-random) 
            MODEL="$(ollama list | cut -f1 -d' ' | grep -v -e 'embed' -e 'rank' | tail -n+2 | sort -R | head -n1)"
            shift 1
            ;;
        # --output)
        #     OUTFILE="$2"; shift 2 ;;
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

echo "$MODEL"
ollama show "$MODEL"
echo -e "${PROMPT}\n\n----------\n"
echo "$PROMPT" | \
    ollama run "$MODEL" "$PROMPT_TO_SPEC" | \
    ollama run "$MODEL" "$SPEC_TO_IMPLEMENTATION" 