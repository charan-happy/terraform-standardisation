# Examples of using moved blocks for safe refactoring
# Add these to your main.tf when renaming or reorganizing resources

# Example 1: Renaming a module
# Old: module "server"
# New: module "web_server"
moved {
  from = module.server
  to   = module.web_server
}

# Example 2: Renaming a resource within a module
moved {
  from = module.ec2.aws_instance.main
  to   = module.ec2.aws_instance.web
}

# Example 3: Moving from count to for_each
# Old: aws_instance.web[0], aws_instance.web[1]
# New: aws_instance.web["primary"], aws_instance.web["secondary"]
moved {
  from = aws_instance.web[0]
  to   = aws_instance.web["primary"]
}

moved {
  from = aws_instance.web[1]
  to   = aws_instance.web["secondary"]
}

# Example 4: Moving resource to a module
# Old: resource "aws_security_group" "web" { ... }
# New: module "web_sg" { source = "../../modules/security-groups" }
moved {
  from = aws_security_group.web
  to   = module.web_sg.aws_security_group.main
}

# Example 5: Extracting module to separate module
# Old: module "app" has both web and api servers
# New: Separate modules for each
moved {
  from = module.app.aws_instance.web
  to   = module.web_server.aws_instance.main
}

moved {
  from = module.app.aws_instance.api
  to   = module.api_server.aws_instance.main
}

# Example 6: Renaming multiple instances with for_each
# Convert from list to map
moved {
  from = aws_subnet.private[0]
  to   = aws_subnet.private["us-east-1a"]
}

moved {
  from = aws_subnet.private[1]
  to   = aws_subnet.private["us-east-1b"]
}

# Example 7: Consolidating resources
# Multiple separate resources into a single module
moved {
  from = aws_security_group.app
  to   = module.app_infrastructure.aws_security_group.main
}

moved {
  from = aws_instance.app
  to   = module.app_infrastructure.aws_instance.main
}

moved {
  from = aws_lb_target_group.app
  to   = module.app_infrastructure.aws_lb_target_group.main
}

# HOW TO USE:
# 1. Make your code changes (rename modules, resources, etc.)
# 2. Add appropriate moved blocks
# 3. Run: terraform plan
#    - Should show moved resources (not destroy/create)
# 4. Run: terraform apply
#    - Resources are updated in state, NOT recreated
# 5. After successful apply, you can remove moved blocks
#    (or keep them for documentation)

# NOTES:
# - Moved blocks are safe - they only update state
# - No infrastructure changes happen
# - Can be removed after state is updated
# - Terraform 1.1+ required
