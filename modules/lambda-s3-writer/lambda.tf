resource "aws_lambda_function" "this" {
  function_name = var.name
  role          = aws_iam_role.lambda.arn

  timeout     = var.lambda_timeout
  memory_size = var.lambda_memory_size

  vpc_config {
    subnet_ids         = local.effective_subnet_ids
    security_group_ids = concat([aws_security_group.lambda.id], var.security_group_ids)
  }

  environment {
    variables = merge(var.environment, { BUCKET_NAME = var.bucket_name })
  }

  # --- Package selection ---
  package_type = var.package_type

  # Zip-only settings
  runtime = local.is_zip ? var.lambda_runtime : null
  handler = local.is_zip ? var.lambda_handler : null

  # Image-only setting
  image_uri = local.is_image ? var.image_uri : null

  dynamic "image_config" {
    for_each = local.is_image ? [1] : []
    content {
      command           = var.image_command
      entry_point       = var.image_entry_point
      working_directory = var.image_working_directory
    }
  }

  # Zip artifact sources (only when Zip)
  filename         = (local.is_zip && !local.use_s3_zip) ? local.lambda_filename : null
  source_code_hash = (local.is_zip && !local.use_s3_zip) ? local.lambda_source_code_hash : null

  s3_bucket = (local.is_zip && local.use_s3_zip) ? var.s3_existing_package_bucket : null
  s3_key    = (local.is_zip && local.use_s3_zip) ? var.s3_existing_package_key : null

  depends_on = [
    aws_cloudwatch_log_group.lambda
  ]

  tags = var.tags

  lifecycle {
    precondition {
      condition = (
        # Image requirements
        (!local.is_image || try(trimspace(var.image_uri), "") != "") &&

        # Zip requirements
        (!local.is_zip || (
          (!local.use_archive || try(trimspace(var.source_dir), "") != "") &&
          (!local.use_local_zip || try(trimspace(var.local_existing_package_path), "") != "") &&
          (!local.use_s3_zip || (
            try(trimspace(var.s3_existing_package_bucket), "") != "" &&
            try(trimspace(var.s3_existing_package_key), "") != ""
          ))
        ))
      )
      error_message = "Invalid packaging inputs. If package_type=Image, set image_uri. If package_type=Zip, provide the required inputs for the selected package_mode."
    }
  }
}

# Optional EventBridge schedule
resource "aws_iam_role" "schedule" {
  count = local.schedule_enabled ? 1 : 0

  name = "${var.name}-scheduler-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "scheduler.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "schedule" {
  count = local.schedule_enabled ? 1 : 0

  name = "${var.name}-scheduler-policy"
  role = aws_iam_role.schedule[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = aws_lambda_function.this.arn
      }
    ]
  })
}

resource "aws_scheduler_schedule" "schedule" {
  count = local.schedule_enabled ? 1 : 0

  name                = "${var.name}-schedule"
  group_name          = "default"
  schedule_expression = var.schedule_expression
  state               = "ENABLED"

  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = aws_lambda_function.this.arn
    role_arn = aws_iam_role.schedule[0].arn
  }
}
