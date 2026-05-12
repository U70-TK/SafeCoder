for cwe in cwe-022 cwe-079 cwe-089 cwe-295 cwe-326 cwe-327 cwe-352 cwe-611 cwe-681; do
    python sec_eval.py --output_name mistral-7b-lora-safecoder --model_name mistral-7b-lora-safecoder --eval_type trained-new --analyze_only --vul_type $cwe
done