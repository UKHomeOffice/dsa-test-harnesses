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
