# Slurm 실행환경 구성 가이드

## 1. Slurm의 실행 단위는 무엇인가

Slurm은 VM을 만들거나 컨테이너를 띄우는 도구가 아니다.
Slurm이 배포하는 단위는 **리눅스 프로세스(Job/Task)**다.

```
Kubernetes → Pod(컨테이너)를 노드에 배치
Slurm      → Process(리눅스 프로세스)를 노드에 배치
```

`srun python train.py`를 실행하면, Slurm은 자원이 있는 compute 노드를 찾아
그 노드의 OS 위에서 `python train.py`를 직접 실행한다.
VM 생성도, 컨테이너 빌드도, 이미지 pull도 없다. 그래서 오버헤드가 거의 없다.

### 스케줄러 비교

| | Slurm | Kubernetes | VM 기반 |
|--|-------|------------|---------|
| 실행 단위 | 프로세스 (Job Step/Task) | 컨테이너 (Pod) | 가상머신 |
| 격리 수준 | 낮음 (같은 OS 공유) | 중간 (namespace/cgroup) | 높음 (별도 커널) |
| 오버헤드 | 거의 없음 | 약간 (이미지 레이어) | 큼 (전체 OS 부팅) |
| 시작 속도 | 즉시 | 수초~수십초 | 수분 |
| GPU 성능 | 네이티브 (손실 없음) | 네이티브 | pass-through 필요 |

---

## 2. 문제: 연구원이 PyTorch를 쓰고 싶다면?

Slurm은 "이 노드에서 이 명령을 실행해라"만 해준다.
PyTorch, transformers, CUDA 같은 **실행 환경은 Slurm이 관리하지 않는다.**

즉, 연구원이 모델을 학습하려면:
1. Slurm이 자원(GPU, CPU, 메모리)을 할당하고
2. 학습 환경(PyTorch 등)은 **별도로 준비**되어 있어야 한다

이 "환경 준비"를 어떻게 하느냐에 따라 3가지 방법이 있다.

---

## 3. 방법 1: 모든 노드에 직접 설치

### 개요

모든 compute 노드에 동일한 패키지를 설치한다.

```bash
# 모든 compute 노드에서 실행
sudo apt install python3-pip -y
pip3 install torch torchvision transformers
```

### Job script

```bash
#!/bin/bash
#SBATCH --partition=gpu
#SBATCH --gres=gpu:8

python train.py --epochs 100
```

### 장점
- 가장 단순하다
- 성능 최상 (로컬 디스크에서 라이브러리 로드)

### 단점
- 노드가 10대, 50대가 되면 전부 동일하게 유지하기 어렵다
- 연구원 A는 PyTorch 2.0, 연구원 B는 2.3이 필요하면 충돌한다
- 패키지 업데이트할 때마다 모든 노드에 반복 작업

### 적합한 상황
- 노드 3-5대 이하
- 연구원이 1-2명
- 교육/PoC 환경

---

## 4. 방법 2: NFS 공유 가상환경 (가장 흔함)

### 개요

NFS로 공유되는 경로(/shared)에 conda 또는 venv 환경을 만들어두면,
모든 compute 노드에서 동일한 환경을 activate해서 사용할 수 있다.

```
/shared/envs/
├── torch23-cuda12/     ← 연구원 A 팀
├── torch20-legacy/     ← 레거시 모델 재현용
├── jax-latest/         ← 연구원 B
└── llm-inference/      ← 서빙 테스트용
```

### 환경 생성 (한 번만)

```bash
# login node 또는 controller에서 실행
conda create -p /shared/envs/torch23-cuda12 python=3.11 -y
source activate /shared/envs/torch23-cuda12
pip install torch==2.3.0 torchvision transformers datasets wandb
```

### Job script

```bash
#!/bin/bash
#SBATCH --job-name=train-bert
#SBATCH --partition=gpu
#SBATCH --nodes=1
#SBATCH --gres=gpu:8
#SBATCH --output=/shared/slurm-logs/%x-%j.out

# 1. 환경 활성화
source /shared/envs/torch23-cuda12/bin/activate

# 2. 학습 실행
python train.py --model bert-base --batch-size 64
```

### 연구원별 환경 분리

```bash
# 연구원 A: 최신 PyTorch
conda create -p /shared/envs/team-a python=3.11 -y
pip install torch==2.3

# 연구원 B: 특정 버전 고정
conda create -p /shared/envs/team-b python=3.10 -y
pip install torch==2.0.1
```

