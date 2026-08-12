#!/bin/bash
##############################################################################
# 12-test-cpu-sbatch.sh
# controller(slurm-ctrl)에서 실행
# 용도: sbatch 기반 batch Job 제출 및 결과 확인
##############################################################################
set -euo pipefail

echo "============================================================"
echo " CPU sbatch 테스트"
echo "============================================================"

echo ""
echo "===== [1/3] 단일 노드 batch Job ====="
cat >/shared/templates/test-single.sbatch <<'EOF'
#!/bin/bash
#SBATCH --job-name=test-single
#SBATCH --partition=debug
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --output=/shared/slurm-logs/test-single-%j.out

echo "job_id=${SLURM_JOB_ID}"
echo "node=${SLURMD_NODENAME}"
echo "partition=${SLURM_JOB_PARTITION}"
hostname
date
uptime
EOF

JOB1=$(sbatch /shared/templates/test-single.sbatch | awk '{print $NF}')
echo "제출됨: Job ID = ${JOB1}"

echo ""
echo "===== [2/3] 2-node batch Job ====="
cat >/shared/templates/test-multi.sbatch <<'EOF'
#!/bin/bash
#SBATCH --job-name=test-multi
#SBATCH --partition=debug
#SBATCH --nodes=2
#SBATCH --ntasks=2
#SBATCH --output=/shared/slurm-logs/test-multi-%j.out

echo "job_id=${SLURM_JOB_ID}"
echo "nodelist=${SLURM_JOB_NODELIST}"
date
srun --input=none bash -lc 'echo "rank=${SLURM_PROCID} host=$(hostname)"'
EOF

JOB2=$(sbatch /shared/templates/test-multi.sbatch | awk '{print $NF}')
echo "제출됨: Job ID = ${JOB2}"

echo ""
echo "15초 대기..."
sleep 15

echo ""
echo "===== [3/3] 결과 확인 ====="
echo "--- squeue (대기/실행 중 Job) ---"
squeue

echo ""
echo "--- 단일 노드 Job 결과 ---"
if [ -f "/shared/slurm-logs/test-single-${JOB1}.out" ]; then
  cat "/shared/slurm-logs/test-single-${JOB1}.out"
  echo ""
  echo "✅ 단일 노드 batch Job 성공"
else
  echo "❌ output 파일 미생성 - 실패"
fi

echo ""
echo "--- 2-node Job 결과 ---"
if [ -f "/shared/slurm-logs/test-multi-${JOB2}.out" ]; then
  cat "/shared/slurm-logs/test-multi-${JOB2}.out"
  echo ""
  echo "✅ 2-node batch Job 성공"
else
  echo "❌ output 파일 미생성 - 실패"
fi

echo ""
echo "정상 기준:"
echo "  - 단일 노드: hostname, date 출력 있음"
echo "  - 2-node: rank=0, rank=1 각각 다른 host에서 출력"
echo ""
echo "============================================================"
echo " CPU sbatch 테스트 완료"
echo "============================================================"
