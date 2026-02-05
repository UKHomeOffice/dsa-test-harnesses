# Terraform Module: Lambda S3 Writer

Terraform module that deploys an AWS Lambda function which writes
objects to a specified S3 bucket. Optionally configures an EventBridge
schedule to invoke the function on a cron/rate expression. The Lambda is
always deployed inside an **existing VPC** across **three private
subnets**.

## Architecture of Deployed Module
![System Architecture](docs/architecture.svg)

## Features

-   Lambda in VPC across exactly 3 private subnets
-   Subnet strategy (choose one):
    -   Provide 3 existing subnet IDs, or
    -   Provide 3 CIDR blocks to create 3 new private subnets in an
        existing VPC
-   Least-privilege IAM to write to the provided S3 bucket
-   Optional EventBridge schedule via `schedule_expression`
-   Flexible packaging:
    -   Terraform zips source using `archive_file`
    -   CI/CD provides a prebuilt zip (local path) or a prebuilt zip
        uploaded to S3 or an image URI from ECR

## Requirements

-   Terraform \>= 1.5
-   AWS provider \>= 5.x
-   Archive provider \>= 2.x

## What this module creates

-   aws_lambda_function
-   IAM Role and policies:
    -   AWS managed: AWSLambdaBasicExecutionRole,
        AWSLambdaVPCAccessExecutionRole
    -   Inline: S3 write permissions for the provided bucket
-   CloudWatch Log Group for the Lambda
-   Security Group for Lambda ENIs
-   Optional EventBridge Rule + Target + Lambda Permission (when
    schedule_expression is provided)
-   Optional 3 private subnets in the given VPC (when subnet_cidr_blocks
    is provided)
-   Optional route table associations for created subnets (when
    route_table_ids is provided)

## Usage

### Example 1: Existing subnets + Terraform packaging

``` hcl
module "writer" {
  source = "../../modules/lambda_s3_writer"

  name        = "my-s3-writer"
  bucket_name = "my-target-bucket"

  vpc_id     = "vpc-123456"
  subnet_ids = ["subnet-a", "subnet-b", "subnet-c"]

  package_mode = "terraform_archive"
  source_dir   = "${path.module}/lambda_src"

  tags = {
    Project = "demo"
    Owner   = "platform"
  }
}
```

### Example 2: Create 3 private subnets from CIDRs

``` hcl
module "writer" {
  source = "../../modules/lambda_s3_writer"

  name        = "my-s3-writer"
  bucket_name = "my-target-bucket"

  vpc_id             = "vpc-123456"
  subnet_cidr_blocks = ["10.0.10.0/24", "10.0.11.0/24", "10.0.12.0/24"]

  availability_zone_names = ["eu-west-2a", "eu-west-2b", "eu-west-2c"]

  package_mode = "terraform_archive"
  source_dir   = "${path.module}/lambda_src"
}
```

### Example 3: Scheduled invocation + CI artifact in S3

``` hcl
module "writer" {
  source = "../../modules/lambda_s3_writer"

  name        = "my-s3-writer"
  bucket_name = "my-target-bucket"

  vpc_id     = "vpc-123456"
  subnet_ids = ["subnet-a", "subnet-b", "subnet-c"]

  schedule_expression = "cron(0 6 * * ? *)"

  package_mode               = "s3_existing_zip"
  s3_existing_package_bucket = "my-lambda-artifacts"
  s3_existing_package_key    = "my-s3-writer/${var.artifact_version}/function.zip"
}
```

### Example 4: Image-based Lambda example

