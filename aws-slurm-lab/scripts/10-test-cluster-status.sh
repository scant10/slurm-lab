#!/bin/bash
##############################################################################
# 10-test-cluster-status.sh
# controller(slurm-ctrl)에서 실행
# 용도: Slurm 클러스터 상태 전체 점검
##############################################################################
set -euo pipefail

echo "============================================================"
echo " Slurm 클러스터 상태 점검"
echo "============================================================"

echo ""
echo "===== [1/6] slurmctld 서비스 상태 ====="
sudo systemctl status slurmctld --no-pager
echo ""
echo "정상 기준: active (running)"

echo ""
echo "===== [2/6] 파티션 및 노드 상태 (sinfo) ====="
sinfo
echo ""
echo "정상 기준: debug 파티션 up, slurm-c[1-2] idle"

echo ""
echo "===== [3/6] 노드 상세 정보 (scontrol show nodes) ====="
scontrol show nodes
echo ""
echo "정상 기준: State=IDLE, CPUTot=2, RealMemory=1600"

echo ""
echo "===== [4/6] 문제 노드 확인 (sinfo -R) ====="
sinfo -R || true
echo ""
echo "정상 기준: 헤더만 출력되고 내용 없음 = 문제 노드 없음"

echo ""
echo "===== [5/6] Munge 인증 확인 ====="
munge -n | unmunge
echo ""
echo "정상 기준: STATUS: Success"

echo ""
echo "===== [6/6] NFS 공유 경로 확인 ====="
ls -al /shared/slurm-logs/
echo ""
echo "정상 기준: compute 노드에서 생성한 *-nfs-test.txt 파일 보임"

echo ""
echo "============================================================"
echo " 점검 완료"
echo "============================================================"
