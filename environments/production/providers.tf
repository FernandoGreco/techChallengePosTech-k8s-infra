provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "TechChallengePosTech"
      Environment = "production"
      ManagedBy   = "Terraform"
      Component   = "Kubernetes"
    }
  }
}