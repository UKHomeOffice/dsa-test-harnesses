data "aws_region" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ecr_repository" "repo" {
  name = var.ecr_repository_name
}
