#!/bin/bash
##############################################################################
# 05-start-services.sh
# 용도: Slurm 서비스 시작
# - controller에서 실행하면 slurmctld 시작
# - compute에서 실행하면 slurmd 시작
##############################################################################
set -euo pipefail

HOSTNAME=$(hostname -s)

if [ "$HOSTNAME" = "slurm-ctrl" ]; then
  echo "===== Controller: slurmctld 시작 ====="
  sudo systemctl enable slurmctld
  sudo systemctl restart slurmctld
  sudo systemctl status slurmctld --no-pager
else
  echo "===== Compute: slurmd 시작 ====="
  sudo systemctl enable slurmd
  sudo systemctl restart slurmd
  sudo systemctl status slurmd --no-pager
fi

echo "===== 05-start-services 완료 ====="
