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
# slurmctld는 Slurm의 중앙 스케줄러 데몬이다.
# active (running)이어야 Job을 받고 배치할 수 있다.
# 이것이 죽어 있으면 클러스터 전체가 Job을 처리할 수 없다.
sudo systemctl status slurmctld --no-pager
echo ""
echo "정상 기준: active (running)"

echo ""
echo "===== [2/6] 파티션 및 노드 상태 (sinfo) ====="
# sinfo는 클러스터의 파티션(자원 그룹)과 노드 상태를 한눈에 보여준다.
# PARTITION: 노드를 묶은 그룹 이름 (예: debug, gpu)
# AVAIL: up이면 파티션이 활성 상태
# STATE: idle(비어있음), alloc(사용중), down(장애), drain(유지보수)
# idle = Job을 받을 수 있는 정상 상태
sinfo
echo ""
echo "정상 기준: debug 파티션 up, slurm-c[1-2] idle"

echo ""
echo "===== [3/6] 노드 상세 정보 (scontrol show nodes) ====="
# scontrol show nodes는 각 노드의 상세 자원 정보를 보여준다.
# CPUTot: 총 CPU 수
# RealMemory: Slurm이 인식한 메모리 (MB)
# State: 노드 상태
# Gres: 등록된 GPU 등 특수 자원
# 여기서 slurm.conf에 적은 값과 실제 하드웨어가 일치하는지 확인한다.
scontrol show nodes
echo ""
echo "정상 기준: State=IDLE, CPUTot=2, RealMemory=1600"

echo ""
echo "===== [4/6] 문제 노드 확인 (sinfo -R) ====="
# sinfo -R은 down, drain, fail 상태인 노드의 "이유(reason)"를 보여준다.
# 결과가 비어 있으면 = 문제 있는 노드가 없다는 뜻이다.
# reason이 표시되면 해당 노드에 무슨 문제가 있는지 알려주는 단서다.
sinfo -R || true
echo ""
echo "정상 기준: 헤더만 출력되고 내용 없음 = 문제 노드 없음"

echo ""
echo "===== [5/6] Munge 인증 확인 ====="
# Munge는 Slurm 노드 간 통신을 인증하는 서비스다.
# munge -n: 인증 토큰을 생성한다.
# unmunge: 생성된 토큰을 검증(디코딩)한다.
# STATUS: Success가 나오면 이 노드의 Munge 인증이 정상 동작한다는 뜻이다.
# 실패하면 munge key 불일치, munged 미실행, 권한 문제 등을 의심한다.
munge -n | unmunge
echo ""
echo "정상 기준: STATUS: Success"

echo ""
echo "===== [6/6] NFS 공유 경로 확인 ====="
# NFS는 모든 노드가 같은 파일을 보기 위한 공유 스토리지다.
# /shared/slurm-logs에 compute 노드에서 만든 파일이 보이면
# controller와 compute가 같은 경로를 공유하고 있다는 뜻이다.
# Job output 파일도 여기에 저장되므로, NFS가 안 되면 결과를 볼 수 없다.
ls -al /shared/slurm-logs/
echo ""
echo "정상 기준: compute 노드에서 생성한 *-nfs-test.txt 파일 보임"

echo ""
echo "============================================================"
echo " 점검 완료"
echo "============================================================"
