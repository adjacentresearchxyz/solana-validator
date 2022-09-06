# Deployment 

Deployment of `NixOS` via `terraform` with monitoring and log collection

## Authenticating 
- Login to `aws-cli` 
- Symlink it to your deployment repository
- Install a `.pem` file for aws deployments
    - The key name that you used here in the AWS console will be used in the `aws_instance.machine.key_name`

## Layout
```
├── *.auto.tfvars
├── README.md
├── id_rsa.pem
├── main.tf
├── nixos
│   ├── README.md
│   ├── configuration.nix
│   ├── flake.lock
│   ├── flake.nix
│   ├── grafana
│   │   ├── dashboards
│   │   │   ├── logging.json
│   │   │   └── node_exporter.json
│   │   └── grafanaDatasources.yml
│   ├── home.nix
│   └── promtail.yaml
└── variables
    └── base.tfvars
```

- Terraform is used for deploying to various cloud environment
    - Terraform `.tfvars` files specified in the `./variables` directory for different configurations
- NixOS configurations deployed for deployment of identical systems 
    - Includes deployment and management of default services
        - `fail2ban` for basic DDOS protection
        - `grafana` with system monitoring dashboards
        - `loki` for system log collection 
        - `prometheus` for system statistics collection
        
```
# the following AMI is used
"22.05.us-east-1.hvm-ebs" = "ami-0223db08811f6fb2d"
```

## Deploying 
```
# copy `variables/base.tfvars`
cp ./variables/base.tfvars *.auto.tfvars

# enter the variables you want to deploy with into `*.auto.tfvars`
# note this is were you enter your AWS keys

# plan and then apply the configuration
terraform plan
terraform apply
```

#### VSCode Server
If you want to develop on the host remote `vscode-server` has been added but you will have to enable once in the server with 
```
systemctl --user enable auto-fix-vscode-server.service
systemctl --user start auto-fix-vscode-server.service
```
