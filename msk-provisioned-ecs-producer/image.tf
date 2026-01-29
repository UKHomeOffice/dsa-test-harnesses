data "aws_ecr_repository" "repo" {
  name = var.ecr_repository_name
}

data "aws_ecr_authorization_token" "token" {}

provider "docker" {
  registry_auth {
    address  = data.aws_ecr_repository.repo.repository_url
    username = data.aws_ecr_authorization_token.token.user_name
    password = data.aws_ecr_authorization_token.token.password
  }
}

locals {
  image_name = "${data.aws_ecr_repository.repo.repository_url}:${var.image_tag}"
}

resource "docker_image" "producer" {
  name         = local.image_name
  keep_locally = false

  build {
    context    = "${path.module}/container"
    dockerfile = "${path.module}/container/Dockerfile"
  }
}

resource "docker_registry_image" "producer" {
  name = docker_image.producer.name
}
