#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="/home/ubuntu/scratch/QRM/experiments/SafeCoder"
SCRIPTS_DIR="$REPO_DIR/scripts"
LOG_DIR="$SCRIPTS_DIR/sec_eval_jobs/logs"
SKIP_COMPLETE="${SKIP_COMPLETE:-0}"

mkdir -p "$LOG_DIR"

cd "$SCRIPTS_DIR"

models=(
  codellama-7b
  codellama-7b-lora-safecoder
  deepseek-coder-1.3b
  deepseek-coder-1.3b-lora-safecoder
  deepseek-coder-6.7b
  deepseek-coder-6.7b-lora-safecoder
  llama2-7b
  llama2-7b-lora-safecoder
  mistral-7b
  mistral-7b-lora-safecoder
  phi-2
  phi-2-lora-safecoder
  qwen2.5-coder-3b
  qwen2.5-coder-3b-lora-safecoder
  qwen2.5-coder-7b
  qwen2.5-coder-7b-lora-safecoder
)

splits=(
  trained
  trained-new
)

failures=()

for model in "${models[@]}"; do
  for split in "${splits[@]}"; do
    out_dir="$REPO_DIR/experiments/sec_eval/$model/$split"
    if [[ ! -d "$out_dir" ]]; then
      echo "===== SKIP missing output: $model / $split ====="
      continue
    fi

    if [[ "$SKIP_COMPLETE" == "1" ]]; then
      if [[ "$split" == "trained" ]]; then
        expected_rows=24
      else
        expected_rows=42
      fi
      completed_rows="$(find "$out_dir" -path '*/result.jsonl' -type f -exec cat {} + 2>/dev/null | sed '/^[[:space:]]*$/d' | wc -l)"
      if [[ "$completed_rows" -eq "$expected_rows" ]]; then
        echo "===== SKIP complete: $model / $split ($completed_rows/$expected_rows rows) ====="
        continue
      fi
    fi

    log_file="$LOG_DIR/codeql_${model}_${split}.log"
    echo "===== CodeQL analyze: $model / $split ====="
    echo "start: $(date -Is)"
    echo "log: $log_file"

    if PYTHONUNBUFFERED=1 PYTHONPATH="$REPO_DIR" \
      "$REPO_DIR/.venv/bin/python" sec_eval.py \
        --output_name "$model" \
        --model_name "$model" \
        --eval_type "$split" \
        --analyze_only \
      2>&1 | tee "$log_file"; then
      echo "done: $(date -Is)"
    else
      echo "FAILED: $model / $split"
      failures+=("$model/$split")
    fi
  done
done

if (( ${#failures[@]} > 0 )); then
  echo "===== CodeQL analysis finished with failures ====="
  printf 'failed: %s\n' "${failures[@]}"
  exit 1
fi

echo "===== CodeQL analysis complete: $(date -Is) ====="
