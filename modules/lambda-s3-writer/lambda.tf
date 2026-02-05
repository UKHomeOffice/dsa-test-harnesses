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
        (!local.is_image || (var.image_uri != null && trimspace(var.image_uri) != "")) &&

        # Zip requirements
        (!local.is_zip || (
          (!local.use_archive || (var.source_dir != null && trimspace(var.source_dir) != "")) &&
          (!local.use_local_zip || (var.local_existing_package_path != null && trimspace(var.local_existing_package_path) != "")) &&
          (!local.use_s3_zip || (
            (var.s3_existing_package_bucket != null && trimspace(var.s3_existing_package_bucket) != "") &&
            (var.s3_existing_package_key != null && trimspace(var.s3_existing_package_key) != "")
          ))
        ))
      )
      error_message = "Invalid packaging inputs. If package_type=Image, set image_uri. If package_type=Zip, provide the required inputs for the selected package_mode."
    }
  }
}

# Optional EventBridge schedule
resource "aws_cloudwatch_event_rule" "schedule" {
  count               = local.schedule_enabled ? 1 : 0
  name                = "${var.name}-schedule"
  schedule_expression = var.schedule_expression
  tags                = var.tags
}

resource "aws_cloudwatch_event_target" "schedule" {
  count = local.schedule_enabled ? 1 : 0
  rule  = aws_cloudwatch_event_rule.schedule[0].name
  arn   = aws_lambda_function.this.arn
}

resource "aws_lambda_permission" "allow_events" {
  count         = local.schedule_enabled ? 1 : 0
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.this.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.schedule[0].arn
}