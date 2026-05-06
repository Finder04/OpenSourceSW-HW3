#!/bin/bash
#SBATCH --job-name=baseline_cmp
#SBATCH --partition=batch_grad
#SBATCH --gres=gpu:high_perf:3
#SBATCH --cpus-per-gpu=8
#SBATCH --mem-per-gpu=29G
#SBATCH --time=6-00:00:00
#SBATCH --nodelist=ariel-n1
#SBATCH --output=/nas2/data/heeyoung37/DASA/logs/%j_out.txt
#SBATCH --error=/nas2/data/heeyoung37/DASA/logs/%j_err.txt
#SBATCH --mail-type=BEGIN,END,FAIL
#SBATCH --mail-user=heeyoung37@khu.ac.kr

source /nas2/data/heeyoung37/anaconda3/etc/profile.d/conda.sh
conda activate base

export LD_LIBRARY_PATH=$CONDA_PREFIX/lib:$LD_LIBRARY_PATH

export WANDB_API_KEY=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
wandb login --relogin $WANDB_API_KEY

cd /nas2/data/heeyoung37/DASA

LOG_DIR=/nas2/data/heeyoung37/DASA/logs/baseline_cmp_${SLURM_JOB_ID}
mkdir -p "${LOG_DIR}"

DATASETS=(original combined_gen)

echo "============================================================"
echo " Baseline Comparison Job: ${SLURM_JOB_ID}"
echo " Datasets : ${DATASETS[*]}"
echo " Log dir  : ${LOG_DIR}"
echo "============================================================"

# ─────────────────────────────────────────────────────────────────────────────
# 0. combined_gen 임베딩 생성 (MoSEs 전처리)
#    original 임베딩은 /nas2/.../Original_embedded/llama-3-70b/ 에 기존재 가정
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "[$(date '+%H:%M:%S')] [0/3] combined_gen 임베딩 시작 (MoSEs 전처리)..."
python Baseline/MoSEs/embed_new_gen.py \
    --dataset       combined_gen \
    --splits        train,test \
    --model_name    BAAI/bge-m3 \
    --model_cache_path /nas2/data/heeyoung37/model/bge-m3 \
    --embedding_type encode \
    --batch_size    64 \
    2>&1 | tee "${LOG_DIR}/embed_combined_gen.log"
echo "[$(date '+%H:%M:%S')] 임베딩 완료"

# ─────────────────────────────────────────────────────────────────────────────
# 1. DASA (Halo-Scope)
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "============================================================"
echo " [1/3] DASA"
echo "============================================================"
for DS in "${DATASETS[@]}"; do
    echo "[$(date '+%H:%M:%S')] DASA [$DS] 시작..."
    python Baseline/DASA/train.py \
        --dataset          "$DS" \
        --model_name       EleutherAI/gpt-neo-2.7B \
        --model_cache_path /nas2/data/heeyoung37/model/gpt-neo-2.7B \
        --batch_size       16 \
        --k_svd            100 \
        --output_name      "baseline_cmp_${SLURM_JOB_ID}" \
        2>&1 | tee "${LOG_DIR}/dasa_${DS}.log"
    echo "[$(date '+%H:%M:%S')] DASA [$DS] 완료"
done

# ─────────────────────────────────────────────────────────────────────────────
# 2. DetectGPT
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "============================================================"
echo " [2/3] DetectGPT"
echo "============================================================"
for DS in "${DATASETS[@]}"; do
    echo "[$(date '+%H:%M:%S')] DetectGPT [$DS] 시작..."
    python Baseline/DetectGPT/run_DetectGPT_new_gen.py \
        --dataset                "$DS" \
        --split                  test \
        --base_model_name        EleutherAI/gpt-neo-2.7B \
        --model_cache_path       /nas2/data/heeyoung37/model/gpt-neo-2.7B \
        --mask_filling_model_name t5-large \
        --mask_model_cache_path  /nas2/data/heeyoung37/model/t5-large \
        --n_perturbation_list    1,10 \
        --pct_words_masked       0.3 \
        --span_length            2 \
        --output_name            "baseline_cmp_${SLURM_JOB_ID}" \
        2>&1 | tee "${LOG_DIR}/detectgpt_${DS}.log"
    echo "[$(date '+%H:%M:%S')] DetectGPT [$DS] 완료"
done

