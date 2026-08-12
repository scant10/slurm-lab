output "ssh_private_key_path" {
  description = "Path to SSH private key"
  value       = local_file.private_key.filename
}

output "slurm_ctrl_public_ip" {
  description = "Controller public IP"
  value       = aws_instance.slurm_ctrl.public_ip
}

output "slurm_c1_public_ip" {
  description = "Compute node 1 public IP"
  value       = aws_instance.slurm_compute[0].public_ip
}

output "slurm_c2_public_ip" {
  description = "Compute node 2 public IP"
  value       = aws_instance.slurm_compute[1].public_ip
}

output "ssh_commands" {
  description = "SSH connection commands"
  value = <<-EOT
    # Controller
    ssh -i ${local_file.private_key.filename} ubuntu@${aws_instance.slurm_ctrl.public_ip}

    # Compute Node 1
    ssh -i ${local_file.private_key.filename} ubuntu@${aws_instance.slurm_compute[0].public_ip}

    # Compute Node 2
    ssh -i ${local_file.private_key.filename} ubuntu@${aws_instance.slurm_compute[1].public_ip}
  EOT
}

output "network_info" {
  description = "Internal network layout"
  value = <<-EOT
    slurm-ctrl  private: 10.50.1.10  public: ${aws_instance.slurm_ctrl.public_ip}
    slurm-c1    private: 10.50.1.11  public: ${aws_instance.slurm_compute[0].public_ip}
    slurm-c2    private: 10.50.1.12  public: ${aws_instance.slurm_compute[1].public_ip}
  EOT
}
