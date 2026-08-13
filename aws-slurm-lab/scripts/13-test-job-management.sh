#!/bin/bash
##############################################################################
# 13-test-job-management.sh
# controller(slurm-ctrl)에서 실행
# 용도: Job 관리 명령어 테스트 (squeue, scancel, scontrol show job)
#
# 실제 운영에서는 Job을 모니터링하고, 문제 있으면 취소하고,
# 상세 정보를 확인하는 작업을 반복한다.
# 이 스크립트는 그 흐름을 검증한다.
##############################################################################
set -euo pipefail

echo "============================================================"
echo " Job 관리 명령어 테스트"
echo "============================================================"

echo ""
echo "===== [1/5] 오래 실행되는 Job 제출 ====="
# sleep 120으로 2분간 실행되는 Job을 만든다.
# 이렇게 해야 Job이 Running 상태에 있는 동안 squeue, scontrol, scancel을 테스트할 수 있다.
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
sleep 3  # Job이 Running 상태로 전환될 시간을 준다

echo ""
echo "===== [2/5] squeue - 실행 중 Job 확인 ====="
# squeue는 현재 Slurm에 등록된 Job(대기 + 실행 중)을 보여준다.
# ST 컬럼: R=Running(실행중), PD=Pending(대기중), CG=Completing(종료중)
# NODELIST: 어떤 노드에서 실행 중인지
# TIME: 얼마나 실행됐는지
squeue
echo ""
echo "정상 기준: Job ${JOB_ID}이 R(Running) 상태로 보임"

echo ""
echo "===== [3/5] scontrol show job - Job 상세 정보 ====="
# scontrol show job은 특정 Job의 모든 정보를 보여준다.
# JobState: 현재 상태 (RUNNING, PENDING, COMPLETED 등)
# NumNodes: 사용 중인 노드 수
# RunTime: 실행 경과 시간
# SubmitTime: 제출 시각
# WorkDir: Job이 실행되는 작업 디렉터리
# Command: 실행된 스크립트 경로
scontrol show job "${JOB_ID}"
echo ""
echo "정상 기준: JobState=RUNNING, NumNodes=1, Partition=debug 등 표시"

echo ""
echo "===== [4/5] scancel - Job 취소 ====="
# scancel은 실행 중이거나 대기 중인 Job을 강제 취소한다.
# 사용 예: 잘못된 설정으로 제출한 Job, 무한루프 Job, 자원 회수 필요 시
# 취소된 Job은 squeue에서 사라지고, output 파일에는 취소 시점까지의 출력만 남는다.
scancel "${JOB_ID}"
sleep 2
echo "scancel 실행 완료"

echo ""
echo "--- 취소 후 squeue ---"
# 취소된 Job은 squeue에서 사라져야 한다.
squeue
echo ""
echo "정상 기준: Job ${JOB_ID}이 squeue에서 사라짐"

echo ""
echo "===== [5/5] 취소된 Job 결과 파일 확인 ====="
# sleep 120 중간에 취소했으므로:
# - "시작" 출력은 있지만
# - "종료" 출력은 없어야 정상 (중간에 죽었으니까)
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
