#!/usr/bin/env bash
# select-ollama-model.sh - Created on Tue May  6 16:37:17 EDT 2025

# Get formatted list, sorted by size descending
MODEL_LIST=$(ollama list | tail -n +2 | sort -k2 -h -r)

# Use column to align output
SELECTED_MODEL=$(echo "$MODEL_LIST" | column -t | \
  fzf --prompt="Select a model: " \
      --preview-window=right:60%:wrap \
      --preview='ollama show {1}' \
      --header="NAME           SIZE    MODIFIED" | awk '{print $1}')




#    -t fd True if file descriptor fd is open and refers to a terminal.
#... where fd can be one of the usual file descriptor assignments:
#    0: standard input
#    1: standard output
#    2: standard error
if [[ -n "$SELECTED_MODEL" ]]; then
  if [ -t 1 ]  && command -v osascript &>/dev/null  ; then
    osascript <<EOF
tell application "iTerm2" to activate
tell application "System Events"
  keystroke "ollama run $SELECTED_MODEL"
end tell
EOF
    exit 0
  fi
    echo "$SELECTED_MODEL"
else
  exit 1
fi
