
resource "aws_iam_role" "main" {
  name_prefix        = "${var.role_name}-"
  assume_role_policy = var.assume_role_policy

  tags = merge(
    var.tags,
    {
      Name = var.role_name
    }
  )
}

resource "aws_iam_role_policy" "inline" {
  for_each = var.inline_policies

  name   = each.key
  role   = aws_iam_role.main.id
  policy = each.value
}

resource "aws_iam_role_policy_attachment" "managed" {
  for_each = toset(var.managed_policy_arns)

  role       = aws_iam_role.main.name
  policy_arn = each.value
}

resource "aws_iam_instance_profile" "main" {
  count       = var.create_instance_profile ? 1 : 0
  name_prefix = "${var.role_name}-"
  role        = aws_iam_role.main.name
}


