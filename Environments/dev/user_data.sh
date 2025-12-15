
#!/bin/bash
set -e

# Update system
yum update -y
yum install -y \
  postgresql15-client \
  git \
  curl \
  cloudwatch \
  amazon-cloudwatch-agent

# Create application directory
mkdir -p /opt/app
cd /opt/app

# Log setup completion
echo "Instance setup completed at $(date)" >> /var/log/user-data.log

# CloudWatch Logs configuration
cat > /opt/aws/amazon-cloudwatch-agent/etc/config.json <<'EOF'
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/messages",
            "log_group_name": "/aws/ec2/project-charan-dev",
            "log_stream_name": "{instance_id}"
          },
          {
            "file_path": "/opt/app/application.log",
            "log_group_name": "/aws/ec2/project-charan-dev/app",
            "log_stream_name": "{instance_id}"
          }
        ]
      }
    }
  }
}
EOF

# Start CloudWatch agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -s \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/config.json





