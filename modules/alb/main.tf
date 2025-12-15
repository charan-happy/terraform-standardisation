# Application Load Balancer Module
# Enterprise-grade ALB with target groups and listeners

resource "aws_lb" "main" {
  name               = var.name
  internal           = var.internal
  load_balancer_type = "application"
  security_groups    = var.security_group_ids
  subnets            = var.subnet_ids

  enable_deletion_protection = var.enable_deletion_protection
  enable_http2              = var.enable_http2
  enable_cross_zone_load_balancing = true

  access_logs {
    bucket  = var.access_logs_bucket
    prefix  = var.access_logs_prefix
    enabled = var.enable_access_logs
  }

  tags = merge(
    var.tags,
    {
      Name = var.name
    }
  )
}

# Target group for instances
resource "aws_lb_target_group" "main" {
  for_each = var.target_groups

  name     = "${var.name}-${each.key}"
  port     = each.value.port
  protocol = each.value.protocol
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = each.value.health_check.healthy_threshold
    unhealthy_threshold = each.value.health_check.unhealthy_threshold
    timeout             = each.value.health_check.timeout
    interval            = each.value.health_check.interval
    path                = each.value.health_check.path
    matcher             = each.value.health_check.matcher
    protocol            = each.value.health_check.protocol
  }

  stickiness {
    type            = "lb_cookie"
    cookie_duration = each.value.stickiness_duration
    enabled         = each.value.enable_stickiness
  }

  deregistration_delay = each.value.deregistration_delay

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-${each.key}"
    }
  )
}

# Attach instances to target groups
resource "aws_lb_target_group_attachment" "main" {
  for_each = var.target_attachments

  target_group_arn = aws_lb_target_group.main[each.value.target_group_key].arn
  target_id        = each.value.instance_id
  port             = each.value.port
}

# HTTP listener (redirect to HTTPS)
resource "aws_lb_listener" "http" {
  count = var.create_http_listener ? 1 : 0

  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = var.redirect_http_to_https ? "redirect" : "forward"

    dynamic "redirect" {
      for_each = var.redirect_http_to_https ? [1] : []
      content {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }

    target_group_arn = var.redirect_http_to_https ? null : aws_lb_target_group.main[var.default_target_group_key].arn
  }
}

# HTTPS listener
resource "aws_lb_listener" "https" {
  count = var.create_https_listener ? 1 : 0

  load_balancer_arn = aws_lb.main.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = var.ssl_policy
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main[var.default_target_group_key].arn
  }
}

# Listener rules for path-based routing
resource "aws_lb_listener_rule" "main" {
  for_each = var.listener_rules

  listener_arn = var.create_https_listener ? aws_lb_listener.https[0].arn : aws_lb_listener.http[0].arn
  priority     = each.value.priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main[each.value.target_group_key].arn
  }

  dynamic "condition" {
    for_each = each.value.path_patterns != null ? [1] : []
    content {
      path_pattern {
        values = each.value.path_patterns
      }
    }
  }

  dynamic "condition" {
    for_each = each.value.host_headers != null ? [1] : []
    content {
      host_header {
        values = each.value.host_headers
      }
    }
  }
}
