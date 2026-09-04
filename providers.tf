terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.5.0"
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile

  default_tags {
    tags = {
      Project     = "vpn-server"
      Environment = "production"
      ManagedBy   = "terraform"
      Owner       = var.owner_tag
    }
  }
}
