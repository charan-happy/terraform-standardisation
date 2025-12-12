
resource "aws_db_subnet_group" "main" {
  name       = "${var.identifier}-subnet-group"
  subnet_ids = var.subnet_ids

  tags = merge(
    var.tags,
    {
      Name = "${var.identifier}-db-subnet-group"
    }
  )
}

resource "aws_db_instance" "main" {
  identifier     = var.identifier
  engine         = var.engine
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage     = var.allocated_storage
  storage_type          = var.storage_type
  storage_encrypted     = true
  # kms_key_id only used if provided, otherwise uses AWS managed key
  kms_key_id            = var.kms_key_id != null && var.kms_key_id != "" ? var.kms_key_id : null

  db_name  = var.db_name
  username = var.username
  password = var.password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = var.security_group_ids

  # Backup configuration
  backup_retention_period = var.backup_retention_days
  backup_window           = var.backup_window
  maintenance_window      = var.maintenance_window
  copy_tags_to_snapshot   = true

  # HA configuration
  multi_az = var.multi_az

  # Deletion protection
  deletion_protection = var.deletion_protection

  # Monitoring
  enabled_cloudwatch_logs_exports = var.enabled_cloudwatch_logs_exports
  monitoring_interval              = var.monitoring_interval
  monitoring_role_arn              = var.monitoring_interval > 0 ? var.monitoring_role_arn : null

  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.identifier}-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"

  tags = merge(
    var.tags,
    {
      Name = var.identifier
    }
  )

  depends_on = [aws_db_subnet_group.main]
}

# Enhanced monitoring requires a monitoring_role_arn, not db_instance_role_association
# This resource should be removed or replaced with proper enhanced monitoring setup
# resource "aws_db_instance_role_association" "monitoring" {
#   count              = var.enable_iam_monitoring ? 1 : 0
#   db_instance_identifier = aws_db_instance.main.id
#   feature_name       = "s3Import"
#   role_arn           = var.monitoring_role_arn
# }
