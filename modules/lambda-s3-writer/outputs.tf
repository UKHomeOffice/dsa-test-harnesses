output "lambda_function_name" {
  description = "Lambda function name."
  value       = aws_lambda_function.this.function_name
}

output "lambda_function_arn" {
  description = "Lambda function ARN."
  value       = aws_lambda_function.this.arn
}

output "security_group_id" {
  description = "Security group ID created for the Lambda."
  value       = aws_security_group.lambda.id
}

output "subnet_ids" {
  description = "The 3 subnet IDs used by the Lambda."
  value       = local.effective_subnet_ids
}

output "event_rule_arn" {
  description = "EventBridge rule ARN if schedule is enabled."
  value       = try(aws_cloudwatch_event_rule.schedule[0].arn, null)
}
