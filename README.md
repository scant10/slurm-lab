# Slurm 설치 및 운용 기본 가이드

작성일: 2026-08-13

---

## 1. 문서 목적

이 문서는 Slurm을 처음 도입하려는 운영자가 아래 내용을 빠르게 파악할 수 있도록 정리한 기본 가이드다.

- Slurm이 무엇이고 왜 쓰는가
- 클러스터 구성요소와 역할
- 설치 전 사전 조건
- 설치 절차 (Ubuntu 기준)
- 핵심 설정 파일 작성법
- GPU GRES 구성
- 서비스 시작 및 검증
- 일상 운용 명령어
- 트러블슈팅
- 운영 확장 시 고려사항

---

## 2. Slurm 개요

### 2.1 한 줄 요약

Slurm은 여러 대의 서버와 GPU를 하나의 클러스터로 묶고, 사용자의 작업(Job)을 줄 세워 적절한 노드에 배치/실행하는 HPC/GPU 클러스터용 작업 스케줄러다.

### 2.2 왜 Slurm을 쓰는가

| 문제 | Slurm이 해결하는 방법 |
|------|----------------------|
| 누가 어떤 GPU를 쓰는지 모름 | 자원 할당 추적 및 가시성 제공 |
| 특정 사용자가 GPU를 독점 | 공정 스케줄링, QOS, 사용량 제한 |
| 멀티노드 학습 실행이 어려움 | 노드 간 자원 조합 자동 배치 |
| 빈 GPU를 모르고 놀림 | idle 자원 자동 활용 |
| 장애 노드에 Job이 계속 들어감 | drain/down 상태 관리 |

### 2.3 구성요소

```
┌─────────────────────────────────────────────────┐
│                  Slurm Cluster                   │
├─────────────────────────────────────────────────┤
│  Controller (Head Node)                          │
│    - slurmctld: 스케줄링 데몬                    │
│    - slurmdbd: accounting 데몬 (선택)            │
│    - munged: 인증 서비스                         │
│    - NFS server: 공유 스토리지 (권장)            │
├─────────────────────────────────────────────────┤
│  Compute Node 1..N                               │
│    - slurmd: 실행 데몬                           │
│    - munged: 인증 서비스                         │
│    - NFS client                                  │
│    - NVIDIA Driver (GPU 노드)                    │
├─────────────────────────────────────────────────┤
│  Login Node (선택)                               │
│    - 사용자 접속 및 Job 제출 전용                │
└─────────────────────────────────────────────────┘
```

---

## 3. 사전 조건

### 3.1 네트워크

- 모든 노드가 사설 네트워크로 상호 통신 가능
- `/etc/hosts` 또는 DNS로 hostname 해석 가능
- 방화벽에서 Slurm 포트 허용:
  - `6817/tcp`: slurmctld
  - `6818/tcp`: slurmd
  - `6819/tcp`: slurmdbd (accounting 사용 시)

### 3.2 시간 동기화

- 모든 노드에서 NTP/chrony로 시간 동기화 필수
- Munge 인증이 시간 차이에 민감 (기본 TTL 300초)

```bash
sudo apt install chrony -y
sudo systemctl enable chrony
timedatectl status
```

### 3.3 사용자 UID 통일

- `slurm`, `munge` 사용자의 UID/GID가 모든 노드에서 동일해야 함
- 패키지 설치 순서에 따라 달라질 수 있으므로 미리 고정 권장

```bash
# 모든 노드에서 동일하게 실행
sudo groupadd -g 64030 slurm
sudo useradd --system --uid 64030 --gid 64030 --home /var/lib/slurm --shell /usr/sbin/nologin slurm
```

### 3.4 공유 스토리지

- Job script, output log를 모든 노드에서 같은 경로로 접근하기 위해 NFS 권장
- 필수는 아니지만 운영 편의성이 크게 향상됨

---

## 4. 설치 (Ubuntu 22.04 기준)

### 4.1 모든 노드 공통

```bash
sudo apt-get update -y
sudo apt-get install -y munge

# slurm 사용자 UID 고정 (패키지 설치 전)
id slurm >/dev/null 2>&1 || sudo useradd --system --uid 64030 --home /var/lib/slurm --shell /usr/sbin/nologin slurm

# 디렉터리 생성
sudo install -d -o munge -g munge -m 0700 /etc/munge /run/munge /var/log/munge /var/lib/munge
sudo install -d -o slurm -g slurm -m 0755 /var/spool/slurmd /var/log/slurm /var/spool/slurmctld
```

### 4.2 Controller

```bash
sudo apt-get install -y slurm-wlm nfs-kernel-server
```

### 4.3 Compute Node

```bash
sudo apt-get install -y slurm-wlm nfs-common
```

