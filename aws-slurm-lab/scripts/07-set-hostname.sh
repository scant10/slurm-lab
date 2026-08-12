#!/bin/bash
##############################################################################
# 07-set-hostname.sh
# 각 노드에서 실행 (EC2는 기본 hostname이 ip-x-x-x-x이므로 변경 필요)
# 사용법: sudo bash 07-set-hostname.sh <hostname>
#   controller: sudo bash 07-set-hostname.sh slurm-ctrl
#   compute 1:  sudo bash 07-set-hostname.sh slurm-c1
#   compute 2:  sudo bash 07-set-hostname.sh slurm-c2
##############################################################################
set -euo pipefail

if [ $# -ne 1 ]; then
  echo "Usage: sudo bash $0 <hostname>"
  echo "  예: sudo bash $0 slurm-ctrl"
  exit 1
fi

NEW_HOSTNAME=$1

echo "===== hostname 변경: $(hostname) -> ${NEW_HOSTNAME} ====="
sudo hostnamectl set-hostname "${NEW_HOSTNAME}"

echo "변경 확인:"
hostname
hostname -s

echo "===== 07-set-hostname 완료 ====="
echo "※ 변경 후 새 SSH 세션을 열면 prompt에 반영됩니다."
