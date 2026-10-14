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