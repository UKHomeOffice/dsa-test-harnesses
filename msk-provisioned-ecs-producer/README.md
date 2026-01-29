# ECS -> Amazon MSK (Provisioned) Terraform Module

This module is responsible for creating an ECS cluster that runs a Python application in a Docker container. This Python application is run inside an ECS Task, and writes data to a specified Kafka Topic in MSK. The Amazon MSK cluster, private subnets to host ECS and MSK, and required IAM roles are all deployed by this module.

## Usage
```hcl
module "msk_harness" {
  source = "git::https://<repo_url>.git//msk-provisioned-ecs-producer?ref=<commit_hash>"

  name = "msk-producer"

  vpc_id = "vpc-123456"

  # Pick a block you know is unused in the VPC
  private_subnet_supernet_cidr = "10.10.64.0/20"

  # Use one route table for all 3, or provide 3
  private_route_table_ids = ["rtb-aaa"]

  ecr_repository_name = "test-harness-producers"
  image_tag           = "roro-001"

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

# 
All producer configuration is passed to the ECS task as environment variables. Any value may be overriden using ecs_environment.