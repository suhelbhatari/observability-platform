terraform {
  required_version = ">= 1.7.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.50"
    }
  }
  backend "s3" {
    bucket         = "acme-observability-tfstate"
    key            = "prod-eu-west-1/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = "eu-west-1"
  default_tags {
    tags = {
      Project     = "observability-platform"
      Environment = "prod"
      Region      = "eu-west-1"
      Purpose     = "disaster-recovery"
      ManagedBy   = "terraform"
    }
  }
}
