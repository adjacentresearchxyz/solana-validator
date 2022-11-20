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
│   ├── grafana
│   │   ├── dashboards
│   │   │   ├── logging.json
│   │   │   └── node_exporter.json
│   │   └── grafanaDatasources.yml
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
        
Since `NixOS` does not have a AWS supported AMI, community built ones are used. Below are common AMIs for regions `us-east-1` and `us-east-2`. If you want to deploy into a different region or would like to use a different version of `Nixos` you can search the public AMIs [here](https://console.aws.amazon.com/ec2/home?#AMICatalog)

```
# the following AMI is used
# located in `.terraform/modules/nixos_image/aws_image_nixos/url_map.tf
ami = "ami-0223db08811f6fb2d" # nixos 22.05 for us-east-1
ami = "ami-0a743534fa3e51b41" # nixos 22.05 for us-east-2
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
