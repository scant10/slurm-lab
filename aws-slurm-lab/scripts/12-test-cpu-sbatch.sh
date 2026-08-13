#!/bin/bash
##############################################################################
# 12-test-cpu-sbatch.sh
# controller(slurm-ctrl)에서 실행
# 용도: sbatch 기반 batch Job 제출 및 결과 확인
#
# sbatch는 srun과 달리 "백그라운드"로 Job을 제출한다.
# 실행이 끝날 때까지 기다리지 않고, Job ID만 받고 돌아온다.
# 결과는 지정한 output 파일에 저장된다.
# 실제 운영에서 학습 작업은 대부분 sbatch로 제출한다.
##############################################################################
set -euo pipefail

echo "============================================================"
echo " CPU sbatch 테스트"
echo "============================================================"

echo ""
echo "===== [1/3] 단일 노드 batch Job ====="
# .sbatch 파일을 만들어 Job을 제출한다.
# #SBATCH: Slurm에게 전달하는 옵션 (스크립트 안에 선언)
# --job-name: Job 이름 (squeue에서 식별용)
# --partition: 어떤 파티션(자원그룹)에서 실행할지
# --nodes=1: 1개 노드 사용
# --ntasks=1: 1개 task 실행
# --output: 실행 결과를 저장할 파일 경로 (%j는 Job ID로 치환됨)
cat >/shared/templates/test-single.sbatch <<'EOF'
#!/bin/bash
#SBATCH --job-name=test-single
#SBATCH --partition=debug
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --output=/shared/slurm-logs/test-single-%j.out

echo "job_id=${SLURM_JOB_ID}"        # Slurm이 부여한 Job 번호
echo "node=${SLURMD_NODENAME}"        # 실행된 노드 이름
echo "partition=${SLURM_JOB_PARTITION}" # 사용된 파티션
hostname                               # OS에서 본 hostname
date                                   # 실행 시각
uptime                                 # 노드 가동 시간
EOF

# sbatch로 제출하면 "Submitted batch job <ID>" 메시지가 나온다.
# awk로 Job ID만 추출해 변수에 저장한다.
JOB1=$(sbatch /shared/templates/test-single.sbatch | awk '{print $NF}')
echo "제출됨: Job ID = ${JOB1}"

echo ""
echo "===== [2/3] 2-node batch Job ====="
# 2개 노드에 걸친 batch Job.
# srun으로 각 노드에서 병렬 실행한다.
# SLURM_PROCID: 각 task의 순번 (rank). 분산학습에서 rank로 사용.
# SLURM_JOB_NODELIST: 할당된 노드 목록 (예: slurm-c[1-2])
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
# batch Job은 비동기이므로 실행 완료를 기다린다.
sleep 15

echo ""
echo "===== [3/3] 결과 확인 ====="
# squeue: 현재 대기/실행 중인 Job 목록.
# Job이 이미 끝났으면 여기에 안 보인다.
echo "--- squeue (대기/실행 중 Job) ---"
squeue

echo ""
echo "--- 단일 노드 Job 결과 ---"
# output 파일이 생겼으면 Job이 실행되어 결과를 남긴 것이다.
if [ -f "/shared/slurm-logs/test-single-${JOB1}.out" ]; then
  cat "/shared/slurm-logs/test-single-${JOB1}.out"
  echo ""
  echo "✅ 단일 노드 batch Job 성공"
else
  echo "❌ output 파일 미생성 - 실패"
fi

echo ""
echo "--- 2-node Job 결과 ---"
# rank=0과 rank=1이 서로 다른 host에서 출력되면
# 2대의 compute 노드가 동시에 참여한 것이다.
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
