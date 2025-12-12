
output "endpoint" {
  description = "The RDS endpoint address"
  value       = aws_db_instance.main.endpoint
  sensitive   = false
}

output "port" {
  description = "The RDS port"
  value       = aws_db_instance.main.port
}

output "resource_id" {
  description = "The RDS Resource ID"
  value       = aws_db_instance.main.resource_id
}

output "db_name" {
  description = "The database name"
  value       = aws_db_instance.main.db_name
}

output "username" {
  description = "The master username"
  value       = aws_db_instance.main.username
  sensitive   = true
}

output "instance_id" {
  description = "The RDS instance ID"
  value       = aws_db_instance.main.id
}


