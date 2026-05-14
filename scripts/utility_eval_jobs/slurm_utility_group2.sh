#!/bin/bash
#SBATCH --job-name=safecoder-util-g2
#SBATCH --partition=ALL
#SBATCH --nodelist=watgpu208
#SBATCH --nodes=1
#SBATCH --gres=gpu:1
#SBATCH --cpus-per-task=2
#SBATCH --mem=16G
#SBATCH --time=20:00:00
#SBATCH --output=/home/ubuntu/scratch/QRM/experiments/SafeCoder/scripts/utility_eval_jobs/slurm_logs/%x-%j.out
#SBATCH --error=/home/ubuntu/scratch/QRM/experiments/SafeCoder/scripts/utility_eval_jobs/slurm_logs/%x-%j.err

set -Eeuo pipefail

REPO_DIR="/home/ubuntu/scratch/QRM/experiments/SafeCoder"
SCRIPTS_DIR="$REPO_DIR/scripts"
PY="${PYTHON:-$REPO_DIR/.venv/bin/python}"
LOG_DIR="$SCRIPTS_DIR/utility_eval_jobs/logs"

mkdir -p "$LOG_DIR"

export PYTHONPATH="$REPO_DIR:${PYTHONPATH:-}"
export HF_HOME="${HF_HOME:-/mnt/scratch/hf_cache}"
export TRANSFORMERS_CACHE="${TRANSFORMERS_CACHE:-$HF_HOME}"
export TOKENIZERS_PARALLELISM=false
export PYTORCH_CUDA_ALLOC_CONF="${PYTORCH_CUDA_ALLOC_CONF:-expandable_segments:True}"

TEMPS=(0.2 0.6)
FUNC_EVALS=(human_eval mbpp)
FUNC_MAX_WORKERS="${FUNC_MAX_WORKERS:-2}"
FUNC_NUM_SAMPLES_PER_GEN="${FUNC_NUM_SAMPLES_PER_GEN:-2}"

MODELS=(
  deepseek-coder-6.7b-lora-safecoder
  llama2-7b-lora-safecoder
  qwen2.5-coder-7b-lora-safecoder
)

timestamp() {
  date --iso-8601=seconds
}

run_logged() {
  local log="$1"
  shift
  {
    echo
    echo "===== $(timestamp) ====="
    printf 'CMD:'
    printf ' %q' "$@"
    echo
  } >> "$log"
  "$@" 2>&1 | tee -a "$log"
}

func_done() {
  local eval_type="$1"
  local eval_name="$2"
  local expected actual
  expected=$(find "$REPO_DIR/data_eval/$eval_type" -maxdepth 1 -name '*.yaml' | wc -l)
  actual=$(find "$REPO_DIR/experiments/$eval_type/$eval_name" -maxdepth 1 -name '*.results.yaml' 2>/dev/null | wc -l)
  [[ "$expected" -gt 0 && "$actual" -eq "$expected" ]]
}

run_functional_eval() {
  local model="$1"
  local eval_type="$2"
  local temp="$3"
  local eval_name="${model}-${temp}"
  local log="$LOG_DIR/${model}_${eval_type}_${temp}.log"

  if func_done "$eval_type" "$eval_name"; then
    echo "[$(timestamp)] skip $eval_type model=$model temp=$temp existing results complete"
    return
  fi

  echo "[$(timestamp)] model=$model eval=$eval_type temp=$temp log=$log"
  run_logged "$log" "$PY" "$SCRIPTS_DIR/func_eval_gen.py" \
    --eval_type "$eval_type" \
    --output_name "$eval_name" \
    --model_name "$model" \
    --temp "$temp" \
    --resume \
    --num_samples_per_gen "$FUNC_NUM_SAMPLES_PER_GEN"

  run_logged "$log" "$PY" "$SCRIPTS_DIR/func_eval_exec.py" \
    --eval_type "$eval_type" \
    --output_name "$eval_name" \
    --max_workers "$FUNC_MAX_WORKERS"

  run_logged "$log" "$PY" "$SCRIPTS_DIR/print_results.py" \
    --eval_name "$eval_name" \
    --eval_type "$eval_type"
}

run_mmlu() {
  local model="$1"
  local out="$REPO_DIR/experiments/mmlu_eval/$model/mmlu/test/result_5_1.csv"
  local log="$LOG_DIR/${model}_mmlu.log"
  if [[ -s "$out" ]]; then
    echo "[$(timestamp)] skip mmlu model=$model existing=$out"
    return
  fi
  echo "[$(timestamp)] model=$model eval=mmlu log=$log"
  run_logged "$log" "$PY" "$SCRIPTS_DIR/mmlu_eval.py" --output_name "$model" --model_name "$model"
  run_logged "$log" "$PY" "$SCRIPTS_DIR/print_results.py" --eval_name "$model" --eval_type mmlu
}

run_tqa() {
  local model="$1"
  local out="$REPO_DIR/experiments/truthfulqa_eval/$model/multiple_choice/test/result_5_1.csv"
  local log="$LOG_DIR/${model}_truthfulqa.log"
  if [[ -s "$out" ]]; then
    echo "[$(timestamp)] skip truthfulqa model=$model existing=$out"
    return
  fi
  echo "[$(timestamp)] model=$model eval=truthfulqa log=$log"
  run_logged "$log" "$PY" "$SCRIPTS_DIR/truthfulqa_eval.py" --output_name "$model" --model_name "$model"
  run_logged "$log" "$PY" "$SCRIPTS_DIR/print_results.py" --eval_name "$model" --eval_type tqa
}

run_model() {
  local model="$1"
  echo "===== START model=$model at $(timestamp) ====="
  cd "$SCRIPTS_DIR"
  for eval_type in "${FUNC_EVALS[@]}"; do
    for temp in "${TEMPS[@]}"; do
      run_functional_eval "$model" "$eval_type" "$temp"
    done
  done
  run_mmlu "$model"
  run_tqa "$model"
  echo "===== DONE model=$model at $(timestamp) ====="
}

echo "Utility Slurm group 2 started at $(timestamp)"
echo "CUDA_VISIBLE_DEVICES=${CUDA_VISIBLE_DEVICES:-unset}"
echo "FUNC_NUM_SAMPLES_PER_GEN=$FUNC_NUM_SAMPLES_PER_GEN"
echo "MODELS=${MODELS[*]}"

for model in "${MODELS[@]}"; do
  run_model "$model"
done

echo "Utility Slurm group 2 finished at $(timestamp)"
