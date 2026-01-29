# github-terraform-template

This repo contains a template Terraform pipeline. To modify this template, please either create an issue or submit a pull request with the changes.

### terraform-checks.yml ###
This workflow will run when any new commit is pushed to any branch. The tools run are listed below.

| Tool              | Description              |
|-------------------|--------------------------|
| terraform fmt     | format terraform         |
| terraform validate | validate terraform       |
| tflnt             | lint terraform           |
| tfsec             | run static code analysis |
| checkov           | run static code analysis |

### terraform-main.yml ###
This workflow is used to deploy Terraform to your environment. The steps run will depend on the GitHub event that triggered it, these are detailed below.
This workflow will only trigger when changes are made to tf files in your working directory, this is set to ```./terraform``` by default.
Note that this calls ```terraform-template.yml``` so that it can be easily reused with multiple Terraform root modules.

| Step            | Description               | Trigger             |
|-----------------|---------------------------|---------------------|
| terraform plan  | create terraform execution plan | pull request        |
| terraform apply | apply terraform with auto approve | merge pull request  |
| tf summariser   | add a summary of terraform changes to pr | pull request        |
| infracost       | add a cost summary to pr  | pull request        |

### Infracost ###

Note that the steps to run Infracost are commented out in ```terraform-template.yml``` as an API key is required.
You will need to set an API key in your GitHub repo secrets called ```INFRACOST_API_KEY```
This variable will need to be uncommented in ```terraform-main.yml``` and ```terraform-template.yml```

### Terraform State Backend ###

A backend should be configured to store Terraform state remotely. An example for AWS S3 is commented out in ```backend.tf```
You will need set the following variables in your GitHub repo secrets:

 - ```TERRAFORM_STATE_BUCKET ```
 - ```TERRAFORM_STATE_KEY```
 - ```TERRAFORM_STATE_DYNAMODB_TABLE ```

These variables will need to be uncommented in ```terraform-checks.yml```, ```terraform-main.yml``` and ```terraform-template.yml``` (both for the variable declaration and as arguments to terraform init)

### AWS Credentials ###

```aws-actions/configure-aws-credentials@v1``` can be used to configure AWS credentials. An example is commented out in ```terraform-checks.yml``` and ```terraform-template.yml```