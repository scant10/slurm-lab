aws_region     = "ap-northeast-2"
project_name   = "slurm-manual-lab"
instance_type  = "t3.small"

# 보안: 실습 시 본인 IP로 제한 권장 (예: ["203.0.113.50/32"])
allowed_ssh_cidrs = ["0.0.0.0/0"]
