
resource "aws_security_group" "main" {
  name_prefix = "${var.name}-"
  description = var.description
  vpc_id      = var.vpc_id

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(
    var.tags,
    {
      Name = var.name
    }
  )
}

resource "aws_vpc_security_group_ingress_rule" "main" {
  for_each = { for idx, rule in var.ingress_rules : idx => rule }

  security_group_id = aws_security_group.main.id

  from_port       = each.value.from_port
  to_port         = each.value.to_port
  ip_protocol     = each.value.protocol
  cidr_ipv4       = try(each.value.cidr_ipv4, null)
  referenced_security_group_id = try(each.value.security_group_id, null)
  description     = try(each.value.description, null)

  tags = {
    Name = "${var.name}-ingress-${each.key}"
  }
}

# resource "aws_vpc_security_group_egress_rule" "main" {
#   for_each = { for idx, rule in var.egress_rules : idx => rule }

#   security_group_id = aws_security_group.main.id

#   from_port       = each.value.from_port
#   to_port         = each.value.to_port
#   ip_protocol     = each.value.protocol
#   cidr_ipv4       = try(each.value.cidr_ipv4, null)
#   referenced_security_group_id = try(each.value.security_group_id, null)
#   description     = try(each.value.description, null)

#   tags = {
#     Name = "${var.name}-egress-${each.key}"
#   }
# }

resource "aws_vpc_security_group_egress_rule" "main" {
  for_each = { for idx, rule in var.egress_rules : idx => rule }

  security_group_id = aws_security_group.main.id

  ip_protocol = each.value.protocol

  from_port = each.value.protocol == "-1" ? null : each.value.from_port
  to_port   = each.value.protocol == "-1" ? null : each.value.to_port

  cidr_ipv4       = try(each.value.cidr_ipv4, null)
  referenced_security_group_id = try(each.value.security_group_id, null)
  description     = try(each.value.description, null)

  tags = {
    Name = "${var.name}-egress-${each.key}"
  }
}