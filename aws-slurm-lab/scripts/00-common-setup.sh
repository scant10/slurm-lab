#!/bin/bash
##############################################################################
# 00-common-setup.sh
# 모든 노드(controller + compute)에서 실행
# 용도: /etc/hosts, 기본 디렉터리, Munge/Slurm 패키지 설치
##############################################################################
set -euo pipefail

echo "===== [1/5] 사전 확인 ====="
hostname
cat /etc/os-release | grep -E "^(NAME|VERSION)="
ip -br addr
date

echo "===== [2/5] /etc/hosts 설정 ====="
sudo cp /etc/hosts /etc/hosts.bak.$(date -u +%Y%m%dT%H%M%SZ)

grep -q 'slurm-ctrl' /etc/hosts || sudo tee -a /etc/hosts >/dev/null <<'EOF'
10.50.1.10 slurm-ctrl
10.50.1.11 slurm-c1
10.50.1.12 slurm-c2
EOF

echo "hosts 등록 확인:"
getent hosts slurm-ctrl
getent hosts slurm-c1
getent hosts slurm-c2

echo "===== [3/5] 패키지 업데이트 및 Munge/Slurm 기본 설치 ====="
sudo apt-get update -y
sudo apt-get install -y munge slurm-wlm-basic-plugins

echo "===== [4/5] Slurm 사용자 및 디렉터리 생성 ====="
# UID/GID를 64030으로 고정 (노드 간 UID 불일치 방지)
id slurm >/dev/null 2>&1 || sudo useradd --system --uid 64030 --home /var/lib/slurm --shell /usr/sbin/nologin slurm

sudo install -d -o munge -g munge -m 0700 /etc/munge /run/munge /var/log/munge /var/lib/munge
sudo install -d -o slurm -g slurm -m 0755 /var/spool/slurmd /var/log/slurm
sudo install -d -o slurm -g slurm -m 0755 /var/spool/slurmctld

echo "===== [5/5] 공유 디렉터리 생성 ====="
sudo install -d -o root -g root -m 0777 /shared /shared/slurm-logs /shared/templates

echo "===== 00-common-setup 완료 ====="