> **참고**: Ubuntu 기본 패키지는 Slurm 21.08이다. 최신 기능(slurmrestd, Slurm-web 등)이 필요하면 SchedMD 공식 패키지 또는 소스 빌드(23.02+)를 사용한다.

---

## 5. Munge 구성

Munge는 노드 간 인증을 담당한다. 모든 노드에서 동일한 key를 공유해야 한다.

### 5.1 Controller에서 key 생성

```bash
sudo create-munge-key -f
sudo chown munge:munge /etc/munge/munge.key
sudo chmod 400 /etc/munge/munge.key
```

### 5.2 Compute에 key 배포

NFS 공유 경로 또는 scp로 배포:

```bash
# Controller에서
sudo sh -c 'base64 -w0 /etc/munge/munge.key > /shared/mungekey.b64'

# 각 Compute에서
sudo sh -c 'base64 -d /shared/mungekey.b64 > /etc/munge/munge.key'
sudo chown munge:munge /etc/munge/munge.key
sudo chmod 400 /etc/munge/munge.key
```

### 5.3 Munge 시작 및 검증

```bash
# 모든 노드에서
sudo systemctl enable munge
sudo systemctl restart munge
munge -n | unmunge
```

정상: `STATUS: Success` 출력

### 5.4 Key 일치 확인

```bash
# 모든 노드에서 hash가 같아야 함
sudo sha256sum /etc/munge/munge.key
```

---

## 6. NFS 구성

### 6.1 Controller (NFS Server)

```bash
sudo install -d -o root -g root -m 0777 /shared /shared/slurm-logs /shared/templates

grep -q '^/shared ' /etc/exports || \
  echo '/shared 10.50.1.0/24(rw,sync,no_subtree_check,no_root_squash)' | sudo tee -a /etc/exports

sudo exportfs -ra
sudo systemctl enable nfs-server
sudo systemctl restart nfs-server
sudo exportfs -v
```

### 6.2 Compute (NFS Client)

```bash
sudo install -d -o root -g root -m 0777 /shared

grep -q '^<controller>:/shared ' /etc/fstab || \
  echo '<controller>:/shared /shared nfs defaults,_netdev,nofail 0 0' | sudo tee -a /etc/fstab

sudo mount /shared
df -h /shared
```

---

## 7. slurm.conf 작성

### 7.1 기본 구조 (CPU Only)

Controller에서 `/etc/slurm/slurm.conf` 작성:

```ini
# 클러스터 기본
ClusterName=my-slurm-cluster
SlurmctldHost=<controller-hostname>
SlurmUser=slurm

# 인증
AuthType=auth/munge
CryptoType=crypto/munge

# 프로세스 관리
ProctrackType=proctrack/linuxproc
MpiDefault=none
ReturnToService=1

# 경로
SlurmctldPidFile=/run/slurmctld.pid
SlurmdPidFile=/run/slurmd.pid
SlurmdSpoolDir=/var/spool/slurmd
StateSaveLocation=/var/spool/slurmctld
SlurmctldLogFile=/var/log/slurm/slurmctld.log
SlurmdLogFile=/var/log/slurm/slurmd.log

# 스케줄링
SwitchType=switch/none
TaskPlugin=task/none
SchedulerType=sched/backfill
SelectType=select/cons_tres

# 노드 정의 (실제 값으로 교체)
NodeName=compute-01 CPUs=32 RealMemory=128000 State=UNKNOWN
NodeName=compute-02 CPUs=32 RealMemory=128000 State=UNKNOWN

# 파티션 정의
PartitionName=debug Nodes=compute-[01-02] Default=YES MaxTime=INFINITE State=UP
```

### 7.2 노드 자원 확인 방법

Compute에서 실제 값을 확인한 뒤 slurm.conf에 반영:

```bash
slurmd -C         # Slurm이 인식하는 하드웨어 정보
nproc             # CPU 수
free -m           # 메모리 (MB)
```

### 7.3 설정 배포

```bash
# Controller에서 NFS로 배포
sudo cp /etc/slurm/slurm.conf /shared/slurm.conf

# 각 Compute에서 적용
sudo install -o slurm -g slurm -m 0644 /shared/slurm.conf /etc/slurm/slurm.conf
```

---

## 8. GPU GRES 구성

### 8.1 slurm.conf에 GPU 추가

```ini
# GresTypes 선언
GresTypes=gpu

# 노드에 GPU 수량 명시
NodeName=compute-01 CPUs=32 RealMemory=128000 Gres=gpu:b200:8 State=UNKNOWN

# GPU 전용 파티션
PartitionName=gpu Nodes=compute-[01-02] MaxTime=1-00:00:00 State=UP
```

### 8.2 gres.conf 작성

Controller와 Compute 모두 `/etc/slurm/gres.conf`:

