locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 3)

  # Generate 3 subnet CIDRs from the provided supernet.
  private_subnet_cidrs = [
    for i in range(3) : cidrsubnet(var.private_subnet_supernet_cidr, var.private_subnet_newbits, i)
  ]

  # Allow either 1 route table (reused) or 3 (one per subnet)
  private_route_table_ids = length(var.private_route_table_ids) == 1 ? [for _ in range(3) : var.private_route_table_ids[0]] : var.private_route_table_ids

  image_name = "${data.aws_ecr_repository.repo.repository_url}:${var.image_tag}"

  merged_tags = merge(var.tags, { "Module" = "msk-provisioned-ecs-producer", "Name" = var.name })
}

locals {
  # Required vars the container expects
  base_env = {
    TOPIC             = var.producer_topic
    BOOTSTRAP_SERVERS = aws_msk_cluster.this.bootstrap_brokers_sasl_iam
    AWS_REGION        = data.aws_region.current.name

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