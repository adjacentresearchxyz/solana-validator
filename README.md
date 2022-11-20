# Solana Validator
## Deploy a Solana Validator via Nixos and Terraform 

Using [NixOS](http://nixos.org) and [Terraform](http://terraform.io) deploying a [solana](https://solana.com) validator is easy and can be done in a few minutes. 

For a more detailed look at the deployment read [DEPLOYMENT.md](https://github.com/adjacentresearchxyz/solana-validator/blob/main/DEPLOYMENT.md)

This will 
- Install the required [Solana](https://solana.com) packages 
- Create required keys 
- Start a `systemd` service running a validator

## Steps 
- Configure your AWS Credentials with Terraform
- Configure Terraform
```
terraform init 
terraform apply # will output an IP that you can log into with the given `.pem` file in your AWS credentials
```

This provisioning will create all the keys nessecary to start a `devnet` validator but has all of the required components to run a `mainnet-beta` validator. You simply need to create the keys and slightly change the configuration

Refer to [generating keys](https://docs.solana.com/running-validator/validator-start#generate-identity) in the solana documentation to create the `validator keypair`, `withdraw authority`, and `vote account` keys that are nessecary

Change the solana config 
`solana config set --url http://api.mainnet-beta.solana.com`

Change the service file entrypoint in `/etc/nixos/services/service.nix`
`--entrypoint entrypoint.mainnet-beta.solana.com:8001`

### Note
Note there might already be a default vpc or subnet in your AWS region in which case you can define your `subnet_id` and `vpc_id`. For example 
```
resource "aws_security_group" "egress_ports" {
  vpc_id = aws_default_vpc.default.id
  ...
  
and 

resource "aws_instance" "machine" {
  ami             = module.nixos_image.ami
  instance_type   = var.instance_type
  security_groups = [aws_security_group.egress_ports.id]
  subnet_id       = aws_default_subnet.default_az1.id
  ...
```

Otherwise a deafult vpc and subnet are defined with 
```
# definitions for default vpc and subnet if no default in the region
resource "aws_default_vpc" "default" {
  tags = {
    Name = "Default VPC"
  }
}

resource "aws_default_subnet" "default_az1" {
  availability_zone = "us-east-2a"

  tags = {
    Name = "Default subnet for us-east-2a"
  }
}
```
