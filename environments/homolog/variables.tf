variable "aws_region" {
  description = "Regiao AWS onde os recursos serao criados"
  type        = string
  default     = "us-east-1"
}

variable "vpc_id" {
  description = "ID da VPC existente"
  type        = string
}

variable "subnet_ids" {
  description = "IDs das subnets existentes"
  type        = list(string)
}