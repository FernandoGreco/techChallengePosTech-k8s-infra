variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "security_group_id" {
  type = string
}

variable "instance_type" {
  type    = string
  default = "t3.medium"
}

variable "ami_id" {
  type = string
}

variable "ssh_key_name" {
  description = "Nome do Key Pair AWS utilizado pelas instancias EC2"
  type        = string
}