# ECS -> Amazon MSK (Provisioned) Terraform Module

This module is responsible for creating an ECS cluster that runs a Python application in a Docker container. This Python application is run inside an ECS Task, and writes data to a specified Kafka Topic in MSK. The Amazon MSK cluster, private subnets to host ECS and MSK, and required IAM roles are all deployed by this module.

## Architecture of Deployed Module
![System Architecture](docs/architecture.svg)

## Usage
```hcl
module "msk_harness" {
  source = "git::https://github.com/UKHomeOffice/dsa-test-harnesses.git//modules/msk-provisioned-ecs-producer?ref=<commit_hash>"

  name = var.name

  vpc_id = var.vpc_id
  
  private_subnets_cidr = var.private_subnets_cidr

  # Use one route table for all 3, or provide 3
  private_route_table_ids = ["rtb-aaa"]

  ecr_repository_name = var.ecr_repository_name

  producer_topic = "msk_topic_1"

  # Either use first-class vars...
  messages_per_sec  = "25"
  batch_size        = "5"
  null_prob         = "0.15"
  compression       = "zstd"
  max_request_size  = "3145728"

  # ...and/or pass arbitrary extras / overrides
  ecs_environment = {
    ACKS         = "all"      # override if you want
    LINGER_MS    = "50"
    RETRIES      = "20"
    SOME_FLAG    = "true"     # any additional flags your script supports
  }
}
```

## MSK Configuration


## ECS Configuration
All producer configuration is passed to the ECS task as environment variables. Any value may be overriden using ecs_environment.

## Calculating private_subnet_supernet_cidr
As part of the LZA process, Core Cloud team vends AWS accounts that contain an IPAM pool. This makes it much easier to calculate which address space is available in your VPC using the AWS CLI.

aws ec2 allocate-ipam-pool-cidr \
  --ipam-pool-id ipam-pool-xxxxxxxx \
  --netmask-length 23 \
  --preview-next-cidr \
  --region eu-west-2

This should display output similar to:

{
    "IpamPoolAllocation": {
        "Cidr": "10.111.38.0/23",
        "ResourceType": "custom",
        "ResourceOwner": "123456789100"
    }
}

This is purely informational. As long as you use an aws_vpc_ipam_pool_cidr resource above this module call in your Terraform, you don't need to run this command to get the CIDR yourself. e.g.
```hcl
resource "aws_vpc_ipam_pool_cidr" "harness" {
  ipam_pool_id   = var.ipam_pool_id
  netmask_length = 23
}

private_subnet_supernet_cidr = aws_vpc_ipam_pool_cidr.harness.cidr
```

For the ECS -> MSK test harness, we need IPs for the MSK broker ENIs, and for the ECS ENIs. We should be able to use a netmask of /23, which contains 512 total IPs. To spread across 3 AZs, the clean split is to carve the /23 into four /25 subnets (adding 2 bits creates 4 subnets). Each /25 subnet has 123 usable IPs (AWS reserves 5 per subnet), which is enough for our temporary test harness and a few extra resources if we need them.
