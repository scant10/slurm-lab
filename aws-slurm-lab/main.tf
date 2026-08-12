##############################################################################
# AWS Slurm Manual Lab - CPU 기반 실습 인프라
# 구성: controller 1대 + compute 2대 (Ubuntu 22.04, t3.small)
##############################################################################

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

##############################################################################
# SSH Key Pair
##############################################################################

resource "tls_private_key" "slurm_lab" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "slurm_lab" {
  key_name   = "${var.project_name}-key"
  public_key = tls_private_key.slurm_lab.public_key_openssh
}

resource "local_file" "private_key" {
  content         = tls_private_key.slurm_lab.private_key_pem
  filename        = "${path.module}/.secrets/slurm-lab.pem"
  file_permission = "0400"
}

##############################################################################
# VPC
##############################################################################

resource "aws_vpc" "slurm" {
  cidr_block           = "10.50.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "${var.project_name}-vpc" }
}

resource "aws_subnet" "slurm" {
  vpc_id                  = aws_vpc.slurm.id
  cidr_block              = "10.50.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = { Name = "${var.project_name}-subnet" }
}

resource "aws_internet_gateway" "slurm" {
  vpc_id = aws_vpc.slurm.id

  tags = { Name = "${var.project_name}-igw" }
}

resource "aws_route_table" "slurm" {
  vpc_id = aws_vpc.slurm.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.slurm.id
  }

  tags = { Name = "${var.project_name}-rt" }
}

resource "aws_route_table_association" "slurm" {
  subnet_id      = aws_subnet.slurm.id
  route_table_id = aws_route_table.slurm.id
}

##############################################################################
# Security Group
##############################################################################

resource "aws_security_group" "slurm" {
  name_prefix = "${var.project_name}-sg-"
  vpc_id      = aws_vpc.slurm.id
  description = "Slurm lab - SSH + internal all traffic"

  # SSH from anywhere (실습용)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidrs
    description = "SSH access"
  }

  # Internal - 같은 subnet 내 모든 통신 허용 (Slurm, Munge, NFS)
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.50.1.0/24"]
    description = "Internal all traffic"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Outbound all"
  }

  tags = { Name = "${var.project_name}-sg" }
}

##############################################################################
# EC2 Instances
##############################################################################

# Controller
resource "aws_instance" "slurm_ctrl" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.slurm.id
  private_ip             = "10.50.1.10"
  vpc_security_group_ids = [aws_security_group.slurm.id]
  key_name               = aws_key_pair.slurm_lab.key_name

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  tags = { Name = "slurm-ctrl" }
}

# Compute Nodes
resource "aws_instance" "slurm_compute" {
  count                  = 2
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.slurm.id
  private_ip             = "10.50.1.${11 + count.index}"
  vpc_security_group_ids = [aws_security_group.slurm.id]
  key_name               = aws_key_pair.slurm_lab.key_name

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  tags = { Name = "slurm-c${count.index + 1}" }
}

##############################################################################
# Data Sources
##############################################################################

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}
