#!/bin/bash
##############################################################################
# 01-controller-install.sh
# controller(slurm-ctrl)에서만 실행
# 용도: Munge + Slurm controller + NFS server 설치
##############################################################################
set -euo pipefail

echo "===== [1/4] Controller 패키지 설치 ====="
sudo apt-get install -y munge slurm-wlm nfs-kernel-server

echo "===== [2/4] NFS 서버 구성 ====="
grep -q '^/shared ' /etc/exports || echo '/shared 10.50.1.0/24(rw,sync,no_subtree_check,no_root_squash)' | sudo tee -a /etc/exports

sudo exportfs -ra
sudo systemctl enable nfs-server
sudo systemctl restart nfs-server

echo "NFS export 확인:"
sudo exportfs -v

echo "===== [3/4] Munge key 생성 및 공유 ====="
# 기존 key가 없으면 생성
if [ ! -f /etc/munge/munge.key ]; then
  sudo create-munge-key -f
fi

sudo chown munge:munge /etc/munge/munge.key
sudo chmod 400 /etc/munge/munge.key

# compute node가 가져갈 수 있도록 NFS 공유 경로에 배포
sudo sh -c 'base64 -w0 /etc/munge/munge.key > /shared/mungekey.b64'

echo "===== [4/4] Munge 시작 ====="
sudo systemctl enable munge
sudo systemctl restart munge
sudo systemctl status munge --no-pager

echo "Munge 인증 테스트:"
munge -n | unmunge

echo "===== 01-controller-install 완료 ====="
