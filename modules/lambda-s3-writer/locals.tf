locals {
  # Mutually exclusive subnet inputs:
  using_existing_subnets = length(var.subnet_ids) == 3
  using_new_subnets      = length(var.subnet_cidr_blocks) == 3

  azs = length(var.availability_zone_names) == 3 ? var.availability_zone_names : slice(data.aws_availability_zones.available.names, 0, 3)

  # schedule enabled if non-null and non-empty
  schedule_enabled = var.schedule_expression != null && trim(var.schedule_expression) != ""

  # Packaging selection
  is_image = var.package_type == "Image"
  is_zip   = var.package_type == "Zip"

  use_archive   = var.package_mode == "terraform_archive"
  use_local_zip = var.package_mode == "local_existing_zip"
  use_s3_zip    = var.package_mode == "s3_existing_zip"

  lambda_filename         = local.use_archive ? data.archive_file.lambda_zip[0].output_path : (local.use_local_zip ? var.local_existing_package_path : null)
  lambda_source_code_hash = local.use_archive ? data.archive_file.lambda_zip[0].output_base64sha256 : (local.use_local_zip ? filebase64sha256(var.local_existing_package_path) : null)
}
