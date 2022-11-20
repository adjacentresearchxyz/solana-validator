terraform {
  required_providers {
    latitudesh = {
      source  = "latitudesh/latitudesh"
      version = "~> 0.1.4"
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

# Define Variables
variable "latitudesh_token" {
  description = "Latitude.sh API token"
}

variable "plan" {
  description = "Latitude.sh server plan"
  default = "c2.small.x86"
}

variable "region" {
  description = "Latitude.sh server region slug"
  default = "ASH"
}

variable "ssh_public_key" {
  description = "Latitude.sh SSH public key"
}

variable "plan_name" {
  description = "Plan name"
  default = "Solana Validator"
}

variable "plan_description" {
  description = "Plan description"
  default = "Solana Validator"
}

variable "plan_environment" {
  description = "Plan environment"
  default = "Development"
}

# Configure the Provider
provider "latitudesh" {
  auth_token = var.latitudesh_token
}

# Create a Project
resource "latitudesh_project" "project" {
  name = vars.plan_name
  description = vars.plan_description
  environment = vars.environment
}

# Define SSH Keys
resource "latitudesh_ssh_key" "ssh_key" {
  project    = latitudesh_project.project.id
  name       = "Solana Validator Key"
  public_key = var.ssh_public_key
}

# Create a Server
resource "latitudesh_server" "server" {
  hostname         = vars.plan_name
  operating_system = "ubuntu_22_04_x64_lts"
  plan             = data.latitudesh_plan.plan.slug
  project          = latitudesh_project.project.id
  site             = data.latitudesh_region.region.slug
  ssh_keys         = [latitudesh_ssh_key.ssh_key.id]
}

resource "aws_instance" "machine" {
  ami = module.nixos_image.ami
  # ami = "ami-0223db08811f6fb2d" # nixos 22.05 for us-east-1
  # ami = "ami-0a743534fa3e51b41" # nixos 22.05 for us-east-2
  instance_type   = var.instance_type
  security_groups = [aws_security_group.default.id]
  subnet_id       = aws_subnet.public_subnet.id
  key_name        = var.key_name

  tags = var.tags

  root_block_device {
    volume_size = var.volume_size
  }

  connection {
    type        = "ssh"
    user        = "root"
    private_key = file("./adjacentresearch_rsa.pem") # your private key here
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
      "solana-keygen new -o /etc/nixos/solana/validator-keypair.json --no-bip39-passphrase", # generate validator-keypair
      "solana config set --keypair /etc/nixos/solana/validator-keypair.json", # set keypair in config
      "solana-keygen new -o /etc/nixos/solana/authorized-withdrawer-keypair.json --no-bip39-passphrase", # create authorized withdrawer
      "solana-keygen new -o /etc/nixos/solana/vote-account-keypair.json --no-bip39-passphrase", # create vote account 
      "solana airdrop 1", # airdrop some SOL for vote account
      "solana create-vote-account /etc/nixos/solana/vote-account-keypair.json /etc/nixos/solana/validator-keypair.json /etc/nixos/solana/authorized-withdrawer-keypair.json", # create vote account 
    ]
  }

  provisioner "remote-exec" {
    inline = [
      "nixos-rebuild switch", # building `nixos` config
    ]
  }
}

output "public_dns" {
  value = aws_instance.machine.public_dns
}

output "public_ip" {
  value = aws_instance.machine.public_ip
}
