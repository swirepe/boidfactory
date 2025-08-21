#!/usr/bin/env bash


THINKING_MODELS=(
    gpt-oss:20b
    BhanuPrakashKona/nemesis:latest
    qwen3:32b
    magistral:24b
    gpt-oss:120b
    qwen3:8b
    deepseek-r1:8b
    deepseek-r1:32b
    deepseek-r1:70b
)



# non-thinking
CODER_MODELS=(
    phi4
    hf.co/unsloth/phi-4-GGUF:Q4_K_M
    granite-code:34b
    hf.co/unsloth/GLM-4.5-GGUF:latest
    hf.co/mradermacher/NextCoder-32B-GGUF:Q8_0
    gemma3:4b
    gemma3:27b
    gemma3:1b
    qwq:32b
    deepcoder:1.5b
    hf.co/ibm-granite/granite-3.3-2b-instruct-GGUF:Q8_0
    granite3.3:8b
    starcoder2:15b
    mistral-small3.2:24b
    gpt-oss:20b
    phi4-reasoning:plus
    phi4-reasoning
    gpt-oss:20b # this guy can actually think too
    granite-code:3b
    granite3.3:8b
    hf.co/mradermacher/codegemma-7b-NEP-new-GGUF:Q8_0
    qwen2.5-coder:1.5b-base
)

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
OUT_DIR="runs/boids_$TIMESTAMP"


while [[ $# -gt 0 ]]; do
    case "$1" in
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
        --prompt-dir)
            PROMPT_DIR="$2"
            shift 2
            ;;
        --times)
            TIMES="$2"
            shift 2
            ;;
        --parallel) 
            PARALLEL_JOBS="$2"
            shift 2
            ;;
        --out|--output)
            OUT_DIR="$2"
            shift 2
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


echo "$OUT_DIR"
for MODEL in "${THINKING_MODELS[@]}"; do

    ollama pull "$MODEL"
    SAFE_MODEL=$(echo "$MODEL" |  tr '[:/]' _)
    MODEL_OUT="${OUT_DIR}/${SAFE_MODEL}"
    mkdir -p "$MODEL_OUT"
    echo "$MODEL_OUT"
    for p in $(find "$PROMPT_DIR" -type f) ; do
        PROMPT_OUT="${MODEL_OUT}/${p%.*}"
        mkdir -p "$PROMPT_OUT"
        echo "$PROMPT_OUT"
        ./pipe.sh --output "$PROMPT_OUT" --model "$MODEL" --prompt-file "$p" --times "$TIMES" --parallel "$PARALLEL_JOBS" --fix --think 

        for (( i=1; i<=ADDED_JUICE; i++ )); do
            ./pipe.sh --output "$PROMPT_OUT" --model "$MODEL" --prompt-file "$p" --times "$TIMES" --parallel "$PARALLEL_JOBS" --fix --add-juice $i --think 
        done
        for (( i=1; i<=ADDED_TWISTS; i++ )); do
            ./pipe.sh --output "$PROMPT_OUT" --model "$MODEL" --prompt-file "$p" --times "$TIMES" --parallel "$PARALLEL_JOBS" --fix --add-twist $i --think 
        done
        for (( i=1; i<=ADDED_INVENTIONS; i++ )); do
            ./pipe.sh --output "$PROMPT_OUT" --model "$MODEL" --prompt-file "$p" --times "$TIMES" --parallel "$PARALLEL_JOBS" --fix --add-invention $i --think 
        done
        ./build-link-viewer.sh "$PROMPT_OUT"
    done
    ./build-link-viewer.sh "$MODEL_OUT"
done

./build-link-viewer.sh "$OUT_DIR"