각자 Job script에서 자기 환경을 activate하면 된다. 충돌 없음.

### 장점
- compute 노드에 아무것도 안 깔아도 된다
- 환경을 한 번 만들면 모든 노드에서 즉시 사용 가능
- 연구원별/프로젝트별 환경 분리 가능

### 단점
- NFS I/O 병목: import torch 시 수천 개 파일을 네트워크로 읽음
- 대규모(50+ 노드)에서 동시 학습 시작 시 NFS 부하 발생 가능
- 해결: conda-pack으로 tar 생성 후 로컬 /tmp에 풀거나, BeeGFS/Lustre 사용

### 적합한 상황
- 노드 5-30대
- 연구원 5-20명
- 대부분의 기업/연구소 GPU 클러스터

---

## 5. 방법 3: 컨테이너 (Enroot + Pyxis)

### 개요

학습 환경을 컨테이너 이미지로 패키징한다.
NVIDIA가 만든 Enroot(컨테이너 런타임) + Pyxis(Slurm 플러그인)를 사용하면
srun/sbatch 명령에 `--container-image` 옵션만 추가하면 된다.

```bash
srun --partition=gpu \
     --gres=gpu:8 \
     --container-image=nvcr.io/nvidia/pytorch:24.01-py3 \
     python train.py
```

### NVIDIA NGC 이미지 활용

NVIDIA NGC에는 사전 빌드된 AI 프레임워크 이미지가 있다:

| 이미지 | 내용 |
|--------|------|
| `nvcr.io/nvidia/pytorch:24.01-py3` | PyTorch + CUDA + cuDNN + NCCL |
| `nvcr.io/nvidia/tensorflow:24.01-tf2-py3` | TensorFlow 2 |
| `nvcr.io/nvidia/nemo:24.01` | NeMo (LLM 학습) |

### 커스텀 이미지 빌드

```dockerfile
FROM nvcr.io/nvidia/pytorch:24.01-py3

# 추가 라이브러리 설치
RUN pip install transformers datasets wandb deepspeed

# 학습 코드 복사
COPY train.py /workspace/
COPY config/ /workspace/config/
```

```bash
docker build -t my-registry/train-env:v1 .
docker push my-registry/train-env:v1
```

### Job script

```bash
#!/bin/bash
#SBATCH --job-name=train-llm
#SBATCH --partition=gpu
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=1
#SBATCH --gres=gpu:8
#SBATCH --output=/shared/slurm-logs/%x-%j.out

srun --container-image=my-registry/train-env:v1 \
     --container-mounts=/shared:/shared \
     torchrun --nnodes=2 --nproc_per_node=8 \
     /workspace/train.py --config /shared/configs/llm.yaml
```

### 장점
- 완벽한 환경 격리: 연구원마다 완전히 다른 환경 가능
- 재현성: 이미지 태그로 버전 고정, "내 노트북에서는 됐는데" 문제 해결
- 이식성: 다른 클러스터에서도 같은 이미지로 즉시 실행
- NFS I/O 문제 없음: 라이브러리가 이미지 안에 있음

### 단점
- 초기 설정 필요 (Enroot + Pyxis 설치 및 설정)
- 이미지 빌드/관리 프로세스 필요
- 연구원이 Docker 개념을 알아야 함

### 적합한 상황
- 대규모 GPU 클러스터 (30+ 노드)
- 다양한 팀/프로젝트가 공존
- 실험 재현성이 중요한 환경
- MLOps 파이프라인과 연동 필요

---

## 6. 보조 도구: Environment Modules (Lmod)

중간 규모에서 많이 쓰는 방식. 미리 설치된 여러 버전의 소프트웨어를
`module load` 명령으로 전환한다.

```bash
# 사용 가능한 모듈 확인
module avail

# PyTorch 2.3 + CUDA 12.1 로드
module load pytorch/2.3-cuda12.1

# Job script에서
#!/bin/bash
#SBATCH --partition=gpu
#SBATCH --gres=gpu:4

module load pytorch/2.3-cuda12.1
python train.py
```

대학/연구소 HPC에서 가장 오래된 방식이지만, 관리자가 모든 버전을 빌드해야 하므로
연구원의 자유도가 제한된다.

---

## 7. 규모별 추천

