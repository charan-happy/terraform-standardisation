terraform {
  backend "s3" {
    bucket  = "terraform-state-charan-492267476800"
    key     = "project-charan/dev/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
}
