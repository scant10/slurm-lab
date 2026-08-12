variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-2"
}

variable "project_name" {
  description = "Project name for resource tagging"
  type        = string
  default     = "slurm-manual-lab"
}

variable "instance_type" {
  description = "EC2 instance type for all nodes"
  type        = string
  default     = "t3.small"
}

variable "allowed_ssh_cidrs" {
  description = "CIDR blocks allowed to SSH (restrict to your IP for security)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}
