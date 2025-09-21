terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.14"
    }
  }

  required_version = ">= 1.13.3"

  backend "s3" {

    bucket         = "terraform-state-wyrmbot"
    key            = "state/terraform.tfstate"
    encrypt        = true
    dynamodb_table = "terraform-state-wyrmbot"
  }
}

provider "aws" {
  region = "eu-central-1"
}

module "wyrmbot" {
  source = "./wyrmbot"
}