# ─────────────────────────────────────────────────────────────────────────────
# 3. MoSEs (Fast-DetectGPT + LASTDE++ + MoSEs SubCentroids)
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "============================================================"
echo " [3/3] MoSEs"
echo "============================================================"
for DS in "${DATASETS[@]}"; do
    echo "[$(date '+%H:%M:%S')] MoSEs [$DS] 시작..."
    python Baseline/MoSEs/run_MOSES_new_gen.py \
        --dataset          "$DS" \
        --scoring_model_name  EleutherAI/gpt-neo-2.7B \
        --scoring_model_cache /nas2/data/heeyoung37/model/gpt-neo-2.7B \
        --num_subcentroids 4 \
        --num_epochs       10 \
        --batch_size       32 \
        --learning_rate    0.001 \
        --lastde_n_samples  100 \
        --lastde_embed_size 4 \
        --lastde_epsilon    8.0 \
        --lastde_tau_prime  15 \
        --output_name      "baseline_cmp_${SLURM_JOB_ID}" \
        2>&1 | tee "${LOG_DIR}/moses_${DS}.log"
    echo "[$(date '+%H:%M:%S')] MoSEs [$DS] 완료"
done

# ─────────────────────────────────────────────────────────────────────────────
# 4. 최종 성능 요약
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "[$(date '+%H:%M:%S')] ===== 최종 성능 요약 파싱 중... ====="

export LOG_DIR
python3 << 'PYEOF'
import re, os

LOG_DIR  = os.environ["LOG_DIR"]
DATASETS = ["original", "combined_gen"]


def extract_dasa(path):
    if not os.path.exists(path):
        return "MISSING", "MISSING"
    text = open(path).read()
    m = re.search(r'Best Layer: (.+?) \(AUROC: ([0-9.]+)\)', text)
    if not m:
        return "N/A", "N/A"
    auroc = m.group(2)
    layer = re.escape(m.group(1).strip())
    m2 = re.search(rf'\[{layer}\].*?FPR95: ([0-9.]+)', text)
    fpr = m2.group(1) if m2 else "N/A"
    return auroc, fpr


def extract_detectgpt(path):
    if not os.path.exists(path):
        return "MISSING", "MISSING"
    text = open(path).read()
    summary = text.split("=== Summary ===")[-1] if "=== Summary ===" in text else text
    rows = re.findall(r'[^\n]+ AUROC: ([0-9.]+) \| FPR@95TPR: ([0-9.]+)', summary)
    if not rows:
        return "N/A", "N/A"
    best = max(rows, key=lambda x: float(x[0]))
    return best[0], best[1]


def extract_moses(path, method):
    if not os.path.exists(path):
        return "MISSING", "MISSING"
    text = open(path).read()
    m = re.search(rf'{re.escape(method)}\s+([\d.]+)\s+([\d.]+)\s+([\d.]+)', text)
    if not m:
        return "N/A", "N/A"
    return m.group(1), m.group(3)   # AUROC, FPR@95TPR


# 결과 수집
records = []
for ds in DATASETS:
    records.append(("DASA",            ds, *extract_dasa(f"{LOG_DIR}/dasa_{ds}.log")))
    records.append(("DetectGPT",       ds, *extract_detectgpt(f"{LOG_DIR}/detectgpt_{ds}.log")))
    records.append(("Fast-DetectGPT",  ds, *extract_moses(f"{LOG_DIR}/moses_{ds}.log", "fast_detectgpt")))
    records.append(("LASTDE++",        ds, *extract_moses(f"{LOG_DIR}/moses_{ds}.log", "lastde_doubleplus")))
    records.append(("MoSEs(SubCent.)", ds, *extract_moses(f"{LOG_DIR}/moses_{ds}.log", "moses_best")))

# 출력
W = (22, 15, 8, 10)
SEP = "=" * (sum(W) + 9)

print()
print(SEP)
print(f"{'BASELINE COMPARISON SUMMARY':^{sum(W) + 9}}")
print(SEP)
print(f"{'Baseline':<{W[0]}} {'Dataset':<{W[1]}} {'AUROC':>{W[2]}} {'FPR@95':>{W[3]}}")
print("-" * (sum(W) + 9))

prev_ds = None
for baseline, ds, auroc, fpr in records:
    if prev_ds and ds != prev_ds:
        print()
    print(f"{baseline:<{W[0]}} {ds:<{W[1]}} {auroc:>{W[2]}} {fpr:>{W[3]}}")
    prev_ds = ds

print(SEP)
print(f"상세 로그: {LOG_DIR}/")
print()
PYEOF
