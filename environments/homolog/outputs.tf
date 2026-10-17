output "vpc_id" {
  value = data.aws_vpc.existing.id
}

output "subnet_ids" {
  value = [
    for subnet in data.aws_subnet.existing :
    subnet.id
  ]
}

output "k8s_security_group_id" {
  description = "ID do Security Group Kubernetes"
  value       = module.security.k8s_security_group_id
}

output "control_plane_id" {
  value = module.ec2.control_plane_id
}

output "worker_id" {
  value = module.ec2.worker_id
}

output "control_plane_private_ip" {
  value = module.ec2.control_plane_private_ip
}

output "worker_private_ip" {
  value = module.ec2.worker_private_ip
}

output "subnet_details" {
  description = "Detalhes das subnets existentes"

  value = {
    for id, subnet in data.aws_subnet.existing :
    id => {
      cidr_block              = subnet.cidr_block
      availability_zone       = subnet.availability_zone
      map_public_ip_on_launch = subnet.map_public_ip_on_launch
    }
  }
}