output "k8s_security_group_id" {
  description = "ID do Security Group dos nodes Kubernetes"
  value       = aws_security_group.k8s_nodes.id
}