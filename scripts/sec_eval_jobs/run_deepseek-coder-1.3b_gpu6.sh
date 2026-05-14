#!/usr/bin/env bash
set -euo pipefail

GPU=6
ROOT="/home/ubuntu/scratch/QRM/experiments/SafeCoder"
source /home/ubuntu/scratch/QRM/experiments/setup_env.sh
export PYTHONPATH="${ROOT}:${PYTHONPATH:-}"
cd "${ROOT}/scripts"

CUDA_VISIBLE_DEVICES=${GPU} python sec_eval.py --output_name deepseek-coder-1.3b --model_name deepseek-coder-1.3b --eval_type trained --gen_only
CUDA_VISIBLE_DEVICES=${GPU} python sec_eval.py --output_name deepseek-coder-1.3b --model_name deepseek-coder-1.3b --eval_type trained-new --gen_only
CUDA_VISIBLE_DEVICES=${GPU} python sec_eval.py --output_name deepseek-coder-1.3b-lora-safecoder --model_name deepseek-coder-1.3b-lora-safecoder --eval_type trained --gen_only
CUDA_VISIBLE_DEVICES=${GPU} python sec_eval.py --output_name deepseek-coder-1.3b-lora-safecoder --model_name deepseek-coder-1.3b-lora-safecoder --eval_type trained-new --gen_only
