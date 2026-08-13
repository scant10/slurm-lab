#!/bin/bash
##############################################################################
# 15-test-fake-gpu.sh
# controller(slurm-ctrl)에서 실행
# 용도: fake GPU GRES 구성 및 GPU 스케줄링 테스트
#
# 실제 GPU가 없는 환경에서 Slurm의 GPU 스케줄링 로직을 검증한다.
# /tmp에 가짜 파일을 만들어 GPU device처럼 사용한다.
# Slurm은 파일 존재 여부만 확인하므로 실제 GPU 없이도 GRES 동작을 테스트할 수 있다.
#
# 주의: 이 스크립트는 slurm.conf를 GPU 버전으로 교체한다.
#       CPU smoke test(06)가 성공한 후에 실행하세요.
##############################################################################
set -euo pipefail

echo "============================================================"
echo " Fake GPU GRES 구성 및 테스트"
echo "============================================================"

echo ""
echo "===== [1/6] compute 노드에 fake GPU file 생성 안내 ====="
# Slurm gres.conf에서 File=/tmp/slurm-fake-gpu[0-7]로 지정할 것이다.
# 이 파일들이 compute 노드에 존재해야 slurmd가 GPU를 인식한다.
# 실제 환경에서는 /dev/nvidia[0-7]이 이 역할을 한다.
echo "각 compute 노드(slurm-c1, slurm-c2)에서 아래 명령을 먼저 실행하세요:"
echo ""
echo '  for i in $(seq 0 7); do sudo touch "/tmp/slurm-fake-gpu${i}"; done'
echo '  sudo chmod 666 /tmp/slurm-fake-gpu[0-7]'
echo ""
read -p "compute 노드에서 fake GPU file을 생성했습니까? (y/n): " CONFIRM
if [ "$CONFIRM" != "y" ]; then
  echo "compute 노드에서 먼저 fake GPU file을 만든 후 다시 실행하세요."
  exit 0
fi

echo ""
echo "===== [2/6] GPU slurm.conf 작성 ====="
# 기존 CPU-only slurm.conf를 백업하고 GPU 포함 버전으로 교체한다.
sudo cp /etc/slurm/slurm.conf /etc/slurm/slurm.conf.bak.cpu

# GresTypes=gpu: Slurm에 "gpu라는 자원 유형이 있다"고 선언
# Gres=gpu:b200:8: 이 노드에 b200 타입 GPU가 8개 있다고 선언
# 파티션을 용도별로 나눔:
#   gpu-debug: 짧은 테스트용 (2시간 제한)
#   gpu-train: 학습용 (1일 제한)
#   gpu-eval: 평가용 (12시간 제한)
cat >/tmp/slurm-gpu.conf <<'EOF'
# Slurm Manual Lab - GPU GRES 구성 (fake GPU)
ClusterName=aws-slurm-lab
SlurmctldHost=slurm-ctrl
SlurmUser=slurm

AuthType=auth/munge
CryptoType=crypto/munge
ProctrackType=proctrack/linuxproc
MpiDefault=none
ReturnToService=1

SlurmctldPidFile=/run/slurmctld.pid
SlurmdPidFile=/run/slurmd.pid
SlurmdSpoolDir=/var/spool/slurmd
StateSaveLocation=/var/spool/slurmctld
SlurmctldLogFile=/var/log/slurm/slurmctld.log
SlurmdLogFile=/var/log/slurm/slurmd.log

SwitchType=switch/none
TaskPlugin=task/none
SchedulerType=sched/backfill
SelectType=select/cons_tres

# GPU GRES 선언
GresTypes=gpu

# 노드 정의 - fake GPU 8개씩
NodeName=slurm-c1 CPUs=2 RealMemory=1600 Gres=gpu:b200:8 State=UNKNOWN
NodeName=slurm-c2 CPUs=2 RealMemory=1600 Gres=gpu:b200:8 State=UNKNOWN

# 파티션 정의
PartitionName=debug Nodes=slurm-c[1-2] Default=YES MaxTime=INFINITE State=UP
PartitionName=gpu-debug Nodes=slurm-c[1-2] MaxTime=02:00:00 State=UP
PartitionName=gpu-train Nodes=slurm-c[1-2] MaxTime=1-00:00:00 State=UP
PartitionName=gpu-eval Nodes=slurm-c[1-2] MaxTime=12:00:00 State=UP
EOF

# gres.conf: 각 노드의 GPU device file 위치를 지정한다.
# File=/tmp/slurm-fake-gpu[0-7]: 8개 fake GPU device
# 실제 환경에서는 File=/dev/nvidia[0-7]로 바뀐다.
cat >/tmp/gres.conf <<'EOF'
NodeName=slurm-c1 Name=gpu Type=b200 File=/tmp/slurm-fake-gpu[0-7]
NodeName=slurm-c2 Name=gpu Type=b200 File=/tmp/slurm-fake-gpu[0-7]
EOF

