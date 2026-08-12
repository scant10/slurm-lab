#!/bin/bash
##############################################################################
# 06-smoke-test.sh
# controller(slurm-ctrl)에서 실행
# 용도: CPU Slurm smoke test
##############################################################################
set -euo pipefail

echo "===== [1/4] 클러스터 상태 확인 ====="
echo "--- sinfo ---"
sinfo

echo ""
echo "--- scontrol show nodes ---"
scontrol show nodes

echo ""
echo "--- sinfo -R (문제 노드 확인) ---"
sinfo -R || true

echo ""
echo "===== [2/4] srun 테스트 ====="
echo "--- 단일 노드 hostname ---"
srun --input=none hostname

echo ""
echo "--- 2-node hostname ---"
srun --input=none --nodes=2 --ntasks=2 hostname

echo ""
echo "===== [3/4] sbatch 테스트 ====="
cat >/shared/templates/hello-slurm.sbatch <<'EOF'
#!/bin/bash
#SBATCH --job-name=hello-slurm
#SBATCH --partition=debug
#SBATCH --nodes=2
#SBATCH --ntasks=2
#SBATCH --output=/shared/slurm-logs/hello-slurm-%j.out

echo "job_id=${SLURM_JOB_ID}"
date
srun --input=none bash -lc 'echo "rank=${SLURM_PROCID} host=$(hostname)"'
EOF

sbatch /shared/templates/hello-slurm.sbatch
echo "10초 대기..."
sleep 10

echo ""
echo "--- squeue ---"
squeue

echo ""
echo "--- Job 결과 확인 ---"
ls -al /shared/slurm-logs/hello-slurm-*.out 2>/dev/null || echo "아직 output 파일 없음"
cat /shared/slurm-logs/hello-slurm-*.out 2>/dev/null || echo "output 내용 없음"

echo ""
echo "===== [4/4] 결과 판정 ====="
if ls /shared/slurm-logs/hello-slurm-*.out >/dev/null 2>&1; then
  echo "✅ CPU Slurm smoke test 성공"
else
  echo "❌ smoke test 실패 - sinfo -R, journalctl -u slurmd 확인 필요"
fi

echo "===== 06-smoke-test 완료 ====="
