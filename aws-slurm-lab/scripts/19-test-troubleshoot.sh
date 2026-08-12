#!/bin/bash
##############################################################################
# 19-test-troubleshoot.sh
# controller(slurm-ctrl)에서 실행
# 용도: 문제 진단용 정보 수집 (트러블슈팅 시 사용)
##############################################################################
set -euo pipefail

echo "============================================================"
echo " 트러블슈팅 정보 수집"
echo "============================================================"

echo ""
echo "===== [1/8] slurmctld 서비스 상태 ====="
sudo systemctl status slurmctld --no-pager 2>&1 || true

echo ""
echo "===== [2/8] slurmctld 최근 로그 ====="
sudo journalctl -u slurmctld -n 30 --no-pager 2>&1 || true

echo ""
echo "===== [3/8] slurm.conf 내용 ====="
cat /etc/slurm/slurm.conf

echo ""
echo "===== [4/8] gres.conf 내용 ====="
cat /etc/slurm/gres.conf 2>/dev/null || echo "(gres.conf 없음 - CPU 모드)"

echo ""
echo "===== [5/8] Munge 상태 ====="
sudo systemctl status munge --no-pager 2>&1 || true
echo ""
munge -n | unmunge 2>&1 || echo "Munge 인증 실패"

echo ""
echo "===== [6/8] 노드 상태 상세 ====="
sinfo -Nel 2>&1 || true
echo ""
sinfo -R 2>&1 || true

echo ""
echo "===== [7/8] scontrol show nodes ====="
scontrol show nodes 2>&1 || true

echo ""
echo "===== [8/8] 네트워크 연결 확인 ====="
echo "--- slurm-c1 ping ---"
ping -c 2 -W 3 slurm-c1 2>&1 || echo "slurm-c1 ping 실패"
echo ""
echo "--- slurm-c2 ping ---"
ping -c 2 -W 3 slurm-c2 2>&1 || echo "slurm-c2 ping 실패"
echo ""
echo "--- NFS mount ---"
df -h /shared 2>&1 || echo "/shared 미마운트"

echo ""
echo "============================================================"
echo " 트러블슈팅 정보 수집 완료"
echo " 위 출력을 확인하여 문제를 진단하세요."
echo ""
echo " 일반적인 확인 순서:"
echo "   1. Munge 인증 실패 → munge key 동기화 문제"
echo "   2. 노드 down/drain → slurmd 미실행 또는 hostname 불일치"
echo "   3. invalid_reg → slurm.conf의 자원값과 실제 값 불일치"
echo "   4. NFS 접근 불가 → nfs-server 미실행 또는 mount 실패"
echo "============================================================"
