variable "aws_region" {
  description = "Regiao AWS onde os recursos serao criados"
  type        = string
  default     = "us-east-1"

  validation {
    condition     = var.aws_region == "us-east-1"
    error_message = "Este fluxo de producao utiliza somente us-east-1."
  }
}

variable "vpc_id" {
  description = "ID da VPC existente"
  type        = string
}

variable "subnet_ids" {
  description = "IDs das subnets existentes"
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) > 0
    error_message = "Informe pelo menos uma subnet."
  }
}

variable "ssh_key_name" {
  description = "Nome do Key Pair existente na conta AWS"
  type        = string
}

variable "ssh_allowed_cidr" {
  description = "IP ou rede autorizada a acessar as instancias via SSH"
  type        = string

  validation {
    condition     = can(cidrhost(var.ssh_allowed_cidr, 0))
    error_message = "Informe um CIDR valido, por exemplo: 203.0.113.10/32."
  }
}
