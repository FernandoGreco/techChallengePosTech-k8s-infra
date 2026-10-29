data "aws_vpc" "existing" {
  id = var.vpc_id
}

data "aws_subnet" "existing" {
  for_each = toset(var.subnet_ids)

  id = each.value
}

module "security" {
  source = "../../modules/security"

  vpc_id           = data.aws_vpc.existing.id
  project_name     = "techchallenge"
  environment      = "production"
  ssh_allowed_cidr = var.ssh_allowed_cidr
}

module "ec2" {
  source = "../../modules/ec2"

  project_name      = "techchallenge"
  environment       = "production"
  subnet_id         = var.subnet_ids[0]
  security_group_id = module.security.k8s_security_group_id
  instance_type     = "t3.medium"
  ami_id            = data.aws_ami.ubuntu.id
  ssh_key_name      = var.ssh_key_name

  root_volume_encrypted = true
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}
