instance_type = "t2.nano"
volume_size = "500" #GiB
tags = {
 "Name" : "nixos-base"
 "env" : "base"
}
key_name = ""
access_key = ""
secret_key = ""
region                = "us-east-2"
availability_zone    = "us-east-2a"
vpc_cidr              = "10.0.0.0/16"
public_subnet_cidr   = "10.0.10.0/24"