output "s3_bucket_name" {
  description = "Name of the S3 bucket for Terraform state"
  value       = aws_s3_bucket.terraform_state.bucket
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.terraform_state.arn
}

output "s3_bucket_region" {
  description = "Region of the S3 bucket"
  value       = aws_s3_bucket.terraform_state.region
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB table for state locking"
  value       = var.enable_state_locking ? aws_dynamodb_table.terraform_locks[0].name : "disabled"
}

output "dynamodb_table_arn" {
  description = "ARN of the DynamoDB table"
  value       = var.enable_state_locking ? aws_dynamodb_table.terraform_locks[0].arn : "disabled"
}

output "key_pair_names" {
  description = "Names of the created EC2 key pairs"
  value       = [for k in aws_key_pair.ec2_keys : k.key_name]
}

output "key_pair_ids" {
  description = "IDs of the created EC2 key pairs"
  value       = { for k, v in aws_key_pair.ec2_keys : k => v.id }
}

output "private_key_files" {
  description = "Locations of the private key files"
  value       = { for k, v in local_sensitive_file.private_keys : k => v.filename }
  sensitive   = true
}

output "backend_configuration" {
  description = "Backend configuration for your Terraform projects"
  value = {
    bucket         = aws_s3_bucket.terraform_state.bucket
    region         = data.aws_region.current.name
    dynamodb_table = var.enable_state_locking ? aws_dynamodb_table.terraform_locks[0].name : "disabled"
    locking_enabled = var.enable_state_locking
  }
}

output "next_steps" {
  description = "Next steps to use the created backend"
  value = <<-EOT
    
    ✅ Bootstrap Complete!
    
    Backend Resources Created:
    - S3 Bucket: ${aws_s3_bucket.terraform_state.bucket}
    - DynamoDB Table: ${var.enable_state_locking ? aws_dynamodb_table.terraform_locks[0].name : "DISABLED (no state locking)"}
    - EC2 Key Pairs: ${join(", ", [for k in aws_key_pair.ec2_keys : k.key_name])}
    
    ${!var.enable_state_locking ? "⚠️  WARNING: State locking is DISABLED. Not recommended for team environments!\n    Enable with: enable_state_locking = true\n" : ""}
    Private Keys Saved To:
    - bootstrap/keys/*.pem
    
    ⚠️  IMPORTANT: Secure your private keys!
    - chmod 400 bootstrap/keys/*.pem
    - Add to .gitignore
    - Store securely (password manager, AWS Secrets Manager)
    
    Next Steps:
    1. Backend config files have been auto-generated in backend-config/
    2. Project backend.tf files have been updated
    3. Navigate to your project: cd ../projects/project-charan/dev
    4. Initialize with backend: terraform init
    5. Deploy your infrastructure: terraform plan && terraform apply
    
    To use the backend in other projects:
    
    terraform {
      backend "s3" {
        bucket  = "${aws_s3_bucket.terraform_state.bucket}"
        key     = "path/to/your/terraform.tfstate"
        region  = "${data.aws_region.current.name}"
        encrypt = true
      }
    }
  EOT
}
