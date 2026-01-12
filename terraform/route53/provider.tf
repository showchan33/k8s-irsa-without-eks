terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
    local = {
      source = "hashicorp/local"
    }
  }
}

provider "aws" {
  region = var.var_provider.region
}
