#---------------------------------------------------------------
# Networking
#---------------------------------------------------------------

output "vpc_id" {
  description = "ID of the VPC the harness resources are deployed into."
  value       = var.vpc_id
}

output "private_subnet_ids" {
  description = "IDs of the newly created private subnets used by MSK and ECS."
  value       = [for s in aws_subnet.private : s.id]
}

output "private_subnet_cidrs" {
  description = "CIDR blocks of the newly created private subnets."
  value       = [for s in aws_subnet.private : s.cidr_block]
}

output "private_subnet_azs" {
  description = "Availability Zones of the newly created private subnets."
  value       = [for s in aws_subnet.private : s.availability_zone]
}

#---------------------------------------------------------------
# MSK
#---------------------------------------------------------------

output "msk_cluster_arn" {
  description = "ARN of the MSK provisioned cluster."
  value       = aws_msk_cluster.this.arn
}

output "msk_cluster_name" {
  description = "Name of the MSK provisioned cluster."
  value       = aws_msk_cluster.this.cluster_name
}

output "msk_kafka_version" {
  description = "Kafka version configured for the MSK cluster."
  value       = aws_msk_cluster.this.kafka_version
}

output "msk_bootstrap_brokers_tls" {
  description = "TLS bootstrap brokers string for the MSK cluster."
  value       = aws_msk_cluster.this.bootstrap_brokers_tls
}

output "msk_bootstrap_brokers_sasl_iam" {
  description = "SASL/IAM bootstrap brokers string for the MSK cluster (recommended for IAM auth)."
  value       = aws_msk_cluster.this.bootstrap_brokers_sasl_iam
}

output "msk_kms_key_arn" {
  description = "KMS key ARN used for MSK encryption at rest."
  value       = aws_kms_key.msk.arn
}

output "msk_security_group_id" {
  description = "Security group ID attached to MSK brokers."
  value       = aws_security_group.msk.id
}

output "msk_log_group_name" {
  description = "CloudWatch Log Group name used for MSK broker logs."
  value       = aws_cloudwatch_log_group.msk.name
}

#---------------------------------------------------------------
# ECS
#---------------------------------------------------------------

output "ecs_cluster_id" {
  description = "ID of the ECS cluster running the producer service."
  value       = aws_ecs_cluster.this.id
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster running the producer service."
  value       = aws_ecs_cluster.this.name
}

output "ecs_service_name" {
  description = "Name of the ECS service running the producer task."
  value       = aws_ecs_service.producer.name
}

output "ecs_service_arn" {
  description = "ARN of the ECS service running the producer task."
  value       = aws_ecs_service.producer.id
}

output "ecs_task_definition_arn" {
  description = "ARN of the ECS task definition used by the producer service."
  value       = aws_ecs_task_definition.producer.arn
}

output "ecs_task_execution_role_arn" {
  description = "ARN of the ECS task execution role (pulls image, writes logs)."
  value       = aws_iam_role.ecs_task_execution.arn
}

output "ecs_task_role_arn" {
  description = "ARN of the ECS task role assumed by the running container (MSK IAM auth permissions)."
  value       = aws_iam_role.ecs_task.arn
}

output "ecs_security_group_id" {
  description = "Security group ID attached to ECS tasks."
  value       = aws_security_group.ecs.id
}

output "ecs_log_group_name" {
  description = "CloudWatch Log Group name used for ECS task logs."
  value       = aws_cloudwatch_log_group.ecs.name
}

#---------------------------------------------------------------
# ECR
#---------------------------------------------------------------

output "ecr_repository_url" {
  description = "URL of the ECR repository used for the producer image."
  value       = data.aws_ecr_repository.repo.repository_url
}

#---------------------------------------------------------------
# Container
#---------------------------------------------------------------

output "image_uri" {
  description = "Full image URI (repository URL plus tag) used by ECS."
  value       = docker_image.producer.name
}

output "container_environment" {
  description = "Final set of environment variables passed to the ECS container (after merging defaults and overrides)."
  value       = local.container_env
  sensitive   = true
}
