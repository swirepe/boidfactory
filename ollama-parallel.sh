#!/usr/bin/env bash

set -euo pipefail

show_help() {
cat << EOF
Usage: $0 [OPTIONS]

Options:
  --prompt "TEXT"         Prompt to feed to Ollama.
  --prompt-file FILE      File containing the prompt (overrides --prompt if both given).
  --model MODEL           Ollama model to use (e.g., llama3, qwen2.5-coder).
  --model-select          Use fzf to select a model interactively
  --model-random          Select a model at random, avoiding embed and reranker models
  --times N               Number of runs (default: 1).
  --parallel N            Number of runs to execute in parallel (default: 2).
  --output-dir DIR        Directory to save output HTML files (default: ./out).
  -h, --help              Show this help message and exit.

Examples:
  $0 --prompt "Write a boids simulation in HTML" --model llama3 --times 5 --parallel 2
  $0 --prompt-file myprompt.txt --model qwen2.5-coder --times 10 --parallel 3 --output-dir ./results
EOF
}

# Default values
PROMPT="What is love?"
PROMPT_FILE=""
MODEL="hf.co/ibm-granite/granite-3.3-2b-instruct-GGUF:Q8_0"
TIMES=1
PARALLEL_JOBS=2
OUTDIR="./runs"

EDITOR="${EDITOR:-vim}"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --prompt)
            PROMPT="$2"; shift 2 ;;
        --prompt-file)
            PROMPT_FILE="$2"; shift 2 ;;
        --prompt-edit)
            PROMPT_FILE=$(mktemp)
            $EDITOR "$PROMPT_FILE"
            shift
            ;;
        --model)
            MODEL="$2"; shift 2 ;;
        --model-select)
            MODEL=$(ollama list | tail -n +2 | sort -k2 -h -r | column -t | \
            fzf --prompt="Select a model: " \
                --preview-window=right:60%:wrap \
                --preview='ollama show {1}' \
                --header="NAME           SIZE    MODIFIED" | awk '{print $1}')
            shift 1
            ;;
        --model-random) 
            MODEL="$(ollama list | cut -f1 -d' ' | grep -v -e 'embed' -e 'rank' | tail -n+2 | sort -R | head -n1)"
            shift 1
            ;;
        --times)
            TIMES="$2"; shift 2 ;;
        --parallel)
            PARALLEL_JOBS="$2"; shift 2 ;;
        --output-dir)
            OUTDIR="$2"; shift 2 ;;
        -h|--help)
            show_help; exit 0 ;;
        *)
            echo "[ERROR] Unknown option: $1" >&2
            show_help
            exit 1
            ;;
    esac
done

# Validate arguments
if [[ -n "$PROMPT_FILE" ]]; then
    if [[ ! -f "$PROMPT_FILE" ]]; then
        echo "[ERROR] Prompt file not found: $PROMPT_FILE" >&2
        exit 1
    fi
    PROMPT="$(< "$PROMPT_FILE")"
fi

if [[ -z "$PROMPT" ]]; then
    echo "[ERROR] You must specify a prompt with --prompt or --prompt-file" >&2
    exit 1
fi

if [[ -z "$MODEL" ]]; then
    echo "[ERROR] You must specify a model with --model" >&2
    exit 1
fi

mkdir -p "$OUTDIR"

# Export vars for xargs/bash
export PROMPT MODEL OUTDIR TIMES

# Function to run one Ollama request
run_ollama() {
    i="$1"
    SAFE_MODEL="${MODEL//\//_}"
    UUID="$(uuidgen)"
    OUTFILE="$OUTDIR/${SAFE_MODEL}-${UUID}-${i}.txt"

    echo "[INFO] ($i/$TIMES) Running $MODEL → $OUTFILE"
    ollama run "$MODEL" "$PROMPT" --hidethinking > "$OUTFILE"
}

export -f run_ollama

# Run in parallel
seq "$TIMES" | xargs -n1 -P"$PARALLEL_JOBS" bash -c 'run_ollama "$@"' _
