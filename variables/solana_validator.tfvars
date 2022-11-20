instance_type = "r6a.4xlarge"
volume_size = "2000" #GiB
tags = {
 "Name" : "solana"
 "env" : "validator"
}
key_name = ""
access_key = ""
secret_key = ""
region                = "us-east-2"
availability_zone    = "us-east-2a"
vpc_cidr              = "10.0.0.0/16"
public_subnet_cidr   = "10.0.10.0/24"