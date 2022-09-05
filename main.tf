terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
  
  backend "remote" {
    organization = "adajcentresearch"
    hostname = "app.terraform.io"

    workspaces {
      prefix = "adjacent-"
    }
  }
}

# variable definitions
# variable values are defined for each corresponding server in `./variables`
variable "volume_size" {
  type        = string
  description = "Size of the volume"
  default     = "500" #GiB
}

variable "instance_type" {
  type        = string
  description = "Type of the instance"
  default     = "t2.nano"
}

variable "tags" {
  type        = map(any)
  description = "Tags associated with naming the instance"
  default = {
    tags = {
      "Name" : "nixos-base"
      "env" : "base"
    }
  }
}

variable "access_key" {
  type        = string
  description = "AWS Access Key"
}

variable "secret_key" {
  type        = string
  description = "AWS Secret Key"
}

variable "key_name" {
  type = string
  description = "AWS key to autheticate with"
  default = "adjacentresearch_rsa"
}

# Configure the AWS Provider
provider "aws" {
  # Keys can also be exported see https://registry.terraform.io/providers/hashicorp/aws/latest/docs#authentication
  # export AWS_ACCESS_KEY_ID="anaccesskey"
  # export AWS_SECRET_ACCESS_KEY="asecretkey"
  access_key = var.access_key
  secret_key = var.secret_key
  region = "us-east-1"
}

# Create a VPC
resource "aws_vpc" "vpc" {
  cidr_block = "10.0.0.0/16"
}

module "nixos_image" {
  source  = "git::https://github.com/tweag/terraform-nixos.git//aws_image_nixos?ref=5f5a0408b299874d6a29d1271e9bffeee4c9ca71"
  release = "22.05"
}

resource "aws_security_group" "ssh_and_egress" {
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "tls_private_key" "state_ssh_key" {
  algorithm = "RSA"
}

resource "aws_instance" "machine" {
  ami             = module.nixos_image.ami
  instance_type   = var.instance_type
  security_groups = [aws_security_group.ssh_and_egress.name]
  key_name        = var.key_name

  tags = var.tags

  root_block_device {
    volume_size = var.volume_size
  }

  connection {
    type        = "ssh"
    user        = "root"
    private_key = file("./id_rsa.pem")
    host        = self.public_ip
  }

 
  provisioner "remote-exec" {
    inline = [
      "nixos-generate-config", # building base `nixos` config
    ]
  }

  provisioner "file" {
    source      = "./nixos/" # note need the trailing slash to fully upload all the directories contents to the destination https://www.terraform.io/language/resources/provisioners/file#directory-uploads
    destination = "/etc/nixos/"
  }

  # symlink grafana, prometheus, and loki default configs into /var/lib/<>

  provisioner "remote-exec" {
    inline = [
      "nixos-rebuild switch --flake /etc/nixos/#nixos", # building `nixos` config
    ]
  }

}

output "public_dns" {
  value = aws_instance.machine.public_dns
}

output "public_ip" {
  value = aws_instance.machine.public_ip
}
