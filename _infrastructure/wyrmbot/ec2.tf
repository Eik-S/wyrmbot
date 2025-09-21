data "aws_ami" "wyrmbot" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

# Security group for SSH access
resource "aws_security_group" "wyrmbot_sg" {
  name_prefix = "wyrmbot-"
  description = "Security group for wyrmbot EC2 instance"

  # SSH access from anywhere (you can restrict this to your IP for better security)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # All outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "wyrmbot-security-group"
  }
}

# Key pair for SSH access (you'll need to create this manually or use an existing one)
variable "key_pair_name" {
  description = "Name of the AWS key pair to use for SSH access"
  type        = string
  default     = "wyrmbot-key"
}

# Local variables to read the .env file
locals {
  env_content = file("${path.root}/../.env")
}

# User data script to set up the environment
locals {
  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    env_content = local.env_content
  }))
}

resource "aws_instance" "wyrmbot" {
  ami                    = data.aws_ami.wyrmbot.id
  instance_type          = "t3.small"
  key_name               = var.key_pair_name
  vpc_security_group_ids = [aws_security_group.wyrmbot_sg.id]
  user_data_base64       = local.user_data

  instance_market_options {
    market_type = "spot"
  }

  tags = {
    Name = "wyrmbot"
  }
}

# Outputs
output "instance_ip" {
  description = "Public IP address of the wyrmbot instance"
  value       = aws_instance.wyrmbot.public_ip
}

output "instance_id" {
  description = "Instance ID of the wyrmbot instance"
  value       = aws_instance.wyrmbot.id
}

output "ssh_command" {
  description = "SSH command to connect to the instance"
  value       = "ssh -i ${var.key_pair_name}.pem ec2-user@${aws_instance.wyrmbot.public_ip}"
}
