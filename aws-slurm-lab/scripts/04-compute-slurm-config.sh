#!/bin/bash
##############################################################################
# 04-compute-slurm-config.sh
# compute node(slurm-c1, slurm-c2)에서 실행
# 용도: NFS에서 slurm.conf 가져와 적용
##############################################################################
set -euo pipefail

echo "===== slurm.conf 적용 ====="
if [ -f /shared/slurm.conf ]; then
  sudo install -o slurm -g slurm -m 0644 /shared/slurm.conf /etc/slurm/slurm.conf
  echo "slurm.conf 적용 완료"
else
  echo "ERROR: /shared/slurm.conf 없음. controller에서 03 스크립트를 먼저 실행하세요."
  exit 1
fi

echo "===== 04-compute-slurm-config 완료 ====="
