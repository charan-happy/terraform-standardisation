output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

output "rds_endpoint" {
  description = "RDS database endpoint"
  value       = module.rds.endpoint
  sensitive   = false
}

output "rds_port" {
  description = "RDS database port"
  value       = module.rds.port
}

output "web_server_ids" {
  description = "Web server instance IDs"
  value       = module.web_servers.instance_ids
}

output "web_server_private_ips" {
  description = "Web server private IPs"
  value       = module.web_servers.private_ips
}

output "web_server_public_ips" {
  description = "Web server public IPs"
  value       = module.web_servers.public_ips
}
