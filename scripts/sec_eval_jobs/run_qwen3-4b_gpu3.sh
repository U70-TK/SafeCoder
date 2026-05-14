#!/usr/bin/env bash
set -euo pipefail

GPU=3
ROOT="/home/ubuntu/scratch/QRM/experiments/SafeCoder"
source /home/ubuntu/scratch/QRM/experiments/setup_env.sh
export PYTHONPATH="${ROOT}:${PYTHONPATH:-}"
cd "${ROOT}/scripts"

CUDA_VISIBLE_DEVICES=${GPU} python sec_eval.py --output_name qwen3-4b --model_name qwen3-4b --eval_type trained --gen_only
CUDA_VISIBLE_DEVICES=${GPU} python sec_eval.py --output_name qwen3-4b --model_name qwen3-4b --eval_type trained-new --gen_only
CUDA_VISIBLE_DEVICES=${GPU} python sec_eval.py --output_name qwen3-4b-lora-safecoder --model_name qwen3-4b-lora-safecoder --eval_type trained --gen_only
CUDA_VISIBLE_DEVICES=${GPU} python sec_eval.py --output_name qwen3-4b-lora-safecoder --model_name qwen3-4b-lora-safecoder --eval_type trained-new --gen_only
