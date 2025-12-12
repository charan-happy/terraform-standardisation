
output "instance_ids" {
  description = "List of EC2 instance IDs"
  value       = aws_instance.main[*].id
}

output "private_ips" {
  description = "List of private IP addresses"
  value       = aws_instance.main[*].private_ip
}

output "public_ips" {
  description = "List of public IP addresses"
  value       = aws_instance.main[*].public_ip
}

output "security_group_id" {
  description = "Security group ID"
  value       = var.security_group_id
}

