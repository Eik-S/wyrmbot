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

# Outputs from the module
output "instance_ip" {
  description = "Public IP address of the wyrmbot instance"
  value       = module.wyrmbot.instance_ip
}

output "instance_id" {
  description = "Instance ID of the wyrmbot instance"
  value       = module.wyrmbot.instance_id
}

output "ssh_command" {
  description = "SSH command to connect to the instance"
  value       = module.wyrmbot.ssh_command
}
