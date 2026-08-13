#!/bin/bash
##############################################################################
# 18-test-partition.sh
# controller(slurm-ctrl)에서 실행
# 용도: Partition 정책 테스트
# 선행조건: 15-test-fake-gpu.sh가 성공한 상태 (GPU partition 존재)
#
# Partition은 Slurm에서 "자원 풀 + 정책"을 정의하는 단위다.
# 예: gpu-debug는 짧은 테스트용(2시간 제한), gpu-train은 학습용(1일 제한)
# 파티션으로 자원 사용 목적을 분리하고, 시간 제한으로 독점을 방지한다.
##############################################################################
set -euo pipefail

echo "============================================================"
echo " Partition 정책 테스트"
echo "============================================================"

echo ""
echo "===== [1/4] 파티션 목록 확인 ====="
# sinfo -s: 파티션별 요약 (summary)
# 각 파티션의 이름, 상태(AVAIL), 시간제한(TIMELIMIT), 노드 수/상태가 보인다.
# *가 붙은 파티션이 기본(default) 파티션 - 파티션 미지정 시 여기로 간다.
sinfo -s
echo ""
echo "정상 기준: debug(default), gpu-debug, gpu-train, gpu-eval 파티션 존재"

echo ""
echo "===== [2/4] 특정 파티션 지정 실행 ====="
echo "--- debug 파티션 ---"
# --partition=debug: 명시적으로 debug 파티션에 Job을 보낸다.
# 파티션을 안 쓰면 default(*)로 간다.
srun --input=none --partition=debug hostname

echo ""
echo "--- gpu-debug 파티션 ---"
# gpu-debug 파티션은 GPU Job 전용이므로 --gres=gpu:b200:1도 함께 요청한다.
# 파티션별로 요구하는 자원 유형이 다를 수 있다.
srun --input=none --partition=gpu-debug --gres=gpu:b200:1 \
  bash -c 'echo "partition=gpu-debug host=$(hostname)"'

echo ""
echo "===== [3/4] gpu-debug 시간 제한 확인 ====="
# scontrol show partition: 파티션의 상세 설정을 보여준다.
# MaxTime: 이 파티션에서 Job이 실행할 수 있는 최대 시간
# gpu-debug는 02:00:00(2시간)으로 설정했다.
# 이 시간을 초과하면 Slurm이 자동으로 Job을 kill한다.
# 이렇게 하면 테스트 Job이 자원을 오래 점유하는 것을 방지할 수 있다.
scontrol show partition gpu-debug | grep -E 'PartitionName|MaxTime|State'

echo ""
echo "===== [4/4] 존재하지 않는 파티션 요청 ====="
# 없는 파티션 이름을 요청하면 즉시 에러가 나야 한다.
# 이것이 성공하면 Slurm 설정에 문제가 있는 것이다.
srun --input=none --partition=nonexistent --immediate=5 hostname \
  && echo "❌ 예상과 다르게 수락됨" \
  || echo "✅ 예상대로 거부됨 (존재하지 않는 파티션)"

echo ""
echo "============================================================"
echo " Partition 정책 테스트 완료"
echo "============================================================"
