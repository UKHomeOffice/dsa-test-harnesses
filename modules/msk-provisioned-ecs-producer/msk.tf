resource "aws_security_group" "msk" {
  name        = "${var.name}-msk-sg"
  description = "MSK broker SG"
  vpc_id      = var.vpc_id

  tags = merge(
    local.merged_tags,
    {
      Name = "${var.name}-msk-sg"
    }
  )
}

resource "aws_security_group" "ecs" {
  name        = "${var.name}-ecs-sg"
  description = "ECS tasks SG"
  vpc_id      = var.vpc_id

  tags = merge(
    local.merged_tags,
    {
      Name = "${var.name}-ecs-sg"
    }
  )
}

# Allow ECS -> MSK (SASL/IAM over TLS = 9098)
resource "aws_security_group_rule" "msk_ingress_from_ecs" {
  type                     = "ingress"
  security_group_id        = aws_security_group.msk.id
  from_port                = 9098
  to_port                  = 9098
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.ecs.id
  description              = "Allow ECS tasks to reach MSK brokers (9098 SASL/IAM)"
}

resource "aws_security_group_rule" "ecs_egress_all" {
  type              = "egress"
  security_group_id = aws_security_group.ecs.id
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow outbound"
}

resource "aws_security_group_rule" "msk_egress_all" {
  type              = "egress"
  security_group_id = aws_security_group.msk.id
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow outbound"
}

resource "aws_kms_key" "msk" {
  description             = "KMS key for MSK at-rest encryption"
  deletion_window_in_days = 7
  tags                    = local.merged_tags
}

resource "aws_cloudwatch_log_group" "msk" {
  name              = "/aws/msk/${var.name}"
  retention_in_days = var.log_retention_days
  tags              = local.merged_tags
}

resource "aws_msk_cluster" "this" {
  cluster_name           = var.name
  kafka_version          = var.msk_kafka_version
  number_of_broker_nodes = var.msk_broker_count

  broker_node_group_info {
    instance_type   = var.msk_broker_instance_type
    client_subnets  = [for s in aws_subnet.private : s.id]
    security_groups = [aws_security_group.msk.id]

    storage_info {
      ebs_storage_info {
        volume_size = var.msk_ebs_volume_size
      }
    }
  }

  encryption_info {
    encryption_at_rest_kms_key_arn = aws_kms_key.msk.arn
    encryption_in_transit {
      client_broker = "TLS"
      in_cluster    = true
    }
  }

  client_authentication {
    sasl {
      iam = true
    }
  }

  logging_info {
    broker_logs {
      cloudwatch_logs {
        enabled   = true
        log_group = aws_cloudwatch_log_group.msk.name
      }
    }
  }

  tags = local.merged_tags
}
