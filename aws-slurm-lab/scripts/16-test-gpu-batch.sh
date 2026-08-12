#!/bin/bash
##############################################################################
# 16-test-gpu-batch.sh
# controller(slurm-ctrl)에서 실행
# 용도: GPU batch Job 테스트 (2-node GPU Job 포함)
# 선행조건: 15-test-fake-gpu.sh가 성공한 상태
##############################################################################
set -euo pipefail

echo "============================================================"
echo " GPU Batch Job 테스트"
echo "============================================================"

echo ""
echo "===== [1/3] 단일 노드 GPU batch Job ====="
cat >/shared/templates/gpu-single.sbatch <<'EOF'
#!/bin/bash
#SBATCH --job-name=gpu-single
#SBATCH --partition=gpu-debug
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --gres=gpu:b200:4
#SBATCH --output=/shared/slurm-logs/gpu-single-%j.out

echo "job_id=${SLURM_JOB_ID}"
echo "node=${SLURMD_NODENAME}"
echo "partition=${SLURM_JOB_PARTITION}"
echo "gres_requested=gpu:b200:4"
echo "CUDA_VISIBLE_DEVICES=${CUDA_VISIBLE_DEVICES:-unset}"
date
EOF

JOB1=$(sbatch /shared/templates/gpu-single.sbatch | awk '{print $NF}')
echo "제출됨: Job ID = ${JOB1}"

echo ""
echo "===== [2/3] 2-node GPU batch Job ====="
cat >/shared/templates/gpu-two-node.sbatch <<'EOF'
#!/bin/bash
#SBATCH --job-name=gpu-two-node
#SBATCH --partition=gpu-debug
#SBATCH --nodes=2
#SBATCH --ntasks=2
#SBATCH --gres=gpu:b200:8
#SBATCH --output=/shared/slurm-logs/gpu-two-node-%j.out

echo "job_id=${SLURM_JOB_ID}"
echo "nodelist=${SLURM_JOB_NODELIST}"
srun --input=none bash -lc 'echo "rank=${SLURM_PROCID} host=$(hostname) cuda=${CUDA_VISIBLE_DEVICES:-unset}"'
EOF

JOB2=$(sbatch /shared/templates/gpu-two-node.sbatch | awk '{print $NF}')
echo "제출됨: Job ID = ${JOB2}"

echo ""
echo "15초 대기..."
sleep 15

echo ""
echo "===== [3/3] 결과 확인 ====="
echo "--- 단일 노드 GPU Job ---"
if [ -f "/shared/slurm-logs/gpu-single-${JOB1}.out" ]; then
  cat "/shared/slurm-logs/gpu-single-${JOB1}.out"
  echo ""
  echo "✅ 단일 노드 GPU batch 성공"
else
  echo "❌ output 파일 미생성"
fi

echo ""
echo "--- 2-node GPU Job ---"
if [ -f "/shared/slurm-logs/gpu-two-node-${JOB2}.out" ]; then
  cat "/shared/slurm-logs/gpu-two-node-${JOB2}.out"
  echo ""
  echo "✅ 2-node GPU batch 성공"
else
  echo "❌ output 파일 미생성"
fi

echo ""
echo "정상 기준:"
echo "  - 단일 노드: CUDA_VISIBLE_DEVICES에 4개 GPU index 표시"
echo "  - 2-node: 두 node 각각 rank, hostname, cuda 값 출력"
echo ""
echo "============================================================"
echo " GPU Batch Job 테스트 완료"
echo "============================================================"
