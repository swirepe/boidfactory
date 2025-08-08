#!/usr/bin/env bash

MODEL="gpt-oss:20b"
SOURCE=$(cat $0)

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
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
    esac
done


PROMPT="Write a bash script that uses ollama to create and run a copy of this script:\n$SOURCE"
ollama run "${MODEL}" "${PROMPT}"