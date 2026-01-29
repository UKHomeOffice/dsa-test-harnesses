output "private_subnet_ids" {
  value = [for s in aws_subnet.private : s.id]
}

output "msk_cluster_arn" {
  value = aws_msk_cluster.this.arn
}

output "msk_bootstrap_brokers_sasl_iam" {
  value = aws_msk_cluster.this.bootstrap_brokers_sasl_iam
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.this.name
}

output "ecs_service_name" {
  value = aws_ecs_service.producer.name
}

output "image_uri" {
  value = docker_registry_image.producer.name
}
