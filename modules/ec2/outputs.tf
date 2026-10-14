output "control_plane_id" {
  value = aws_instance.control_plane.id
}

output "worker_id" {
  value = aws_instance.worker.id
}

output "control_plane_private_ip" {
  value = aws_instance.control_plane.private_ip
}

output "worker_private_ip" {
  value = aws_instance.worker.private_ip
}