``` hcl
module "writer" {
  source = "../../modules/lambda_s3_writer"

  name        = "my-s3-writer"
  bucket_name = "my-target-bucket"

  vpc_id     = "vpc-123456"
  subnet_ids = ["subnet-a", "subnet-b", "subnet-c"]

  package_type = "Image"
  image_uri    = "123456789012.dkr.ecr.eu-west-2.amazonaws.com/my-repo:1.2.3"
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.24.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 6.24.0 |
| <a name="provider_databricks"></a> [databricks](#provider\_databricks) | ~> 1.84 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_kms_key.databricks_managed_services_key](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_kms_key.databricks_workspace_storage_key](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_kms_alias.databricks_managed_services_key_alias](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_alias) | resource |
| [aws_kms_alias.databricks_workspace_storage_key_alias](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_alias) | resource |
| [databricks_mws_customer_managed_keys.managed_services](https://registry.terraform.io/providers/databricks/databricks/latest/docs/resources/mws_customer_managed_keys) | resource |
| [databricks_mws_customer_managed_keys.workspace_storage](https://registry.terraform.io/providers/databricks/databricks/latest/docs/resources/mws_customer_managed_keys) | resource |
| [aws_subnet.private_backend](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_security_group.databricks_classic_compute](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.databricks_backend_vpce](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_route_table_association.private_backend](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_vpc_endpoint.databricks_rest](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint) | resource |
| [aws_vpc_endpoint.databricks_scc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint) | resource |
| [databricks_mws_vpc_endpoint.databricks_rest](https://registry.terraform.io/providers/databricks/databricks/latest/docs/resources/mws_vpc_endpoint) | resource |
| [databricks_mws_vpc_endpoint.databricks_scc](https://registry.terraform.io/providers/databricks/databricks/latest/docs/resources/mws_vpc_endpoint) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_name"></a> [name](#input\_name) | Base name/prefix for resources | `string` | n/a | yes |
| <a name="input_bucket_name"></a> [bucket\_name](#input\_bucket\_name) | S3 bucket name Lambda writes to | `string` | n/a | yes |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | Existing VPC ID | `string` | n/a | yes |
| <a name="input_subnet_ids"></a> [subnet\_ids](#input\_subnet\_ids) | Exactly 3 existing private subnet IDs | `list(string)` | `[]` | no |
| <a name="input_subnet_cidr_blocks"></a> [subnet\_cidr\_blocks](#input\_subnet\_cidr\_blocks) | Exactly 3 CIDRs to create subnets | `list(string)` | `[]` | no |
| <a name="input_availability_zone_names"></a> [availability\_zone\_names](#input\_availability\_zone\_names) | Optional: exactly 3 AZ names | `list(string)` | `[]` | no |
| <a name="input_route_table_ids"></a> [route\_table\_ids](#input\_route\_table\_ids) | Optional: route table IDs | `list(string)` | `[]` | no |
| <a name="input_security_group_ids"></a> [security\_group\_ids](#input\_security\_group\_ids) | Additional SG IDs | `list(string)` | `[]` | no |
| <a name="input_schedule_expression"></a> [schedule\_expression](#input\_schedule\_expression) | Optional schedule | `string` | n/a | no |
| <a name="input_lambda_runtime"></a> [lambda\_runtime](#input\_lambda\_runtime) | Lambda runtime | `string` | `python3.12` | no |
| <a name="input_lambda_handler"></a> [lambda\_handler](#input\_lambda\_handler) | Lambda handler | `string` | `app.handler` | no |
| <a name="input_lambda_timeout"></a> [lambda\_timeout](#input\_lambda\_timeout) | Timeout seconds | `number` | 30 | no |
| <a name="input_lambda_memory_size"></a> [lambda\_memory\_size](#input\_lambda\_memory\_size) | Memory MB | `number` | 128 | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Additional environment variables | `map(string)` | `{}` | no |
| <a name="input_package_mode"></a> [package\_mode](#input\_package\_mode) | Packaging mode | `string` | `terraform_archive` | no |
| <a name="input_source_dir"></a> [source\_dir](#input\_source\_dir) | Source dir for terraform archive | `string` | null | no |
| <a name="input_local_existing_package_path"></a> [local\_existing\_package\_path](#input\_local\_existing\_package\_path) | Path to zip | `string` | null | no |
| <a name="input_s3_existing_package_bucket"></a> [s3\_existing\_package\_bucket](#input\_s3\_existing\_package\_bucket) | Artifact bucket | `string` | null | no |
| <a name="input_s3_existing_package_key"></a> [s3\_existing\_package\_key](#input\_s3\_existing\_package\_key) | Artifact key | `string` | null | no |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of tags to add to all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_lambda_function_name"></a> [lambda\_function\_name](#output\_lambda\_function\_name) | Lambda function name |
| <a name="output_lambda_function_arn"></a> [lambda\_function\_arn](#output\_lambda\_function\_arn) | Lambda function ARN |
| <a name="output_security_group_id"></a> [security\_group\_id](#output\_security\_group\_id) | Security group created for Lambda |
| <a name="output_subnet_ids"></a> [subnet\_ids](#output\_subnet\_ids) | The 3 subnet IDs used by Lambda |
| <a name="output_event_rule_arn"></a> [event\_rule\_arn](#output\_event\_rule\_arn) | EventBridge rule ARN (if enabled) |
<!-- END_TF_DOCS -->

## Operational Notes

-   Private subnet behavior depends on routing. Ensure NAT or VPC endpoints exist.
-   Lambda requires ENI permissions; module attaches AWSLambdaVPCAccessExecutionRole.
-   Module sets `BUCKET_NAME` environment variable automatically.

## Security Considerations

-   IAM is least-privilege for S3 write access.
-   Default SG has no ingress and open egress; adjust as needed.

## Versioning Strategy for Artifacts

Use immutable keys when using `s3_existing_zip` to ensure reproducible deployments, for example:

-   my-func/2026-02-05-`<gitsha>`{=html}/function.zip
