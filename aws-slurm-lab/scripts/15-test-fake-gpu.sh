#!/bin/bash
##############################################################################
# 15-test-fake-gpu.sh
# controller(slurm-ctrl)에서 실행
# 용도: fake GPU GRES 구성 및 GPU 스케줄링 테스트
# 주의: 이 스크립트는 slurm.conf를 GPU 버전으로 교체합니다.
#       CPU smoke test(06)가 성공한 후에 실행하세요.
##############################################################################
set -euo pipefail

echo "============================================================"
echo " Fake GPU GRES 구성 및 테스트"
echo "============================================================"

echo ""
echo "===== [1/6] compute 노드에 fake GPU file 생성 안내 ====="
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
sudo cp /etc/slurm/slurm.conf /etc/slurm/slurm.conf.bak.cpu

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

# GPU GRES
GresTypes=gpu

# Nodes - fake GPU 8개씩
NodeName=slurm-c1 CPUs=2 RealMemory=1600 Gres=gpu:b200:8 State=UNKNOWN
NodeName=slurm-c2 CPUs=2 RealMemory=1600 Gres=gpu:b200:8 State=UNKNOWN

# Partitions
PartitionName=debug Nodes=slurm-c[1-2] Default=YES MaxTime=INFINITE State=UP
PartitionName=gpu-debug Nodes=slurm-c[1-2] MaxTime=02:00:00 State=UP
PartitionName=gpu-train Nodes=slurm-c[1-2] MaxTime=1-00:00:00 State=UP
PartitionName=gpu-eval Nodes=slurm-c[1-2] MaxTime=12:00:00 State=UP
EOF

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
sleep 30

echo ""
echo "===== [4/6] GPU GRES 등록 확인 ====="
echo "--- sinfo -Nel ---"
sinfo -Nel
echo ""
echo "--- GRES 확인 ---"
scontrol show nodes | grep -E 'NodeName=|Gres=|CfgTRES=|State='
echo ""
echo "정상 기준: Gres=gpu:b200:8, CfgTRES에 gres/gpu=8 포함"

echo ""
echo "===== [5/6] GPU Job 실행 테스트 ====="
echo "--- GPU 1개 요청 ---"
srun --input=none --partition=gpu-debug --gres=gpu:b200:1 \
  bash -lc 'echo "host=$(hostname) CUDA_VISIBLE_DEVICES=${CUDA_VISIBLE_DEVICES:-unset}"'
echo ""
echo "정상 기준: hostname 출력 + CUDA_VISIBLE_DEVICES 값 표시"

echo ""
echo "--- GPU 8개 요청 ---"
srun --input=none --partition=gpu-debug --gres=gpu:b200:8 \
  bash -lc 'echo "host=$(hostname) CUDA_VISIBLE_DEVICES=${CUDA_VISIBLE_DEVICES:-unset}"'
echo ""
echo "정상 기준: 8개 GPU 할당, CUDA_VISIBLE_DEVICES에 0-7 표시"

echo ""
echo "===== [6/6] GPU 초과 요청 거부 테스트 ====="
echo "--- GPU 9개 요청 (노드당 8개인데 9개) ---"
srun --input=none --partition=gpu-debug --gres=gpu:b200:9 --immediate=10 \
  bash -lc 'hostname' \
  && echo "❌ UNEXPECTED_ACCEPTED" \
  || echo "✅ EXPECTED_REJECTED (노드당 GPU 8개 초과)"

echo ""
echo "============================================================"
echo " Fake GPU GRES 테스트 완료"
echo "============================================================"
