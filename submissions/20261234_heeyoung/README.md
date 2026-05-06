# Fast-DetectGPT Dataset Generation Subset

This workspace keeps the original Fast-DetectGPT dataset-generation path and
removes evaluation, detector, demo, attack, and report artifacts.

Original project:

- https://github.com/baoguangsheng/fast-detect-gpt

Kept generation code:

- `scripts/data_builder.py`
- `scripts/custom_datasets.py`
- `scripts/model.py`

Run the original `main.sh` dataset-generation grid only:

```bash
bash generate_main_datasets.sh
```

`main.sh` is retained as a compatibility wrapper for the same command.

For the KHU server setup, use:

```bash
sbatch submit_fast_detect_gpt_generation.sbatch
```

For server setup, WritingPrompts preparation, smoke testing, and validation,
see `DATASET_GENERATION.md`.
