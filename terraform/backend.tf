terraform {
  required_version = "~> 1.3.6"
  #  backend "s3" {
  #    encrypt = true
  #    region  = "eu-west-2"
  #  }
  required_providers {
    #    aws = {
    #      version = ">= 4.46.0"
    #    }
    null = {
      version = ">= 3.2.1"
    }
  }
}
