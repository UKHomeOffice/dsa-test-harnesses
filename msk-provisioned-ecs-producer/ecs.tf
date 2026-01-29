resource "aws_ecs_cluster" "this" {
  name = "${var.name}-ecs"
  tags = local.merged_tags
}

resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/aws/ecs/${var.name}"
  retention_in_days = var.log_retention_days
  tags              = local.merged_tags
}

# Minimal task definition for a long-running producer
resource "aws_ecs_task_definition" "producer" {
  family                   = "${var.name}-producer"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = tostring(var.ecs_cpu)
  memory                   = tostring(var.ecs_memory)
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name      = "producer"
      image     = docker_registry_image.producer.name
      essential = true

      environment = [
        { name = "TOPIC", value = var.producer_topic },
        { name = "INTERVAL_SECONDS", value = tostring(var.message_interval_seconds) },
        # For IAM auth on MSK, you typically use the IAM bootstrap brokers.
        { name = "BOOTSTRAP_BROKERS", value = aws_msk_cluster.this.bootstrap_brokers_sasl_iam }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.ecs.name
          awslogs-region        = data.aws_region.current.name
          awslogs-stream-prefix = "producer"
        }
      }
    }
  ])

  tags = local.merged_tags
}

resource "aws_ecs_service" "producer" {
  name            = "${var.name}-producer"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.producer.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [for s in aws_subnet.private : s.id]
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = false
  }

  depends_on = [aws_msk_cluster.this]

  tags = local.merged_tags
}
