resource "aws_iam_role" "ecs_task_execution" {
  name = "${var.name}-ecs-exec"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
  tags = local.merged_tags
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "ecs_task" {
  name = "${var.name}-ecs-task"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
  tags = local.merged_tags
}

# MSK IAM authorization policy
resource "aws_iam_policy" "msk_access" {
  name        = "${var.name}-msk-access"
  description = "Allow ECS task to connect and write to MSK via IAM"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Control-plane read (handy for debugging / discovering brokers)
      {
        Effect = "Allow"
        Action = [
          "kafka:DescribeCluster",
          "kafka:GetBootstrapBrokers",
          "kafka:ListClusters"
        ]
        Resource = "*"
      },
      # Data-plane (MSK IAM auth)
      {
        Effect = "Allow"
        Action = [
          "kafka-cluster:Connect",
          "kafka-cluster:DescribeCluster",
          "kafka-cluster:DescribeClusterDynamicConfiguration"
        ]
        Resource = [
          aws_msk_cluster.this.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kafka-cluster:DescribeTopic",
          "kafka-cluster:WriteData",
          "kafka-cluster:WriteDataIdempotently",
          "kafka-cluster:ReadData"
        ]
        Resource = [
          "${local.msk_topic_arn_prefix}/${var.producer_topic}"
        ]
      }
    ]
  })
  tags = local.merged_tags
}

resource "aws_iam_role_policy_attachment" "ecs_task_msk_access" {
  role       = aws_iam_role.ecs_task.name
  policy_arn = aws_iam_policy.msk_access.arn
}
