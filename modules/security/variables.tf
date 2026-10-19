variable "vpc_id" {
  description = "ID da VPC existente"
  type        = string
}

variable "project_name" {
  description = "Nome do projeto"
  type        = string
  default     = "techchallenge"
}

variable "environment" {
  description = "Ambiente da infraestrutura"
  type        = string
  default     = "homolog"
}

variable "ssh_allowed_cidr" {
  description = "CIDR autorizado para acesso SSH as instancias EC2"
  type        = string
}