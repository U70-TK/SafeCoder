# Security generation jobs

Each script runs one model family at a time, in this order:

1. base model on `trained`
2. base model on `trained-new`
3. LoRA SafeCoder model on `trained`
4. LoRA SafeCoder model on `trained-new`

The Phi script intentionally skips `phi-2-lora-safecoder` on `trained`, because that job was already launched manually.

These scripts run only the GPU-bound generation stage (`--gen_only`). After generation finishes, run CodeQL analysis separately with `--analyze_only`; that stage does not need `CUDA_VISIBLE_DEVICES`.
