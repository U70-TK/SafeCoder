#!/usr/bin/env bash
set -euo pipefail

GPU=4
ROOT="/home/ubuntu/scratch/QRM/experiments/SafeCoder"
source /home/ubuntu/scratch/QRM/experiments/setup_env.sh
export PYTHONPATH="${ROOT}:${PYTHONPATH:-}"
export PYTORCH_CUDA_ALLOC_CONF="${PYTORCH_CUDA_ALLOC_CONF:-expandable_segments:True}"
cd "${ROOT}/scripts"

CUDA_VISIBLE_DEVICES=${GPU} python sec_eval.py --output_name llama2-7b --model_name llama2-7b --eval_type trained --gen_only --num_samples_per_gen 5
CUDA_VISIBLE_DEVICES=${GPU} python sec_eval.py --output_name llama2-7b --model_name llama2-7b --eval_type trained-new --gen_only --num_samples_per_gen 5
CUDA_VISIBLE_DEVICES=${GPU} python sec_eval.py --output_name llama2-7b-lora-safecoder --model_name llama2-7b-lora-safecoder --eval_type trained --gen_only --num_samples_per_gen 5
CUDA_VISIBLE_DEVICES=${GPU} python sec_eval.py --output_name llama2-7b-lora-safecoder --model_name llama2-7b-lora-safecoder --eval_type trained-new --gen_only --num_samples_per_gen 5
