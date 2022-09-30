variable "region" {
  type = string
}

provider "aws" {
  region = var.region
}

//data "aws_caller_identity" "current" {}

terraform {
  backend "s3" {
    bucket         = "ashwiniag-practices"
    region         = "us-east-1"
    dynamodb_table = "tfstate"
  }
}

terraform {
  required_version = ">= 1.0.10"
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.13.1"
    }
    aws = {
      source = "hashicorp/aws"
    }
    template = {
      source = "hashicorp/template"
    }
  }
}

