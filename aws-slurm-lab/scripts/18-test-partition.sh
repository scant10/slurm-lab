#!/bin/bash
##############################################################################
# 18-test-partition.sh
# controller(slurm-ctrl)에서 실행
# 용도: Partition 정책 테스트
# 선행조건: 15-test-fake-gpu.sh가 성공한 상태 (GPU partition 존재)
##############################################################################
set -euo pipefail

echo "============================================================"
echo " Partition 정책 테스트"
echo "============================================================"

echo ""
echo "===== [1/4] 파티션 목록 확인 ====="
sinfo -s
echo ""
echo "정상 기준: debug(default), gpu-debug, gpu-train, gpu-eval 파티션 존재"

echo ""
echo "===== [2/4] 특정 파티션 지정 실행 ====="
echo "--- debug 파티션 ---"
srun --input=none --partition=debug hostname
echo ""
echo "--- gpu-debug 파티션 ---"
srun --input=none --partition=gpu-debug --gres=gpu:b200:1 \
  bash -c 'echo "partition=gpu-debug host=$(hostname)"'

echo ""
echo "===== [3/4] gpu-debug 시간 제한 확인 ====="
echo "gpu-debug MaxTime=02:00:00 설정 확인:"
scontrol show partition gpu-debug | grep -E 'PartitionName|MaxTime|State'

echo ""
echo "===== [4/4] 존재하지 않는 파티션 요청 ====="
srun --input=none --partition=nonexistent --immediate=5 hostname \
  && echo "❌ 예상과 다르게 수락됨" \
  || echo "✅ 예상대로 거부됨 (존재하지 않는 파티션)"

echo ""
echo "============================================================"
echo " Partition 정책 테스트 완료"
echo "============================================================"
