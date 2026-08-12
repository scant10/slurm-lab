#!/bin/bash
##############################################################################
# 02-compute-install.sh
# compute node(slurm-c1, slurm-c2)에서 실행
# 용도: Munge + Slurm compute + NFS client 설치
##############################################################################
set -euo pipefail

echo "===== [1/4] Compute 패키지 설치 ====="
sudo apt-get install -y munge slurm-wlm nfs-common

echo "===== [2/4] NFS 마운트 ====="
grep -q '^slurm-ctrl:/shared ' /etc/fstab || \
  echo 'slurm-ctrl:/shared /shared nfs defaults,_netdev,nofail 0 0' | sudo tee -a /etc/fstab

sudo mount /shared || echo "이미 마운트됨"

echo "NFS 마운트 확인:"
df -h /shared
touch /shared/slurm-logs/$(hostname)-nfs-test.txt

echo "===== [3/4] Munge key 동기화 ====="
sudo systemctl stop munge || true

# controller에서 배포한 key 가져오기
if [ -f /shared/mungekey.b64 ]; then
  sudo sh -c 'base64 -d /shared/mungekey.b64 > /etc/munge/munge.key'
  sudo chown munge:munge /etc/munge/munge.key
  sudo chmod 400 /etc/munge/munge.key
  echo "Munge key 동기화 완료"
else
  echo "ERROR: /shared/mungekey.b64 파일 없음. controller에서 01 스크립트를 먼저 실행하세요."
  exit 1
fi

echo "===== [4/4] Munge 시작 ====="
sudo systemctl enable munge
sudo systemctl restart munge
sudo systemctl status munge --no-pager

echo "Munge 인증 테스트:"
munge -n | unmunge

echo "===== 02-compute-install 완료 ====="
