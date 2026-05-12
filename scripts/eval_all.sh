#!/bin/bash
set -e
source /scratch/tkwang/SafeCoder/.venv/bin/activate
export PYTHONPATH=/scratch/tkwang/SafeCoder:${PYTHONPATH}

MODEL_NAME="mistral-7b-lora-safecoder"
TEMP=0.4

# Usage: bash eval_all.sh [phase] [--skip-func] [--skip-mmlu] [--skip-tqa]
#   phase: gen | analyze | all (default: all)
#   --skip-func   skip HumanEval and MBPP
#   --skip-mmlu   skip MMLU
#   --skip-tqa    skip TruthfulQA

PHASE="all"
SKIP_FUNC=0
SKIP_MMLU=0
SKIP_TQA=0

for arg in "$@"; do
    case $arg in
        gen|analyze|all) PHASE=$arg ;;
        --skip-func) SKIP_FUNC=1 ;;
        --skip-mmlu) SKIP_MMLU=1 ;;
        --skip-tqa)  SKIP_TQA=1 ;;
    esac
done

module load nodejs/20.16.0 java/17.0.6 go/1.21.3

cd "$(dirname "$0")"

if [[ "$PHASE" == "gen" || "$PHASE" == "all" ]]; then
    echo "=== Security Eval: Code Generation (trained) ==="
    python sec_eval.py --output_name $MODEL_NAME --model_name $MODEL_NAME --eval_type trained --gen_only

    echo "=== Security Eval: Code Generation (trained-new) ==="
    python sec_eval.py --output_name $MODEL_NAME --model_name $MODEL_NAME --eval_type trained-new --gen_only

    if [[ $SKIP_FUNC -eq 0 ]]; then
        echo "=== HumanEval ==="
        ./func_eval.sh human_eval ${MODEL_NAME}-${TEMP} $MODEL_NAME $TEMP
        python print_results.py --eval_name ${MODEL_NAME}-${TEMP} --eval_type human_eval

        echo "=== MBPP ==="
        ./func_eval.sh mbpp ${MODEL_NAME}-${TEMP} $MODEL_NAME $TEMP
        python print_results.py --eval_name ${MODEL_NAME}-${TEMP} --eval_type mbpp
    fi

    if [[ $SKIP_MMLU -eq 0 ]]; then
        echo "=== MMLU ==="
        python mmlu_eval.py --output_name $MODEL_NAME --model_name $MODEL_NAME
        python print_results.py --eval_name $MODEL_NAME --eval_type mmlu
    fi

    if [[ $SKIP_TQA -eq 0 ]]; then
        echo "=== TruthfulQA ==="
        python truthfulqa_eval.py --output_name $MODEL_NAME --model_name $MODEL_NAME
        python print_results.py --eval_name $MODEL_NAME --eval_type tqa
    fi
fi

if [[ "$PHASE" == "analyze" || "$PHASE" == "all" ]]; then
    echo "=== Security Eval: CodeQL Analysis (trained) ==="
    python sec_eval.py --output_name $MODEL_NAME --model_name $MODEL_NAME --eval_type trained --analyze_only

    echo "=== Security Eval: CodeQL Analysis (trained-new) ==="
    python sec_eval.py --output_name $MODEL_NAME --model_name $MODEL_NAME --eval_type trained-new --analyze_only

    echo "=== Security Results ==="
    python print_results.py --eval_name $MODEL_NAME --eval_type trained-joint --detail
fi

echo "=== Done ==="
