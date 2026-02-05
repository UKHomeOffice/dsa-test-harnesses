data "aws_availability_zones" "available" {
  state = "available"
}

# terraform_archive -> build zip from source_dir
data "archive_file" "lambda_zip" {
  count       = (local.is_zip && local.use_archive) ? 1 : 0
  type        = "zip"
  source_dir  = var.source_dir
  output_path = "${path.module}/.terraform-build/${var.name}.zip"
}