```ini
NodeName=compute-01 Name=gpu Type=b200 File=/dev/nvidia[0-7]
NodeName=compute-02 Name=gpu Type=b200 File=/dev/nvidia[0-7]
```

### 8.3 GPU 수 확인

Compute에서:

```bash
nvidia-smi -L              # GPU 목록
ls -l /dev/nvidia[0-9]*    # device file 확인
```

---

## 9. 서비스 시작

### 9.1 Controller

```bash
sudo systemctl enable slurmctld
sudo systemctl restart slurmctld
sudo systemctl status slurmctld --no-pager
```

### 9.2 Compute

```bash
sudo systemctl enable slurmd
sudo systemctl restart slurmd
sudo systemctl status slurmd --no-pager
```

### 9.3 상태 확인

```bash
sinfo                              # 파티션/노드 상태
scontrol show nodes                # 노드 상세
sinfo -R                           # 문제 노드 reason 확인
```

정상 기준: `sinfo`에서 노드가 `idle` 상태

---

## 10. Smoke Test

### 10.1 CPU 테스트

```bash
# 단일 노드
srun --input=none hostname

# 2-node
srun --input=none --nodes=2 --ntasks=2 hostname

# Batch Job
sbatch --wrap="hostname; date; sleep 5" --output=/shared/slurm-logs/test-%j.out
```

### 10.2 GPU 테스트

```bash
# GPU 1개 요청
srun --partition=gpu --gres=gpu:1 nvidia-smi

# GPU 8개 요청
srun --partition=gpu --gres=gpu:8 bash -c 'nvidia-smi -L; echo CUDA=$CUDA_VISIBLE_DEVICES'

# 초과 요청 거부 확인 (노드당 8개인데 9개 요청)
srun --partition=gpu --gres=gpu:9 --immediate=10 hostname || echo "정상 거부됨"
```

---

## 11. 일상 운용 명령어

### 11.1 Job 관리

| 명령어 | 용도 |
|--------|------|
| `sinfo` | 클러스터/파티션/노드 상태 |
| `squeue` | 대기/실행 중 Job 목록 |
| `srun <cmd>` | Job 즉시 실행 |
| `sbatch <script>` | Batch Job 제출 |
| `scancel <job-id>` | Job 취소 |
| `scontrol show job <id>` | Job 상세 정보 |
| `sacct` | 완료된 Job 이력 (slurmdbd 필요) |

### 11.2 노드 관리

```bash
# 노드 유지보수 모드 (새 Job 안 들어감)
scontrol update NodeName=compute-01 State=DRAIN Reason="maintenance"

# 유지보수 완료 후 복귀
scontrol update NodeName=compute-01 State=RESUME

# 노드 상세 확인
scontrol show node compute-01
```

### 11.3 설정 변경 후 반영

```bash
# slurm.conf 변경 후 controller에서
sudo systemctl restart slurmctld

# 또는 reconfigure (일부 변경사항만)
scontrol reconfigure
```

### 11.4 Job Script 예시

```bash
#!/bin/bash
#SBATCH --job-name=train-bert
#SBATCH --partition=gpu
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=1
#SBATCH --gres=gpu:8
#SBATCH --cpus-per-task=32
#SBATCH --mem=128G
#SBATCH --time=24:00:00
#SBATCH --output=/shared/slurm-logs/%x-%j.out

echo "Job ${SLURM_JOB_ID} started at $(date)"
echo "Nodes: ${SLURM_JOB_NODELIST}"

srun torchrun \
  --nnodes=2 \
  --nproc_per_node=8 \
  --rdzv_backend=c10d \
  --rdzv_endpoint=${SLURM_SUBMIT_HOST}:29500 \
  train.py --config config.yaml

echo "Job completed at $(date)"
```

---

## 12. 트러블슈팅

### 12.1 진단 순서

```
문제 발생
  │
  ├─ sinfo -R → 노드 reason 확인
  ├─ scontrol show node <name> → State, Reason
  ├─ journalctl -u slurmctld -n 50 → controller 로그
  ├─ journalctl -u slurmd -n 50 → compute 로그
  └─ munge -n | unmunge → 인증 확인
```

### 12.2 자주 발생하는 문제

| 증상 | 원인 | 해결 |
|------|------|------|
| `Invalid job credential` | Munge key 불일치 또는 slurm UID 불일치 | key 동기화, UID 통일 후 서비스 재시작 |
| 노드 `down` | slurmd 미실행 또는 hostname 불일치 | hostname 확인, slurmd 시작 |
| `invalid_reg` | slurm.conf 자원과 실제 하드웨어 불일치 | `slurmd -C`로 실제 값 확인 후 수정 |
| Job `PD` (Pending) 지속 | 자원 부족 또는 노드 down | `squeue -j <id> -o "%R"`로 reason 확인 |
| `Invalid generic resource` | GresTypes 누락 또는 gres.conf 오류 | slurm.conf에 GresTypes=gpu 추가, gres.conf 확인 |
| Munge `Connection refused` | munged 미실행 | `systemctl restart munge` |
| GPU Job에서 `nvidia-smi` 실패 | NVIDIA driver 미설치 또는 device 권한 | driver 설치 확인, /dev/nvidia* 존재 확인 |

