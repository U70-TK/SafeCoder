#!/usr/bin/env bash
set -euo pipefail

GPU=0
ROOT="/home/ubuntu/scratch/QRM/experiments/SafeCoder"
source /home/ubuntu/scratch/QRM/experiments/setup_env.sh
export PYTHONPATH="${ROOT}:${PYTHONPATH:-}"
cd "${ROOT}/scripts"

CUDA_VISIBLE_DEVICES=${GPU} python sec_eval.py --output_name phi-2 --model_name phi-2 --eval_type trained --gen_only
CUDA_VISIBLE_DEVICES=${GPU} python sec_eval.py --output_name phi-2 --model_name phi-2 --eval_type trained-new --gen_only
# Skipped: phi-2-lora-safecoder / trained. It was already launched manually.
CUDA_VISIBLE_DEVICES=${GPU} python sec_eval.py --output_name phi-2-lora-safecoder --model_name phi-2-lora-safecoder --eval_type trained-new --gen_only
