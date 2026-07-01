#!/bin/bash
set -e

# Install Nginx
if ! command -v nginx &>/dev/null; then
    apt-get update -y
    apt-get install -y nginx
fi

# Configure Nginx as load balancer
cat > /etc/nginx/nginx.conf << 'EOF'
events {
    worker_connections 1024;
}

http {
    upstream webservers {
        server 192.168.56.11:8080;
        server 192.168.56.12:8080;
    }

    server {
        listen 80;

        location / {
            proxy_pass http://webservers;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        }
    }
}
EOF

# Enable and restart Nginx
systemctl enable nginx
systemctl restart nginx

# Allow HTTP traffic
ufw allow 80/tcp