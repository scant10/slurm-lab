#!/bin/bash
##############################################################################
# 19-test-troubleshoot.sh
# controller(slurm-ctrl)에서 실행
# 용도: 문제 진단용 정보 수집 (트러블슈팅 시 사용)
#
# Slurm에서 문제가 생기면 이 스크립트를 실행해서
# 한번에 진단에 필요한 정보를 수집한다.
# 각 섹션이 무엇을 확인하는지 주석으로 설명한다.
##############################################################################
set -euo pipefail

echo "============================================================"
echo " 트러블슈팅 정보 수집"
echo "============================================================"

echo ""
echo "===== [1/8] slurmctld 서비스 상태 ====="
# slurmctld가 죽어있으면 모든 Job 제출/스케줄링이 불가능하다.
# active (running)이 아니면 여기서부터 고쳐야 한다.
sudo systemctl status slurmctld --no-pager 2>&1 || true

echo ""
echo "===== [2/8] slurmctld 최근 로그 ====="
# slurmctld 데몬의 최근 로그 30줄을 본다.
# error, fatal, warning 키워드를 찾으면 된다.
# 자주 보이는 에러: slurm.conf 문법 오류, 노드 통신 실패, 인증 실패
sudo journalctl -u slurmctld -n 30 --no-pager 2>&1 || true

echo ""
echo "===== [3/8] slurm.conf 내용 ====="
# 현재 적용된 slurm.conf를 확인한다.
# 노드 이름, CPU 수, 메모리, GRES 설정이 올바른지 본다.
cat /etc/slurm/slurm.conf

echo ""
echo "===== [4/8] gres.conf 내용 ====="
# GPU 설정 파일. GPU 구성이 없으면 파일 자체가 없을 수 있다.
# NodeName, Name=gpu, File= 경로가 실제 device와 일치하는지 확인한다.
cat /etc/slurm/gres.conf 2>/dev/null || echo "(gres.conf 없음 - CPU 모드)"

echo ""
echo "===== [5/8] Munge 상태 ====="
# Munge 인증이 실패하면 노드 간 통신이 전부 안 된다.
# "Invalid job credential", "Security violation" 에러의 원인이 대부분 여기다.
sudo systemctl status munge --no-pager 2>&1 || true
echo ""
munge -n | unmunge 2>&1 || echo "Munge 인증 실패"

echo ""
echo "===== [6/8] 노드 상태 상세 ====="
# sinfo -Nel: 모든 노드의 상태를 한 줄씩 상세히 보여준다.
# sinfo -R: down/drain 노드의 reason을 보여준다.
# reason이 "Not responding"이면 네트워크 또는 slurmd 문제,
# "Invalid registration"이면 slurm.conf와 실제 하드웨어 불일치.
sinfo -Nel 2>&1 || true
echo ""
sinfo -R 2>&1 || true

echo ""
echo "===== [7/8] scontrol show nodes ====="
# 각 노드의 전체 정보를 덤프한다.
# State, Reason, CPUTot, RealMemory, Gres, CfgTRES를 확인한다.
scontrol show nodes 2>&1 || true

echo ""
echo "===== [8/8] 네트워크 연결 확인 ====="
# controller에서 compute 노드로 ping이 되는지 확인한다.
# ping 실패 = 네트워크/방화벽/호스트명 해석 문제
echo "--- slurm-c1 ping ---"
ping -c 2 -W 3 slurm-c1 2>&1 || echo "slurm-c1 ping 실패"
echo ""
echo "--- slurm-c2 ping ---"
ping -c 2 -W 3 slurm-c2 2>&1 || echo "slurm-c2 ping 실패"
echo ""
# NFS mount 확인. /shared가 마운트 안 되어 있으면 Job output을 볼 수 없다.
echo "--- NFS mount ---"
df -h /shared 2>&1 || echo "/shared 미마운트"

echo ""
echo "============================================================"
echo " 트러블슈팅 정보 수집 완료"
echo ""
echo " 일반적인 확인 순서:"
echo "   1. Munge 인증 실패 → munge key 동기화 문제"
echo "   2. 노드 down/drain → slurmd 미실행 또는 hostname 불일치"
echo "   3. invalid_reg → slurm.conf의 자원값과 실제 값 불일치"
echo "   4. NFS 접근 불가 → nfs-server 미실행 또는 mount 실패"
echo "   5. Security violation → slurm UID 불일치 (노드간 동일해야 함)"
echo "============================================================"
