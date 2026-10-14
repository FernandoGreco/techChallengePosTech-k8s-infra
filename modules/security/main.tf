resource "aws_security_group" "k8s_nodes" {
  name_prefix = "${var.project_name}-${var.environment}-k8s-"
  description = "Security Group dos nodes Kubernetes"
  vpc_id      = var.vpc_id

  tags = {
    Name        = "${var.project_name}-${var.environment}-k8s"
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "aws_vpc_security_group_ingress_rule" "internal" {
  security_group_id            = aws_security_group.k8s_nodes.id
  referenced_security_group_id = aws_security_group.k8s_nodes.id

  ip_protocol = "-1"

  description = "Comunicacao interna entre nodes Kubernetes"
}

resource "aws_vpc_security_group_egress_rule" "outbound" {
  security_group_id = aws_security_group.k8s_nodes.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"

  description = "Saida para instalacao de pacotes e imagens"
}