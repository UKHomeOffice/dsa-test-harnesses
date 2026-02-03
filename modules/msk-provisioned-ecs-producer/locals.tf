locals {
  azs        = data.aws_availability_zones.available.names
  region     = data.aws_region.current.region
  account_id = data.aws_caller_identity.current.account_id

  len_private_subnets  = length(var.private_subnets)
  private_subnet_names = [for az in local.azs : format("%s-private-%s", var.name, az)]

  # Allow either 1 route table (reused) or 3 (one per subnet)
  private_route_table_ids = length(var.private_route_table_ids) == 1 ? [for _ in range(3) : var.private_route_table_ids[0]] : var.private_route_table_ids

  merged_tags = merge(var.tags, { "terraform-location" = "dsa-test-harnesses/msk-provisioned-ecs-producer" })

  # MSK
  topic_arn_prefix = "arn:aws:kafka:${local.region}:${local.account_id}:topic/${aws_msk_cluster.this.cluster_name}/${aws_msk_cluster.this.cluster_uuid}"

  # Required vars the container expects
  base_env = {
    TOPIC             = var.producer_topic
    BOOTSTRAP_SERVERS = aws_msk_cluster.this.bootstrap_brokers_sasl_iam
    AWS_REGION        = local.region

    # Your tuning defaults (first-class vars)
    MESSAGES_PER_SEC = var.messages_per_sec
    BATCH_SIZE       = var.batch_size
    NULL_PROB        = var.null_prob

    ACKS             = var.acks
    LINGER_MS        = var.linger_ms
    RETRIES          = var.retries
    COMPRESSION      = var.compression
    MAX_REQUEST_SIZE = var.max_request_size
  }

  # Allow callers to override anything by passing ecs_environment
  container_env = merge(local.base_env, var.ecs_environment)

  # Convert map -> ECS list-of-objects form
  container_env_list = [
    for k, v in local.container_env : { name = k, value = v }
  ]
}