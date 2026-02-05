variable "name" {
  description = "Base name/prefix for resources."
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources."
  type        = map(string)
  default     = {}
}

variable "bucket_name" {
  description = "Target S3 bucket name the Lambda writes to."
  type        = string
}

#----------------------------------------------------------------------------
# Networking
#----------------------------------------------------------------------------

variable "vpc_id" {
  description = "Existing VPC ID where Lambda runs."
  type        = string
}

variable "subnet_ids" {
  description = "Exactly 3 existing private subnet IDs. Mutually exclusive with subnet_cidr_blocks."
  type        = list(string)
  default     = []

  validation {
    condition     = length(var.subnet_ids) == 0 || length(var.subnet_ids) == 3
    error_message = "If subnet_ids is provided, it must contain exactly 3 subnet IDs."
  }

  validation {
    condition     = !(length(var.subnet_ids) > 0 && length(var.subnet_cidr_blocks) > 0)
    error_message = "Provide only one of subnet_ids or subnet_cidr_blocks (not both)."
  }
}

variable "subnet_cidr_blocks" {
  description = "Exactly 3 CIDR blocks to create new private subnets. Mutually exclusive with subnet_ids."
  type        = list(string)
  default     = []

  validation {
    condition     = length(var.subnet_cidr_blocks) == 0 || length(var.subnet_cidr_blocks) == 3
    error_message = "If subnet_cidr_blocks is provided, it must contain exactly 3 CIDR blocks."
  }

  validation {
    condition     = !(length(var.subnet_ids) > 0 && length(var.subnet_cidr_blocks) > 0)
    error_message = "Provide only one of subnet_ids or subnet_cidr_blocks (not both)."
  }
}

variable "availability_zone_names" {
  description = "Optional: Exactly 3 AZ names to place subnets in, e.g. [\"eu-west-2a\",\"eu-west-2b\",\"eu-west-2c\"]. If not set, module will pick the first 3 available AZs."
  type        = list(string)
  default     = []

  validation {
    condition     = length(var.availability_zone_names) == 0 || length(var.availability_zone_names) == 3
    error_message = "If availability_zone_names is provided, it must contain exactly 3 AZ names."
  }
}

variable "route_table_ids" {
  description = "Optional: Exactly 3 route table IDs to associate to created subnets (only used when subnet_cidr_blocks is set). If omitted, no associations are created."
  type        = list(string)
  default     = []

  validation {
    condition     = length(var.route_table_ids) == 0 || length(var.route_table_ids) == 3
    error_message = "If route_table_ids is provided, it must contain exactly 3 route table IDs."
  }
}

variable "security_group_ids" {
  description = "Optional: Additional security group IDs to attach to Lambda ENIs. Module always creates one SG; these are appended."
  type        = list(string)
  default     = []
}

#----------------------------------------------------------------------------
# Lambda
#----------------------------------------------------------------------------

variable "lambda_runtime" {
  description = "Lambda runtime (ignored if package_type is Image)."
  type        = string
  default     = "python3.12"
}

variable "lambda_handler" {
  description = "Lambda handler (ignored if package_type is Image)."
  type        = string
  default     = "app.handler"
}

variable "lambda_timeout" {
  description = "Lambda timeout (seconds)."
  type        = number
  default     = 30
}

variable "lambda_memory_size" {
  description = "Lambda memory (MB)."
  type        = number
  default     = 128
}

variable "environment" {
  description = "Environment variables for the Lambda."
  type        = map(string)
  default     = {}
}

variable "schedule_expression" {
  description = "Optional: EventBridge schedule expression, e.g. cron(0 6 * * ? *) or rate(5 minutes). If null/empty, no schedule is created."
  type        = string
  default     = null
}

variable "package_mode" {
  description = <<EOT
How Lambda code is packaged:
- "terraform_archive": use archive_file on source_dir
- "local_existing_zip": use a prebuilt zip at local_existing_package_path (e.g. produced by CI)
- "s3_existing_zip": use a prebuilt zip uploaded to S3 (s3_existing_package_bucket/key)
EOT
  type        = string
  default     = "terraform_archive"

  validation {
    condition     = contains(["terraform_archive", "local_existing_zip", "s3_existing_zip"], var.package_mode)
    error_message = "package_mode must be one of: terraform_archive, local_existing_zip, s3_existing_zip."
  }
}

variable "source_dir" {
  description = "Local directory of Lambda source (used when package_mode=terraform_archive)."
  type        = string
  default     = null
}

variable "local_existing_package_path" {
  description = "Path to an existing zip file (used when package_mode=local_existing_zip)."
  type        = string
  default     = null
}

variable "s3_existing_package_bucket" {
  description = "S3 bucket containing the prebuilt zip (used when package_mode=s3_existing_zip)."
  type        = string
  default     = null
}

variable "s3_existing_package_key" {
  description = "S3 key for the prebuilt zip (used when package_mode=s3_existing_zip)."
  type        = string
  default     = null
}

variable "package_type" {
  description = "Lambda package type. Use Zip for zip artifacts or Image for ECR container images."
  type        = string
  default     = "Zip"

  validation {
    condition     = contains(["Zip", "Image"], var.package_type)
    error_message = "package_type must be either Zip or Image."
  }
}

variable "image_uri" {
  description = "ECR image URI for Image-based Lambda (required when package_type=Image). Example: 123456789012.dkr.ecr.eu-west-2.amazonaws.com/my-repo:tag"
  type        = string
  default     = null
}

variable "image_command" {
  description = "Optional override for the container ENTRYPOINT/CMD (Lambda image config command)."
  type        = list(string)
  default     = null
}

variable "image_entry_point" {
  description = "Optional entry point override (Lambda image config entry_point)."
  type        = list(string)
  default     = null
}

variable "image_working_directory" {
  description = "Optional working directory override (Lambda image config working_directory)."
  type        = string
  default     = null
}
