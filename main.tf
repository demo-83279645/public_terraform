# -------------------------------
# Terraform configuration
# -------------------------------
terraform {
  required_version = ">=1.9"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>5.0"
    }
  }

/*   backend "s3" {
    bucket  = "my-wordpress-tfstate-bucket-11272156"
    key     = "my-wordpress-demo.tfstate"
    region  = "ap-northeast-1"
    profile = "terraform"
  } */
 }

# -------------------------------
# Provider
# -------------------------------
provider "aws" {
#  profile = "terraform"
  region  = var.aws_region

}

provider "aws" {
  alias   = "virginia"
  region  = var.aws_region_virginia
}


