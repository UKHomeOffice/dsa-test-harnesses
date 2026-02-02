# ECS -> Amazon MSK (Provisioned) Terraform Module

This module is responsible for creating an ECS cluster that runs a Python application in a Docker container. This Python application is run inside an ECS Task, and writes data to a specified Kafka Topic in MSK. The Amazon MSK cluster, private subnets to host ECS and MSK, and required IAM roles are all deployed by this module.

## Architecture of Deployed Module
![System Architecture](docs/architecture.svg)

## Usage
```hcl
module "msk_harness" {
  source = "git::https://github.com/UKHomeOffice/dsa-test-harnesses.git//modules/msk-provisioned-ecs-producer?ref=<commit_hash>"

  name   = var.name
  vpc_id = var.vpc_id

  private_subnets_cidr    = var.private_subnets_cidr
  private_route_table_ids = ["rtb-aaa"]

  image          = var.ecs_task_image
  producer_topic = var.msk_topic

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
This module deploys an Amazon MSK provisioned cluster across a set of 3 x private subnets (also created as part of this module), using IAM auth and TLS for encryption using a KMS key (deployed as part of the module). A CloudWatch Logs group is created and linked to the cluster for capturing logs.

## ECS Configuration
This module creates a new ECS cluster, complete with service, task definition, and both of the required IAM roles. The container image used by the ECS task needs to be passed in from the module call, having been pre-built and sent to an ECR repository already.

We take the image as a parameter to the module so that we separate the application deployment and infrastructure deployment. Otherwise if we tried to deploy everything via Terraform, including the build and push of a container image to ECR, we would tie the application deployments to the infrastructure. A better solution is to build and push the image to ECR in a GitHub actions workflow, then have a secondary workflow that deploys this module over the top, taking the image you just built as an input. 

A CloudWatch Logs group is created and linked to the cluster for capturing logs.

All producer configuration is passed to the ECS task as environment variables. Any value may be overriden using ecs_environment.
