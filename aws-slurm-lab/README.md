# AWS Slurm Manual Lab - CPU 기반 실습

## 구성
- `slurm-ctrl` (10.50.1.10) - Controller + NFS Server
- `slurm-c1` (10.50.1.11) - Compute Node 1
- `slurm-c2` (10.50.1.12) - Compute Node 2

## 사전 요구사항
- Terraform >= 1.5
- AWS CLI 설정 완료 (`aws configure`)
- SSH 클라이언트

## 1단계: 인프라 생성

```bash
cd aws-slurm-lab
terraform init
terraform plan
terraform apply
```

apply 완료 후 출력되는 SSH 명령어로 각 노드에 접속합니다.

## 2단계: Slurm 설치 (SSH 접속 후 수동 실행)

### 실행 순서

| 순서 | 스크립트 | 실행 위치 |
|------|----------|-----------|
| 1 | `07-set-hostname.sh` | **모든 노드** (hostname 설정) |
| 2 | `00-common-setup.sh` | **모든 노드** (/etc/hosts, 디렉터리) |
| 3 | `01-controller-install.sh` | **controller만** (Munge, NFS server) |
| 4 | `02-compute-install.sh` | **compute만** (Munge, NFS client) |
| 5 | `03-slurm-config.sh` | **controller만** (slurm.conf 작성) |
| 6 | `04-compute-slurm-config.sh` | **compute만** (slurm.conf 적용) |
| 7 | `05-start-services.sh` | **모든 노드** (서비스 시작) |
| 8 | `06-smoke-test.sh` | **controller만** (검증) |

### 상세 절차

```bash
# --- 모든 노드에서 ---
# 스크립트를 서버에 복사 (로컬에서)
scp -i .secrets/slurm-lab.pem scripts/*.sh ubuntu@<ctrl-ip>:/tmp/
scp -i .secrets/slurm-lab.pem scripts/*.sh ubuntu@<c1-ip>:/tmp/
scp -i .secrets/slurm-lab.pem scripts/*.sh ubuntu@<c2-ip>:/tmp/

# --- controller (slurm-ctrl) ---
sudo bash /tmp/07-set-hostname.sh slurm-ctrl
sudo bash /tmp/00-common-setup.sh
sudo bash /tmp/01-controller-install.sh
sudo bash /tmp/03-slurm-config.sh
sudo bash /tmp/05-start-services.sh

# --- compute node 1 (slurm-c1) ---
sudo bash /tmp/07-set-hostname.sh slurm-c1
sudo bash /tmp/00-common-setup.sh
sudo bash /tmp/02-compute-install.sh
sudo bash /tmp/04-compute-slurm-config.sh
sudo bash /tmp/05-start-services.sh

# --- compute node 2 (slurm-c2) ---
sudo bash /tmp/07-set-hostname.sh slurm-c2
sudo bash /tmp/00-common-setup.sh
sudo bash /tmp/02-compute-install.sh
sudo bash /tmp/04-compute-slurm-config.sh
sudo bash /tmp/05-start-services.sh

# --- controller에서 smoke test ---
bash /tmp/06-smoke-test.sh
```

## 3단계: 설치 후 테스트 (controller에서 실행)

### 테스트 스크립트 목록

| 스크립트 | 검증 항목 | 선행조건 |
|----------|-----------|----------|
| `10-test-cluster-status.sh` | 서비스 상태, 노드 상태, Munge, NFS | 설치 완료 |
| `11-test-cpu-srun.sh` | srun 즉시 실행 (단일/2-node) | 설치 완료 |
| `12-test-cpu-sbatch.sh` | sbatch batch Job 제출 및 결과 | 설치 완료 |
| `13-test-job-management.sh` | squeue, scontrol, scancel | 설치 완료 |
| `14-test-resource-limit.sh` | CPU/노드/메모리 초과 거부 | 설치 완료 |
| `15-test-fake-gpu.sh` | fake GPU GRES 구성 + GPU Job | CPU 테스트 성공 |
| `16-test-gpu-batch.sh` | GPU batch Job (단일/2-node) | 15번 성공 |
| `17-test-nfs-log.sh` | NFS 공유 로그 저장 검증 | 설치 완료 |
| `18-test-partition.sh` | 파티션 정책 및 시간 제한 | 15번 성공 |
| `19-test-troubleshoot.sh` | 문제 발생 시 진단 정보 수집 | 언제든 |

### 추천 테스트 순서

```bash
# Phase 1: CPU 기본 검증
bash /tmp/10-test-cluster-status.sh    # 클러스터 건강 상태
bash /tmp/11-test-cpu-srun.sh          # srun 동작
bash /tmp/12-test-cpu-sbatch.sh        # sbatch 동작
bash /tmp/13-test-job-management.sh    # Job 관리 명령
bash /tmp/14-test-resource-limit.sh    # 스케줄링 정책

# Phase 2: NFS 검증
bash /tmp/17-test-nfs-log.sh           # 공유 로그 저장

# Phase 3: GPU GRES 검증 (fake GPU)
bash /tmp/15-test-fake-gpu.sh          # GPU 구성 + 기본 테스트
bash /tmp/16-test-gpu-batch.sh         # GPU batch Job
bash /tmp/18-test-partition.sh         # GPU 파티션 정책

# 문제 발생 시
bash /tmp/19-test-troubleshoot.sh      # 진단 정보 수집
```

### 실습 완료 기준 (워드 문서 기반)

아래가 모두 성공하면 수동 Slurm 구성 실습은 완료:

1. ✅ Munge 인증 성공 (3대 모두 `STATUS: Success`)
2. ✅ sinfo에서 slurm-c[1-2] idle
3. ✅ srun hostname 단일 노드 성공
4. ✅ srun 2-node 성공
5. ✅ sbatch Job 제출 → output 파일 생성
6. ✅ NFS 공유 경로에서 모든 노드의 output 확인 가능
7. ✅ GPU GRES 등록 확인 (Gres=gpu:b200:8)
8. ✅ GPU Job에서 CUDA_VISIBLE_DEVICES 표시
9. ✅ GPU 초과 요청 거부 (9개 요청 시 실패)
10. ✅ scancel로 Job 취소 정상 동작

## 4단계: 리소스 정리

```bash
terraform destroy
```

## 비용 참고
- t3.small × 3대: 시간당 약 $0.06 (서울 리전)
- 하루 실습 기준: ~$1.5
