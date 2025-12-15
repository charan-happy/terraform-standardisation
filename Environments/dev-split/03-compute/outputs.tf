output "web_server_instance_ids" {
  description = "Web server instance IDs"
  value       = module.web_server.instance_ids
}

output "web_server_public_ips" {
  description = "Web server public IPs"
  value       = module.web_server.public_ips
}

output "web_server_private_ips" {
  description = "Web server private IPs"
  value       = module.web_server.private_ips
}

output "web_security_group_id" {
  description = "Web security group ID"
  value       = module.web_security_group.id
}
