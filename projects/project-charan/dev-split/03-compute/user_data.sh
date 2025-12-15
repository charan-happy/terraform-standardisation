#!/bin/bash
# User data for web server

# Update system
yum update -y

# Install Apache
yum install -y httpd

# Create simple page with DB info
cat > /var/www/html/index.html <<EOF
<html>
<head><title>Project Charan - Web Server</title></head>
<body>
<h1>Welcome to Project Charan</h1>
<p>Database Endpoint: ${db_endpoint}</p>
<p>Database Name: ${db_name}</p>
<p>Server Hostname: $(hostname)</p>
<p>Server IP: $(hostname -I)</p>
</body>
</html>
EOF

# Start Apache
systemctl start httpd
systemctl enable httpd

# Configure firewall
systemctl start firewalld
systemctl enable firewalld
firewall-cmd --permanent --add-service=http
firewall-cmd --reload
