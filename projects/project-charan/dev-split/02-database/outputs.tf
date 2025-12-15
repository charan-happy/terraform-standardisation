# Database outputs for compute layer

output "endpoint" {
  description = "RDS endpoint"
  value       = module.rds.endpoint
}

output "address" {
  description = "RDS address"
  value       = module.rds.address
}

output "port" {
  description = "RDS port"
  value       = module.rds.port
}

output "db_name" {
  description = "Database name"
  value       = module.rds.db_name
}

output "security_group_id" {
  description = "Database security group ID"
  value       = module.db_security_group.id
}
