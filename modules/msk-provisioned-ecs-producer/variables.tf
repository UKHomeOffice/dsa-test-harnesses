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

#----------------------------------------------------------
# Networking
#----------------------------------------------------------

variable "vpc_id" {
  description = "Existing VPC ID."
  type        = string
}

variable "private_subnets" {
  description = "CIDR blocks for private subnets."
  type        = list(string)
  nullable    = true
  default     = [null]
}

variable "private_route_table_ids" {
  description = <<-EOT
    Existing private route table IDs to associate to the newly created private subnets.
    Must be either:
      - length 3 (one per subnet/AZ), or
      - length 1 (the same route table used for all three subnets).
  EOT
  type        = list(string)
}

#----------------------------------------------------------
# MSK
#----------------------------------------------------------

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

#----------------------------------------------------------
# ECR / ECS
#----------------------------------------------------------

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

variable "ecs_environment" {
  description = <<-EOT
    Additional environment variables to pass to the ECS container.

    These values are merged with the module's default environment variables and
    can be used to override any default (e.g. ACKS, LINGER_MS) or to introduce
    new variables consumed by the producer script.
  EOT
  type        = map(string)
  default     = {}
}

variable "ecs_desired_count" {
  description = "ECS service desired count."
  type        = number
  default     = 1
}

variable "producer_topic" {
  description = "Topic to write to."
  type        = string
  default     = "test-topic"
}

variable "log_retention_days" {
  description = "CloudWatch log retention."
  type        = number
  default     = 14
}

#----------------------------------------------------------
# App-level vars, overrideable via ecs_environment
#----------------------------------------------------------

variable "messages_per_sec" {
  description = "Target total message production rate (messages per second)."
  type        = string
  default     = "10"
}

variable "batch_size" {
  description = "Number of messages produced per loop iteration."
  type        = string
  default     = "1"
}

variable "null_prob" {
  description = "Probability (0.0–1.0) that nullable union fields will be emitted as null."
  type        = string
  default     = "0.35"
}

variable "acks" {
  description = "Kafka producer acknowledgement level (e.g. all, 1, 0)."
  type        = string
  default     = "all"
}

variable "linger_ms" {
  description = "Time (in milliseconds) the producer will wait to batch messages before sending."
  type        = string
  default     = "20"
}

variable "retries" {
  description = "Number of retry attempts for failed Kafka produce requests."
  type        = string
  default     = "10"
}

variable "compression" {
  description = <<-EOT
    Compression codec used by the Kafka producer.

    Supported values depend on the client library and typically include:
    snappy, gzip, lz4, zstd, or none.
  EOT
  type        = string
  default     = "snappy"
}

variable "max_request_size" {
  description = "Maximum Kafka produce request size in bytes."
  type        = string
  default     = "2097152" # 2 MiB
}
