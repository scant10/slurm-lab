#!/bin/bash
##############################################################################
# 17-test-nfs-log.sh
# controller(slurm-ctrl)에서 실행
# 용도: NFS 공유 로그 저장 검증
#
# NFS는 Slurm 운영에서 중요하다:
# - Job script를 모든 노드가 같은 경로에서 읽을 수 있어야 한다.
# - Job output을 controller에서 확인하려면 공유 경로가 필요하다.
# - NFS가 없으면 각 compute 노드에 SSH로 접속해서 결과를 봐야 한다.
#
# 이 스크립트는 compute 노드에서 실행된 Job이
# NFS 공유 경로에 파일을 쓰고, controller에서 읽을 수 있는지 검증한다.
##############################################################################
set -euo pipefail

echo "============================================================"
echo " NFS 로그 저장 검증"
echo "============================================================"

echo ""
echo "===== [1/3] 각 노드에서 NFS 쓰기 Job ====="
# 2개 노드에서 동시에 /shared/slurm-logs에 파일을 생성한다.
# 각 노드가 독립적으로 파일을 쓸 수 있으면 NFS가 정상이다.
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
# output 파일도 /shared/slurm-logs에 저장된다.
# 이 파일이 controller에서 보이면 = NFS를 통해 결과가 공유되고 있다.
if [ -f "/shared/slurm-logs/nfs-write-${JOB_ID}.out" ]; then
  cat "/shared/slurm-logs/nfs-write-${JOB_ID}.out"
else
  echo "❌ output 파일 없음"
fi

echo ""
echo "===== [3/3] NFS 공유 디렉터리 상태 ====="
# controller에서 ls로 보이는 파일들 중:
# - nfs-from-slurm-c1-*.txt: c1에서 생성한 파일
# - nfs-from-slurm-c2-*.txt: c2에서 생성한 파일
# 둘 다 보이면 = 양쪽 compute가 NFS에 쓸 수 있고, controller가 읽을 수 있다.
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
