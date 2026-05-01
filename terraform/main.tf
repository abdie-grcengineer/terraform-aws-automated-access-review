terraform {
  required_version = ">= 1.5.0"

  backend "s3" {
    bucket       = "abdi-tf-state-1777601022" # ← paste your real bucket name here
    key          = "aws-access-review/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true # ← S3-native locking, no DynamoDB needed
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = var.name_prefix
      ManagedBy = "Terraform"
    }
  }
}

data "aws_caller_identity" "current" {}