sudo install -o slurm -g slurm -m 0644 /tmp/slurm-gpu.conf /etc/slurm/slurm.conf
sudo install -o slurm -g slurm -m 0644 /tmp/gres.conf /etc/slurm/gres.conf
sudo cp /etc/slurm/slurm.conf /shared/slurm.conf
sudo cp /etc/slurm/gres.conf /shared/gres.conf

echo "GPU slurm.conf, gres.conf 작성 완료"

echo ""
echo "===== [3/6] 서비스 재시작 ====="
# 설정 변경 후 slurmctld를 재시작해야 새 설정이 반영된다.
echo "controller slurmctld 재시작..."
sudo systemctl restart slurmctld

echo ""
echo "compute 노드에서 아래 명령을 실행하세요:"
echo '  sudo install -o slurm -g slurm -m 0644 /shared/slurm.conf /etc/slurm/slurm.conf'
echo '  sudo install -o slurm -g slurm -m 0644 /shared/gres.conf /etc/slurm/gres.conf'
echo '  sudo systemctl restart slurmd'
echo ""
read -p "compute 노드에서 slurmd를 재시작했습니까? (y/n): " CONFIRM2
if [ "$CONFIRM2" != "y" ]; then
  echo "compute 노드 재시작 후 이 스크립트를 다시 실행하세요."
  exit 0
fi

echo ""
echo "30초 대기 (노드 등록 대기)..."
# slurmd가 재시작되면 slurmctld에 자신의 자원을 보고한다.
# 이 과정이 완료되어야 노드가 idle 상태가 된다.
sleep 30

echo ""
echo "===== [4/6] GPU GRES 등록 확인 ====="
echo "--- sinfo -Nel ---"
# -N: 노드별 한 줄씩, -e: 파티션 정보 포함, -l: 상세 포맷
sinfo -Nel
echo ""
echo "--- GRES 확인 ---"
# scontrol show nodes에서 Gres=와 CfgTRES= 라인을 확인한다.
# Gres=gpu:b200:8 → 노드가 GPU 8개를 등록했다는 뜻
# CfgTRES에 gres/gpu=8 → 스케줄러가 GPU를 자원으로 인식했다는 뜻
scontrol show nodes | grep -E 'NodeName=|Gres=|CfgTRES=|State='
echo ""
echo "정상 기준: Gres=gpu:b200:8, CfgTRES에 gres/gpu=8 포함"

echo ""
echo "===== [5/6] GPU Job 실행 테스트 ====="
echo "--- GPU 1개 요청 ---"
# --gres=gpu:b200:1: b200 타입 GPU 1개를 이 Job에 할당해달라
# CUDA_VISIBLE_DEVICES: Slurm이 설정하는 환경변수로,
#   할당된 GPU의 index를 알려준다 (예: 0, 또는 0,1,2...)
# 실제 환경에서는 PyTorch가 이 변수를 보고 해당 GPU만 사용한다.
srun --input=none --partition=gpu-debug --gres=gpu:b200:1 \
  bash -lc 'echo "host=$(hostname) CUDA_VISIBLE_DEVICES=${CUDA_VISIBLE_DEVICES:-unset}"'
echo ""
echo "정상 기준: hostname 출력 + CUDA_VISIBLE_DEVICES 값 표시"

echo ""
echo "--- GPU 8개 요청 ---"
# 노드의 전체 GPU(8개)를 요청한다.
# CUDA_VISIBLE_DEVICES에 0,1,2,3,4,5,6,7이 표시되어야 한다.
srun --input=none --partition=gpu-debug --gres=gpu:b200:8 \
  bash -lc 'echo "host=$(hostname) CUDA_VISIBLE_DEVICES=${CUDA_VISIBLE_DEVICES:-unset}"'
echo ""
echo "정상 기준: 8개 GPU 할당, CUDA_VISIBLE_DEVICES에 0-7 표시"

echo ""
echo "===== [6/6] GPU 초과 요청 거부 테스트 ====="
echo "--- GPU 9개 요청 (노드당 8개인데 9개) ---"
# 노드당 GPU가 8개인데 9개를 요청한다.
# 어떤 단일 노드도 9개를 제공할 수 없으므로 거부되어야 한다.
# 이것이 통과하면 GPU 자원 보호가 안 되고 있다는 뜻이다.
srun --input=none --partition=gpu-debug --gres=gpu:b200:9 --immediate=10 \
  bash -lc 'hostname' \
  && echo "❌ UNEXPECTED_ACCEPTED" \
  || echo "✅ EXPECTED_REJECTED (노드당 GPU 8개 초과)"

echo ""
echo "============================================================"
echo " Fake GPU GRES 테스트 완료"
echo "============================================================"
