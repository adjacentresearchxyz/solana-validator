terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.29"
    }
  }

  backend "remote" {
    organization = "adajcentresearch"
    hostname     = "app.terraform.io"

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
  type        = string
  description = "AWS key to autheticate with"
  default     = "adjacentresearch_rsa"
}

# Configure the AWS Provider
provider "aws" {
  # Keys can also be exported see https://registry.terraform.io/providers/hashicorp/aws/latest/docs#authentication
  # export AWS_ACCESS_KEY_ID="anaccesskey"
  # export AWS_SECRET_ACCESS_KEY="asecretkey"
  access_key = var.access_key
  secret_key = var.secret_key
  region     = "us-east-1"
}

module "nixos_image" {
  source  = "git::https://github.com/tweag/terraform-nixos.git//aws_image_nixos?ref=5f5a0408b299874d6a29d1271e9bffeee4c9ca71"
  release = "22.05"
}

resource "aws_security_group" "egress_ports" {
  vpc_id = "vpc-0d7d7f1f799e0dd0a "
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # solana gossip ports https://docs.solana.com/running-validator/validator-reqs#required
  ingress {
    from_port   = 8000
    to_port     = 10000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # solana gossip ports https://docs.solana.com/running-validator/validator-reqs#required
  ingress {
    from_port   = 8000
    to_port     = 10000
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # solana RPC ports (HTTP) https://docs.solana.com/running-validator/validator-reqs#optional
  ingress {
    from_port   = 8899
    to_port     = 8899
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # solana RPC ports (Websocket) https://docs.solana.com/running-validator/validator-reqs#optional 
  ingress {
    from_port   = 8900
    to_port     = 8900
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags
}

resource "tls_private_key" "state_ssh_key" {
  algorithm = "RSA"
}

resource "aws_instance" "machine" {
  ami             = module.nixos_image.ami
  instance_type   = var.instance_type
  security_groups = [aws_security_group.egress_ports.id]
  subnet_id       = "subnet-000390238e20aae0b"
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

  provisioner "remote-exec" {
    inline = [
      "nixos-rebuild switch --flake /etc/nixos/#nixos", # building `nixos` config
    ]
  }

  # add adjacent channel and install solana packages
  provisioner "remote-exec" {
    inline = [
      "nix-channel --add https://github.com/adjacentresearchxyz/nix-channel/archive/main.tar.gz adjacent",
      "nix-channel --update",
      "nix-env -f https://github.com/adjacentresearchxyz/nix-channel/archive/main.tar.gz -i solana-validator",
    ]
  }

  # generate keys 
  # note: creating on devnet given in order to create vote account and start on mainnet SOL needs to be sent to an the fee payer account
  provisioner "remote-exec" {
    inline = [
      "solana config set --url http://api.devnet.solana.com", # config for mainnet-beta
      "solana transaction-count",
      "mkdir /etc/nixos/solana",
      "solana-keygen new -o /etc/nixos/solana/validator-keypair.json", # generate validator-keypair
      "solana config set --keypair /etc/nixos/solana/validator-keypair.json", # set keypair in config
      "solana-keygen new -o /etc/nixos/solana/authorized-withdrawer-keypair.json", # create authorized withdrawer
      "solana-keygen new -o /etc/nixos/solana/vote-account-keypair.json", # create vote account 
      "solana airdrop 1", # airdrop some SOL for vote account
      "solana create-vote-account /etc/nixos/solana/vote-account-keypair.json /etc/nixos/solana/validator-keypair.json /etc/nixos/solana/authorized-withdrawer-keypair.json", # create vote account 
    ]
  }
}

output "public_dns" {
  value = aws_instance.machine.public_dns
}

output "public_ip" {
  value = aws_instance.machine.public_ip
}
