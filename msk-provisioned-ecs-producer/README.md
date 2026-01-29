module "harness" {
  source = "./msk-provisioned-ecs-producer"

  name = "my-harness"

  vpc_id                = "vpc-123456"
  azs                   = ["eu-west-2a", "eu-west-2b", "eu-west-2c"]
  private_subnet_cidrs   = ["10.10.64.0/20", "10.10.80.0/20", "10.10.96.0/20"]
  private_route_table_ids = ["rtb-aaa", "rtb-bbb", "rtb-ccc"]

  ecr_repository_name = "my-existing-ecr-repo"
  image_tag           = "v1"

  producer_topic            = "load-test"
  message_interval_seconds  = 1
  desired_count             = 1
}