| 규모 | 추천 방법 | 이유 |
|------|-----------|------|
| 교육/PoC (3-5대) | 직접 설치 또는 NFS venv | 단순하고 빠름 |
| 소규모 (5-15대) | NFS + conda 환경 | 관리 쉽고 연구원 자유도 높음 |
| 중규모 (15-50대) | NFS conda + Lmod | 공통 환경은 module, 커스텀은 conda |
| 대규모 (50+ 대) | Enroot + Pyxis 컨테이너 | 격리/재현성/확장성 |

---

## 8. 실제 운영 예시: 연구원 워크플로

### NFS 환경 기준

```
연구원 워크플로:
1. login node에 SSH 접속
2. conda create -p /shared/envs/my-exp python=3.11
3. pip install 필요한 라이브러리
4. Job script 작성 (/shared/scripts/train.sh)
5. sbatch /shared/scripts/train.sh
6. squeue로 상태 확인
7. cat /shared/slurm-logs/train-<job_id>.out 으로 결과 확인
```

### 컨테이너 기준

```
연구원 워크플로:
1. 로컬 PC에서 Dockerfile 작성/빌드
2. 이미지를 레지스트리에 push
3. login node에 SSH 접속
4. Job script에 --container-image=<이미지> 지정
5. sbatch /shared/scripts/train.sh
6. 결과 확인
```

---

## 9. Job script 템플릿

### 단일 노드 GPU 학습

```bash
#!/bin/bash
#SBATCH --job-name=train-single
#SBATCH --partition=gpu
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --gres=gpu:4
#SBATCH --cpus-per-task=16
#SBATCH --mem=64G
#SBATCH --time=12:00:00
#SBATCH --output=/shared/slurm-logs/%x-%j.out

# 환경 활성화
source /shared/envs/torch23/bin/activate

# GPU 확인
nvidia-smi
echo "CUDA_VISIBLE_DEVICES=$CUDA_VISIBLE_DEVICES"

# 학습 실행
python train.py \
  --model resnet50 \
  --batch-size 256 \
  --epochs 100 \
  --data /shared/datasets/imagenet
```

### 멀티노드 분산 학습 (DDP)

```bash
#!/bin/bash
#SBATCH --job-name=train-ddp
#SBATCH --partition=gpu
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=1
#SBATCH --gres=gpu:8
#SBATCH --cpus-per-task=32
#SBATCH --mem=256G
#SBATCH --time=24:00:00
#SBATCH --output=/shared/slurm-logs/%x-%j.out

source /shared/envs/torch23/bin/activate

# MASTER_ADDR: 첫 번째 노드의 hostname (분산 통신 기준점)
export MASTER_ADDR=$(scontrol show hostnames $SLURM_JOB_NODELIST | head -n 1)
export MASTER_PORT=29500

srun torchrun \
  --nnodes=$SLURM_NNODES \
  --nproc_per_node=8 \
  --rdzv_backend=c10d \
  --rdzv_endpoint=$MASTER_ADDR:$MASTER_PORT \
  train.py --config config.yaml
```

### 컨테이너 기반 학습

```bash
#!/bin/bash
#SBATCH --job-name=train-container
#SBATCH --partition=gpu
#SBATCH --nodes=1
#SBATCH --gres=gpu:8
#SBATCH --time=24:00:00
#SBATCH --output=/shared/slurm-logs/%x-%j.out

srun --container-image=nvcr.io/nvidia/pytorch:24.01-py3 \
     --container-mounts=/shared:/shared \
     bash -c '
       pip install transformers datasets
       python /shared/scripts/train.py --config /shared/configs/bert.yaml
     '
```

---

## 10. 요약

```
Slurm이 하는 일:
  → "어떤 노드에서, CPU/GPU 몇 개로, 이 명령을 실행해라"

Slurm이 안 하는 일:
  → "PyTorch를 설치해라", "환경을 구성해라", "의존성을 해결해라"

환경 준비는 운영팀/연구원이 별도로:
  → NFS 위 conda 환경, 또는
  → 컨테이너 이미지, 또는
  → 전 노드 직접 설치
```

Job script는 항상 이 구조:
```bash
#!/bin/bash
#SBATCH 옵션들        ← Slurm에게: 자원 요청
환경 activate         ← OS에게: 실행 환경 준비
python train.py       ← 실제 작업 실행
```
