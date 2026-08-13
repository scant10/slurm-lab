#!/bin/bash
##############################################################################
# 16-test-gpu-batch.sh
# controller(slurm-ctrl)에서 실행
# 용도: GPU batch Job 테스트 (단일/2-node GPU Job 포함)
# 선행조건: 15-test-fake-gpu.sh가 성공한 상태
#
# 실제 GPU 학습 워크로드는 대부분 sbatch로 제출한다.
# 이 스크립트는 GPU가 할당된 batch Job이 정상 동작하는지 확인한다.
##############################################################################
set -euo pipefail

echo "============================================================"
echo " GPU Batch Job 테스트"
echo "============================================================"

echo ""
echo "===== [1/3] 단일 노드 GPU batch Job ====="
# --gres=gpu:b200:4: 한 노드에서 GPU 4개를 할당받는 Job
# 실제 학습에서는 모델 크기에 따라 GPU 수를 조절한다.
# CUDA_VISIBLE_DEVICES에 4개의 GPU index가 표시되어야 한다.
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
# 분산 학습의 핵심 시나리오: 2대의 노드에서 각각 GPU 8개씩 사용.
# 총 16개 GPU를 사용하는 멀티노드 학습을 시뮬레이션한다.
# rank=0은 노드1, rank=1은 노드2에서 실행되어야 한다.
# 각 rank에서 CUDA_VISIBLE_DEVICES가 표시되면
# Slurm이 노드별로 GPU를 올바르게 배분한 것이다.
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
