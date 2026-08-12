#!/bin/bash
##############################################################################
# 11-test-cpu-srun.sh
# controller(slurm-ctrl)에서 실행
# 용도: srun 기반 CPU Job 즉시 실행 테스트
##############################################################################
set -euo pipefail

echo "============================================================"
echo " CPU srun 테스트"
echo "============================================================"

echo ""
echo "===== [1/4] 단일 노드 hostname ====="
srun --input=none hostname
echo ""
echo "정상 기준: slurm-c1 또는 slurm-c2 출력"

echo ""
echo "===== [2/4] 2-node hostname ====="
srun --input=none --nodes=2 --ntasks=2 hostname
echo ""
echo "정상 기준: slurm-c1, slurm-c2 두 줄 출력"

echo ""
echo "===== [3/4] CPU 요청 ====="
srun --input=none --cpus-per-task=2 bash -c 'echo "host=$(hostname) cpus=$(nproc)"'
echo ""
echo "정상 기준: cpus=2 출력"

echo ""
echo "===== [4/4] 환경변수 전달 확인 ====="
srun --input=none bash -c 'echo "JOB_ID=${SLURM_JOB_ID} NODE=${SLURMD_NODENAME} TASK=${SLURM_PROCID}"'
echo ""
echo "정상 기준: JOB_ID, NODE, TASK 값이 모두 표시됨"

echo ""
echo "============================================================"
echo " CPU srun 테스트 완료"
echo "============================================================"
