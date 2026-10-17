resource "aws_instance" "control_plane" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [var.security_group_id]
  key_name               = "vockey"

  user_data = templatefile("${path.module}/user-data/control-plane.sh.tftpl", {
    install_k8s        = file("${path.module}/user-data/install-k8s.sh")
    init_control_plane = file("${path.module}/user-data/init-control-plane.sh")
    install_cni        = file("${path.module}/user-data/install-cni.sh")
  })

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-control-plane"
    Environment = var.environment
    Role        = "control-plane"
  }
}

resource "aws_instance" "worker" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [var.security_group_id]
  key_name               = "vockey"

  user_data = templatefile("${path.module}/user-data/worker.sh.tftpl", {
    install_k8s = file("${path.module}/user-data/install-k8s.sh")
  })

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-worker"
    Environment = var.environment
    Role        = "worker"
  }
}