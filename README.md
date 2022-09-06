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