### 12.3 로그 위치

| 로그 | 경로 |
|------|------|
| slurmctld | `/var/log/slurm/slurmctld.log` |
| slurmd | `/var/log/slurm/slurmd.log` |
| munge | `/var/log/munge/munged.log` |
| systemd journal | `journalctl -u slurmctld` / `journalctl -u slurmd` |

---

## 13. 운영 확장 시 고려사항

### 13.1 Accounting (slurmdbd)

사용량 추적, Job 이력, 공정 스케줄링을 위해 slurmdbd + MariaDB 구성 권장:

```ini
# slurm.conf에 추가
AccountingStorageType=accounting_storage/slurmdbd
AccountingStorageHost=<controller-hostname>
JobAcctGatherType=jobacct_gather/linux
```

### 13.2 Multi-Partition 전략

```ini
PartitionName=debug    Nodes=compute-[01-02] MaxTime=02:00:00  Default=YES State=UP
PartitionName=gpu-short Nodes=compute-[01-08] MaxTime=04:00:00  State=UP
PartitionName=gpu-long  Nodes=compute-[01-08] MaxTime=7-00:00:00 State=UP
PartitionName=cpu-only  Nodes=compute-[09-12] MaxTime=INFINITE   State=UP
```

### 13.3 QOS (Quality of Service)

사용자/팀별 자원 제한:

```bash
sacctmgr add qos normal set MaxTRESPerUser=cpu=64,gres/gpu=8
sacctmgr add qos priority set Priority=100 MaxTRESPerUser=cpu=128,gres/gpu=16
```

### 13.4 모니터링

| 도구 | 용도 |
|------|------|
| Prometheus + Grafana | Job 통계, GPU 사용률 대시보드 |
| NVIDIA DCGM | GPU 온도, VRAM, 에러 감지 |
| Slurm-web | 웹 UI (Slurm 23.02+ 필요) |
| Open OnDemand | 웹 포탈 (Job 제출, 터미널, Jupyter) |

### 13.5 자동화

| 규모 | 권장 도구 |
|------|-----------|
| 3-5대 | Shell script + NFS 배포 |
| 10대+ | Terraform(인프라) + Ansible(설정) |
| AWS 전용 | AWS ParallelCluster |
| GPU 대규모 | NVIDIA DeepOps (Ansible 기반) |

### 13.6 백업

정기 백업 대상:

- `/etc/slurm/slurm.conf`, `gres.conf`
- `/etc/munge/munge.key`
- `/var/spool/slurmctld` (state 정보)
- slurmdbd database (MariaDB dump)

---

## 14. 참고 링크

- [Slurm 공식 Quick Start Admin Guide](https://slurm.schedmd.com/quickstart_admin.html)
- [Slurm 공식 sbatch 문서](https://slurm.schedmd.com/sbatch.html)
- [Slurm 공식 GRES Guide](https://slurm.schedmd.com/gres.html)
- [Slurm Configuration Tool (configurator)](https://slurm.schedmd.com/configurator.html)
- [Munge 공식 프로젝트](https://dun.github.io/munge/)
- [SchedMD 공식 패키지](https://www.schedmd.com/downloads.php)
- [NVIDIA DeepOps](https://github.com/NVIDIA/DeepOps)
- [AWS ParallelCluster](https://docs.aws.amazon.com/parallelcluster/)

---

## 15. 용어 정리

| 용어 | 설명 |
|------|------|
| slurmctld | Controller 데몬. 스케줄링, 자원 관리 담당 |
| slurmd | Compute 데몬. 실제 Job 실행 담당 |
| slurmdbd | Database 데몬. Job 이력, accounting 담당 |
| munged | Munge 인증 데몬 |
| Partition | 노드 묶음 + 정책 단위 (Queue 역할) |
| GRES | Generic Resource. GPU 등 특수 자원 정의 |
| Job | 사용자가 제출한 작업 단위 |
| srun | 즉시 실행 명령 |
| sbatch | Batch Job 제출 명령 |
| drain | 노드 유지보수 상태 (기존 Job은 실행, 새 Job 차단) |
| idle | 노드가 비어있고 Job을 받을 수 있는 상태 |
| cons_tres | Consumable Trackable Resources. CPU/메모리/GPU를 개별 추적하는 스케줄링 방식 |
