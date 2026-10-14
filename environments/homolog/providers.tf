provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "TechChallengePosTech"
      Environment = "homolog"
      ManagedBy   = "Terraform"
      Component   = "Kubernetes"
    }
  }
}