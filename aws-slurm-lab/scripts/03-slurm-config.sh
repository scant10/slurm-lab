#!/bin/bash
##############################################################################
# 03-slurm-config.sh
# controller(slurm-ctrl)에서 실행
# 용도: slurm.conf 작성 및 NFS를 통해 compute에 배포
##############################################################################
set -euo pipefail

echo "===== [1/2] slurm.conf 작성 ====="
cat >/tmp/slurm.conf <<'EOF'
# Slurm Manual Lab - CPU 기본 구성
ClusterName=aws-slurm-lab
SlurmctldHost=slurm-ctrl
SlurmUser=slurm

# Authentication
AuthType=auth/munge
CryptoType=crypto/munge

# Process Tracking
ProctrackType=proctrack/linuxproc
MpiDefault=none
ReturnToService=1

# Paths
SlurmctldPidFile=/run/slurmctld.pid
SlurmdPidFile=/run/slurmd.pid
SlurmdSpoolDir=/var/spool/slurmd
StateSaveLocation=/var/spool/slurmctld
SlurmctldLogFile=/var/log/slurm/slurmctld.log
SlurmdLogFile=/var/log/slurm/slurmd.log

# Scheduling
SwitchType=switch/none
TaskPlugin=task/none
SchedulerType=sched/backfill
SelectType=select/cons_tres

# Nodes - t3.small: 2 vCPU, ~1.7GB usable memory
NodeName=slurm-c1 CPUs=2 RealMemory=1600 State=UNKNOWN
NodeName=slurm-c2 CPUs=2 RealMemory=1600 State=UNKNOWN

# Partitions
PartitionName=debug Nodes=slurm-c[1-2] Default=YES MaxTime=INFINITE State=UP
EOF

sudo install -o slurm -g slurm -m 0644 /tmp/slurm.conf /etc/slurm/slurm.conf

echo "===== [2/2] NFS를 통해 compute에 배포 ====="
sudo cp /etc/slurm/slurm.conf /shared/slurm.conf

echo "slurm.conf 배포 완료. compute node에서 04 스크립트를 실행하세요."
echo ""
cat /etc/slurm/slurm.conf

echo "===== 03-slurm-config 완료 ====="
