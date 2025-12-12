terraform {
  backend "s3" {
    bucket         = "terraform-state-charan-492267476800"
    key            = "project-charan/staging/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}
