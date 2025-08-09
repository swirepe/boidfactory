#!/usr/bin/env bash
# Usage: ./boids_pipeline_multi.sh base_prompt.txt
# Generates enriched prompts, specs, and implementations using multiple Ollama models, in parallel,
# with detailed logging and color-coded terminal output.

set -euo pipefail

# Colors
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
MAGENTA="\033[0;35m"
RESET="\033[0m"



# How many Ollama runs to allow at the same time
JOBS=4
TIMES=10
# UUID=$(uuidgen)
THINKING_ARG="--think=false"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
OUTDIR="runs/boids_${TIMESTAMP}"
PROMPT_FILE_LIST=()


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
    hf.co/unsloth/Qwen3-Coder-30B-A3B-Instruct-GGUF
    granite-code:20b
    phi4-reasoning:plus
    phi4-reasoning
    hf.co/mradermacher/Homunculus-abliterated-GGUF:Q4_K_M
    gpt-oss:20b # this guy can actually think too
    granite-code:3b
    granite3.3:8b
    granite-code:8b
    hf.co/mradermacher/codegemma-7b-NEP-new-GGUF:Q8_0
    qwen2.5-coder:1.5b-base
)

# CODER_MODELS=(
#     deepseek-r1:32b
#     qwen3-coder:latest
#     qwen3:32b
#     starcoder2:15b
#     gpt-oss:20b
#     qwq:32b
#     gpt-oss:120b
#     granite3.3:8b
#     gemma3:27b
#     hf.co/ibm-granite/granite-3.3-2b-instruct-GGUF:Q4_K_M
#     hf.co/ibm-granite/granite-3.3-2b-instruct-GGUF:Q8_0
#     codellama:70b
#     codestral:22b
#     qwen3:latest
#     qwen3:30b
#     codestral:latest
#     deepseek-coder:6.7b-base
#     hf.co/Qwen/Qwen3-32B-GGUF:Q4_K_M
#     qwen2.5-coder:14b
#     qwen2.5-coder:1.5b-base
#     qwen2.5-coder:32b
#     llama3.2:latest
#     hf.co/unsloth/gpt-oss-20b-GGUF:F16
#     hf.co/unsloth/gpt-oss-120b-GGUF:F16
#     deepcoder:14b
#     mistral-small3.2:24b
#     codellama:7b
#     devstral:24b
#     deepcoder:1.5b
#     deepseek-r1:32b
#     hf.co/Qwen/QwQ-32B-GGUF:Q4_K_M
#     hf.co/Qwen/QwQ-32B-GGUF:Q8_0
#     codeqwen:7b
#     hf.co/unsloth/Qwen3-Coder-30B-A3B-Instruct-GGUF
#     hf.co/unsloth/phi-4-GGUF:Q4_K_M
# )

function show_help {
cat << EOF
Usage: $0 [OPTIONS] [PROMPT FILES OR DIRECTORIES] 

Options:
  -p, --prompt-file            File or directory of prompts
  -t, --think                  Use thinking models.
  -h, --help                   Show this help message and exit.


Examples:
  $0 prompt.txt                Run a single prompt $TIMES times,
                               with $JOBS jobs running in paralle..

  $0 prompt_dir/               Run all the files in prompt_dir/
                               Each prompt is passed to ollama individually.

  $0 prompt.txt  prompt_dir/   Run prompt.txt and  all the files in prompt_dir/
EOF

}

# if [[ "$1" = "-h" ]] || [[ "$1" = "--help" ]]; then
#     show_help
#     exit 0
# fi


# if [[ $1 = "-t" ]] || [[ $1 = "--think" ]]; then

#     shift
# fi



# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in

        --prompt-file)
            PROMPT_FILE="$2";
            readarray -t FOUND_FILES < <(find "$PROMPT_FILE" -type f)
            PROMPT_FILE_LIST+=("${FOUND_FILES[@]}");
             shift 2 ;;
        --prompt-edit)
            PROMPT_FILE=$(mktemp)
            $EDITOR "$PROMPT_FILE" || exit 0
            PROMPT_FILE_LIST+=("$PROMPT_FILE")
            shift
            ;;
        --think)
            CODER_MODELS=("${THINKING_MODELS[@]}")
            THINKING_ARG="--think=true"
            shift 
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


mkdir -p "$OUTDIR"



NUM_PROMPTS="${#PROMPT_FILE_LIST[@]}"

if [ "$NUM_PROMPTS" -eq 0 ]; then
    show_help
    exit 1
fi



NUM_CODERS="${#CODER_MODELS[@]}"
for ((i=0;i<NUM_CODERS;i++)); do

    
    MODEL=${CODER_MODELS[i]}
    SAFE_MODEL=$(echo "$MODEL" |  tr '[:/]' _)

    echo -e "[${GREEN}$((i+1))/$NUM_CODERS${RESET}] Pulling ${GREEN}$MODEL${RESET}"
    time ollama pull "$MODEL"
    echo -e "[${GREEN}$((i+1))/$NUM_CODERS${RESET}] Running ${GREEN}$MODEL${RESET}"

    for ((j=0;j<NUM_PROMPTS;j++)); do 
        PROMPT_FILE="${PROMPT_FILE_LIST[$j]}"
        echo -e "[${CYAN}$((j+1))/${NUM_PROMPTS}${RESET}] Running ${GREEN}${MODEL}${RESET} on ${CYAN}${PROMPT_FILE}${RESET}"
        time ./ollama-parallel.sh --times $TIMES --parallel $JOBS --output-dir "$OUTDIR/${PROMPT_FILE%.*}_${SAFE_MODEL}" --model "$MODEL" --prompt-file "$PROMPT_FILE" --extension "html" --hidethinking $THINKING_ARG
    done
done