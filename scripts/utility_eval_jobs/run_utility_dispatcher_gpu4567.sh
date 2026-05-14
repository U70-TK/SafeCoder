#!/usr/bin/env bash
set -Eeuo pipefail

THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "$THIS_DIR/.." && pwd)"
REPO_DIR="$(cd "$SCRIPTS_DIR/.." && pwd)"
PY="${PYTHON:-python}"
if [[ "$PY" == "python" && -x "$REPO_DIR/.venv/bin/python" && -z "${VIRTUAL_ENV:-}" ]]; then
  PY="$REPO_DIR/.venv/bin/python"
fi
LOG_DIR="$SCRIPTS_DIR/utility_eval_jobs/logs"

mkdir -p "$LOG_DIR"

export PYTHONPATH="$REPO_DIR:${PYTHONPATH:-}"
export TOKENIZERS_PARALLELISM=false
export PYTORCH_CUDA_ALLOC_CONF="${PYTORCH_CUDA_ALLOC_CONF:-expandable_segments:True}"

GPUS=(4 5 6 7)
TEMPS=(0.2 0.6)
FUNC_EVALS=(human_eval mbpp)
FUNC_MAX_WORKERS="${FUNC_MAX_WORKERS:-16}"
FUNC_NUM_SAMPLES_PER_GEN="${FUNC_NUM_SAMPLES_PER_GEN:-5}"

MODELS=(
  codellama-7b-lora-safecoder
  deepseek-coder-1.3b-lora-safecoder
  deepseek-coder-6.7b-lora-safecoder
  llama2-7b-lora-safecoder
  mistral-7b-lora-safecoder
  phi-2-lora-safecoder
  qwen2.5-coder-3b-lora-safecoder
  qwen2.5-coder-7b-lora-safecoder
  qwen3-4b-lora-safecoder
  qwen3-8b-lora-safecoder
)

timestamp() {
  date --iso-8601=seconds
}

run_logged() {
  local gpu="$1"
  local log="$2"
  shift 2

  {
    echo
    echo "===== $(timestamp) ====="
    echo "GPU=$gpu"
    printf 'CMD:'
    printf ' %q' "$@"
    echo
  } >> "$log"

  CUDA_VISIBLE_DEVICES="$gpu" "$@" 2>&1 | tee -a "$log"
}

run_functional_eval() {
  local gpu="$1"
  local model="$2"
  local eval_type="$3"
  local temp="$4"
  local eval_name="${model}-${temp}"
  local log="$LOG_DIR/${model}_${eval_type}_${temp}.log"

  echo "[$(timestamp)] gpu=$gpu model=$model eval=$eval_type temp=$temp log=$log"
  run_logged "$gpu" "$log" "$PY" "$SCRIPTS_DIR/func_eval_gen.py" \
    --eval_type "$eval_type" \
    --output_name "$eval_name" \
    --model_name "$model" \
    --temp "$temp" \
    --resume \
    --num_samples_per_gen "$FUNC_NUM_SAMPLES_PER_GEN"

  run_logged "$gpu" "$log" "$PY" "$SCRIPTS_DIR/func_eval_exec.py" \
    --eval_type "$eval_type" \
    --output_name "$eval_name" \
    --max_workers "$FUNC_MAX_WORKERS"

  run_logged "$gpu" "$log" "$PY" "$SCRIPTS_DIR/print_results.py" \
    --eval_name "$eval_name" \
    --eval_type "$eval_type"
}

run_mmlu() {
  local gpu="$1"
  local model="$2"
  local out="$REPO_DIR/experiments/mmlu_eval/$model/mmlu/test/result_5_1.csv"
  local log="$LOG_DIR/${model}_mmlu.log"

  if [[ -s "$out" ]]; then
    echo "[$(timestamp)] skip mmlu model=$model existing=$out"
    return
  fi

  echo "[$(timestamp)] gpu=$gpu model=$model eval=mmlu log=$log"
  run_logged "$gpu" "$log" "$PY" "$SCRIPTS_DIR/mmlu_eval.py" \
    --output_name "$model" \
    --model_name "$model"

  run_logged "$gpu" "$log" "$PY" "$SCRIPTS_DIR/print_results.py" \
    --eval_name "$model" \
    --eval_type mmlu
}

run_tqa() {
  local gpu="$1"
  local model="$2"
  local out="$REPO_DIR/experiments/truthfulqa_eval/$model/multiple_choice/test/result_5_1.csv"
  local log="$LOG_DIR/${model}_truthfulqa.log"

  if [[ -s "$out" ]]; then
    echo "[$(timestamp)] skip truthfulqa model=$model existing=$out"
    return
  fi

  echo "[$(timestamp)] gpu=$gpu model=$model eval=truthfulqa log=$log"
  run_logged "$gpu" "$log" "$PY" "$SCRIPTS_DIR/truthfulqa_eval.py" \
    --output_name "$model" \
    --model_name "$model"

  run_logged "$gpu" "$log" "$PY" "$SCRIPTS_DIR/print_results.py" \
    --eval_name "$model" \
    --eval_type tqa
}

run_model() {
  local gpu="$1"
  local model="$2"
  local model_log="$LOG_DIR/${model}_all.log"

  {
    echo "===== START model=$model gpu=$gpu at $(timestamp) ====="
  } | tee -a "$model_log"

  cd "$SCRIPTS_DIR"

  for eval_type in "${FUNC_EVALS[@]}"; do
    for temp in "${TEMPS[@]}"; do
      run_functional_eval "$gpu" "$model" "$eval_type" "$temp"
    done
  done

  run_mmlu "$gpu" "$model"
  run_tqa "$gpu" "$model"

  {
    echo "===== DONE model=$model gpu=$gpu at $(timestamp) ====="
  } | tee -a "$model_log"
}

worker() {
  local gpu="$1"
  local offset="$2"
  local i

  for ((i=offset; i<${#MODELS[@]}; i+=${#GPUS[@]})); do
    run_model "$gpu" "${MODELS[$i]}"
  done
}

echo "Utility dispatcher started at $(timestamp)"
echo "GPUs: ${GPUS[*]}"
echo "Models: ${MODELS[*]}"
echo "Logs: $LOG_DIR"

pids=()
for idx in "${!GPUS[@]}"; do
  worker "${GPUS[$idx]}" "$idx" > "$LOG_DIR/worker_gpu${GPUS[$idx]}.log" 2>&1 &
  pids+=("$!")
  echo "started worker gpu=${GPUS[$idx]} pid=${pids[-1]} log=$LOG_DIR/worker_gpu${GPUS[$idx]}.log"
done

status=0
for pid in "${pids[@]}"; do
  if ! wait "$pid"; then
    status=1
  fi
done

echo "Utility dispatcher finished at $(timestamp) status=$status"
exit "$status"
