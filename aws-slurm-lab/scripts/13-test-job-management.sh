#!/bin/bash
##############################################################################
# 13-test-job-management.sh
# controller(slurm-ctrl)에서 실행
# 용도: Job 관리 명령어 테스트 (squeue, scancel, scontrol show job)
##############################################################################
set -euo pipefail

echo "============================================================"
echo " Job 관리 명령어 테스트"
echo "============================================================"

echo ""
echo "===== [1/5] 오래 실행되는 Job 제출 ====="
cat >/shared/templates/test-long.sbatch <<'EOF'
#!/bin/bash
#SBATCH --job-name=test-long
#SBATCH --partition=debug
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --output=/shared/slurm-logs/test-long-%j.out

echo "시작: $(date)"
sleep 120
echo "종료: $(date)"
EOF

JOB_ID=$(sbatch /shared/templates/test-long.sbatch | awk '{print $NF}')
echo "제출됨: Job ID = ${JOB_ID}"
sleep 3

echo ""
echo "===== [2/5] squeue - 실행 중 Job 확인 ====="
squeue
echo ""
echo "정상 기준: Job ${JOB_ID}이 R(Running) 상태로 보임"

echo ""
echo "===== [3/5] scontrol show job - Job 상세 정보 ====="
scontrol show job "${JOB_ID}"
echo ""
echo "정상 기준: JobState=RUNNING, NumNodes=1, Partition=debug 등 표시"

echo ""
echo "===== [4/5] scancel - Job 취소 ====="
scancel "${JOB_ID}"
sleep 2
echo "scancel 실행 완료"

echo ""
echo "--- 취소 후 squeue ---"
squeue
echo ""
echo "정상 기준: Job ${JOB_ID}이 squeue에서 사라짐"

echo ""
echo "===== [5/5] 취소된 Job 결과 파일 확인 ====="
if [ -f "/shared/slurm-logs/test-long-${JOB_ID}.out" ]; then
  cat "/shared/slurm-logs/test-long-${JOB_ID}.out"
  echo ""
  echo "정상 기준: '시작' 출력만 있고 '종료'는 없음 (중간에 취소됨)"
else
  echo "output 파일 없음 (Job이 시작 전에 취소되었을 수 있음)"
fi

echo ""
echo "============================================================"
echo " Job 관리 명령어 테스트 완료"
echo "============================================================"
