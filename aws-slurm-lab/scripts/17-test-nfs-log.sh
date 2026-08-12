#!/bin/bash
##############################################################################
# 17-test-nfs-log.sh
# controller(slurm-ctrl)에서 실행
# 용도: NFS 공유 로그 저장 검증
#   - Job output이 /shared/slurm-logs에 정상 저장되는지 확인
#   - 모든 노드에서 같은 경로로 접근 가능한지 확인
##############################################################################
set -euo pipefail

echo "============================================================"
echo " NFS 로그 저장 검증"
echo "============================================================"

echo ""
echo "===== [1/3] 각 노드에서 NFS 쓰기 Job ====="
cat >/shared/templates/nfs-write-test.sbatch <<'EOF'
#!/bin/bash
#SBATCH --job-name=nfs-write
#SBATCH --partition=debug
#SBATCH --nodes=2
#SBATCH --ntasks=2
#SBATCH --output=/shared/slurm-logs/nfs-write-%j.out

srun --input=none bash -lc '
  TESTFILE="/shared/slurm-logs/nfs-from-$(hostname)-$(date +%s).txt"
  echo "host=$(hostname) writing to ${TESTFILE}"
  echo "Written by $(hostname) at $(date)" > "${TESTFILE}"
  echo "file created: ${TESTFILE}"
'
EOF

JOB_ID=$(sbatch /shared/templates/nfs-write-test.sbatch | awk '{print $NF}')
echo "제출됨: Job ID = ${JOB_ID}"
sleep 10

echo ""
echo "===== [2/3] Job 결과 확인 ====="
if [ -f "/shared/slurm-logs/nfs-write-${JOB_ID}.out" ]; then
  cat "/shared/slurm-logs/nfs-write-${JOB_ID}.out"
else
  echo "❌ output 파일 없음"
fi

echo ""
echo "===== [3/3] NFS 공유 디렉터리 상태 ====="
echo "--- /shared/slurm-logs 전체 ---"
ls -alt /shared/slurm-logs/ | head -20
echo ""
echo "정상 기준:"
echo "  - nfs-from-slurm-c1-*.txt, nfs-from-slurm-c2-*.txt 파일 존재"
echo "  - controller에서 compute가 쓴 파일을 볼 수 있음"
echo "  - 모든 Job output(.out)이 이 경로에 저장됨"

echo ""
echo "============================================================"
echo " NFS 로그 저장 검증 완료"
echo "============================================================"
