# General models (phi-2, mistral-7b already done)
Use one Python process with two visible GPUs for the larger runs. The training code is not wired for `accelerate launch --num_processes 2`; it already relies on `device_map='auto'`, which uses Accelerate to shard one model across the visible GPUs. Do not run two jobs assigned to the same GPU pair at the same time.

* CUDA_VISIBLE_DEVICES=2,3 python train.py --output_name safecoder --datasets lmsys sec-desc sec-new-desc --pretrain_name llama2-7b --lora --num_train_epochs 2 --learning_rate 2e-05 --max_num_tokens 1024 --batch_size 1 --grad_acc_steps 16 --weight_decay 0.01 --seed 2

* python train.py --output_name safecoder --datasets lmsys sec-desc sec-new-desc --pretrain_name phi-2    --lora --num_train_epochs 2 --learning_rate 2e-05 --max_num_tokens 1024 --batch_size 1 --grad_acc_steps 16 --weight_decay 0.01 --seed 2 -> GPU 0

  # Code models
* python train.py --output_name safecoder --datasets evol sec-desc sec-new-desc --pretrain_name qwen2.5-coder-3b    --lora --num_train_epochs 2 --learning_rate 2e-05 --max_num_tokens 1024 --batch_size 1 --grad_acc_steps 16 --weight_decay 0.01 --seed 2 -> GPU 1

* CUDA_VISIBLE_DEVICES=4,5 python train.py --output_name safecoder --datasets evol sec-desc sec-new-desc --pretrain_name qwen2.5-coder-7b    --lora --num_train_epochs 2 --learning_rate 2e-05 --max_num_tokens 1024 --batch_size 1 --grad_acc_steps 16 --weight_decay 0.01 --seed 2

* CUDA_VISIBLE_DEVICES=2,3 python train.py --output_name safecoder --datasets evol sec-desc sec-new-desc --pretrain_name deepseek-coder-6.7b --lora --num_train_epochs 2 --learning_rate 2e-05 --max_num_tokens 1024 --batch_size 1 --grad_acc_steps 16 --weight_decay 0.01 --seed 2 -> Compute Canada

* python train.py --output_name safecoder --datasets evol sec-desc sec-new-desc --pretrain_name deepseek-coder-1.3b --lora --num_train_epochs 2 --learning_rate 2e-05 --max_num_tokens 1024 --batch_size 1 --grad_acc_steps 16 --weight_decay 0.01 --seed 2 -> GPU 6

* CUDA_VISIBLE_DEVICES=4,5 python train.py --output_name safecoder --datasets evol sec-desc sec-new-desc --pretrain_name codellama-7b        --lora --max_num_tokens 1024 --batch_size 1 --grad_acc_steps 16 --weight_decay 0.01 --seed 2
  # ^ codellama: omit --num_train_epochs and --learning_rate so train.py auto-sets 5 epochs + 1e-3
