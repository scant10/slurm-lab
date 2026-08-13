#!/bin/bash
##############################################################################
# 11-test-cpu-srun.sh
# controller(slurm-ctrl)에서 실행
# 용도: srun 기반 CPU Job 즉시 실행 테스트
#
# srun은 Slurm을 통해 명령을 "즉시" 실행하는 명령이다.
# 사용자가 직접 compute 노드에 SSH하지 않고도,
# Slurm이 자원이 있는 노드를 찾아 명령을 배치/실행해준다.
##############################################################################
set -euo pipefail

echo "============================================================"
echo " CPU srun 테스트"
echo "============================================================"

echo ""
echo "===== [1/4] 단일 노드 hostname ====="
# 가장 기본적인 테스트. Slurm에게 "아무 노드 하나에서 hostname을 실행해줘"라고 요청한다.
# --input=none: 표준입력을 비활성화 (스크립트 실행 시 필요)
# 성공하면 slurm-c1 또는 slurm-c2 중 하나가 출력된다.
# 이것이 성공 = "Slurm이 살아있고, compute 노드에 Job을 보낼 수 있다"
srun --input=none hostname
echo ""
echo "정상 기준: slurm-c1 또는 slurm-c2 출력"

echo ""
echo "===== [2/4] 2-node hostname ====="
# 2대의 노드를 동시에 사용하는 Job을 요청한다.
# --nodes=2: 반드시 2개 노드를 할당해라
# --ntasks=2: 총 2개의 task(프로세스)를 실행해라
# 성공하면 slurm-c1, slurm-c2 두 줄이 출력된다.
# 이것이 성공 = "멀티노드 Job 스케줄링이 정상 동작한다"
srun --input=none --nodes=2 --ntasks=2 hostname
echo ""
echo "정상 기준: slurm-c1, slurm-c2 두 줄 출력"

echo ""
echo "===== [3/4] CPU 요청 ====="
# 특정 CPU 수를 요청하는 테스트.
# --cpus-per-task=2: 이 task에 CPU 2개를 할당해라
# nproc: 할당된 CPU 수를 확인하는 명령
# Slurm이 요청한 만큼의 CPU를 실제로 할당했는지 검증한다.
srun --input=none --cpus-per-task=2 bash -c 'echo "host=$(hostname) cpus=$(nproc)"'
echo ""
echo "정상 기준: cpus=2 출력"

echo ""
echo "===== [4/4] 환경변수 전달 확인 ====="
# Slurm은 Job 실행 시 다양한 환경변수를 자동으로 설정한다.
# SLURM_JOB_ID: Slurm이 부여한 고유 Job 번호
# SLURMD_NODENAME: 실제 실행된 compute 노드 이름
# SLURM_PROCID: 이 task의 rank 번호 (멀티 task 시 0,1,2...)
# 이 변수들이 보이면 Slurm이 Job 컨텍스트를 정상 전달한 것이다.
srun --input=none bash -c 'echo "JOB_ID=${SLURM_JOB_ID} NODE=${SLURMD_NODENAME} TASK=${SLURM_PROCID}"'
echo ""
echo "정상 기준: JOB_ID, NODE, TASK 값이 모두 표시됨"

echo ""
echo "============================================================"
echo " CPU srun 테스트 완료"
echo "============================================================"
