variable "name" {
  description = "Name prefix for resources."
  type        = string
  default     = "msk-ecs-producer"
}

variable "tags" {
  description = "Tags to apply to resources."
  type        = map(string)
  default     = {}
}

variable "vpc_id" {
  description = "Existing VPC ID."
  type        = string
}

variable "azs" {
  description = "AZs to use for new private subnets (must align with cidrs)."
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for the new private subnets."
  type        = list(string)
}

variable "private_route_table_ids" {
  description = "Existing private route table IDs to associate to the new subnets (same length as private_subnet_cidrs)."
  type        = list(string)
}

variable "msk_kafka_version" {
  description = "Kafka version for MSK provisioned cluster."
  type        = string
  default     = "3.6.0"
}

variable "msk_broker_instance_type" {
  description = "Broker instance type."
  type        = string
  default     = "kafka.m5.large"
}

variable "msk_broker_count" {
  description = "Number of broker nodes (should equal number of subnets for best HA)."
  type        = number
  default     = 3
}

variable "msk_ebs_volume_size" {
  description = "EBS volume size (GiB) per broker."
  type        = number
  default     = 1000
}

variable "ecr_repository_name" {
  description = "Existing ECR repository name (not ARN)."
  type        = string
}

variable "image_tag" {
  description = "Docker image tag to build/push."
  type        = string
  default     = "latest"
}

variable "ecs_cpu" {
  description = "Fargate task CPU."
  type        = number
  default     = 256
}

variable "ecs_memory" {
  description = "Fargate task memory (MiB)."
  type        = number
  default     = 512
}

variable "desired_count" {
  description = "ECS service desired count."
  type        = number
  default     = 1
}

variable "producer_topic" {
  description = "Topic to write to."
  type        = string
  default     = "test-topic"
}

variable "message_interval_seconds" {
  description = "How often to produce messages."
  type        = number
  default     = 1
}

variable "log_retention_days" {
  description = "CloudWatch log retention."
  type        = number
  default     = 14
}
