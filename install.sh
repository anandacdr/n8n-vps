#!/bin/bash

DOMAIN="n8n.anovoxlabs.com"
EMAIL="info.anandachaudhary@gmail.com"

echo "============================================"
echo "  n8n Installation for $DOMAIN"
echo "============================================"

# Update system
echo "📦 Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Install Docker
echo "🐳 Installing Docker..."
sudo apt install -y apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
echo "✅ Docker installed!"

# Create n8n data directory
echo "📂 Creating n8n data directory..."
mkdir -p /root/n8n_data
sudo chown -R 1000:1000 /root/n8n_data
sudo chmod -R 755 /root/n8n_data
echo "✅ Data directory ready!"

# Create certbot directories
echo "🔐 Setting up SSL directories..."
mkdir -p certbot/conf certbot/www

# Create temporary nginx config for SSL certificate generation
echo "📝 Creating temporary nginx config for SSL..."
cat > nginx.conf << 'NGINXCONF'
events {
    worker_connections 1024;
}

http {
    server {
        listen 80;
        server_name n8n.anovoxlabs.com;

        location /.well-known/acme-challenge/ {
            root /var/www/certbot;
        }

        location / {
            return 200 'Setting up SSL...';
            add_header Content-Type text/plain;
        }
    }
}
NGINXCONF

# Start nginx temporarily
echo "🚀 Starting nginx for SSL verification..."
sudo docker compose up -d nginx

# Wait for nginx to start
sleep 5

# Get SSL certificate
echo "🔐 Obtaining SSL certificate..."
sudo docker compose run --rm certbot certonly --webroot --webroot-path=/var/www/certbot \
    --email $EMAIL --agree-tos --no-eff-email \
    -d $DOMAIN

# Restore full nginx config with SSL
echo "📝 Updating nginx config with SSL..."
cat > nginx.conf << 'NGINXCONF'
events {
    worker_connections 1024;
}

http {
    server {
        listen 80;
        server_name n8n.anovoxlabs.com;

        location /.well-known/acme-challenge/ {
            root /var/www/certbot;
        }

        location / {
            return 301 https://$host$request_uri;
        }
    }

    server {
        listen 443 ssl;
        server_name n8n.anovoxlabs.com;

        ssl_certificate /etc/letsencrypt/live/n8n.anovoxlabs.com/fullchain.pem;
        ssl_certificate_key /etc/letsencrypt/live/n8n.anovoxlabs.com/privkey.pem;

        location / {
            proxy_pass http://svr_n8n:5678;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_buffering off;
            proxy_cache off;
            chunked_transfer_encoding off;
        }
    }
}
NGINXCONF

# Start all services
echo "🚀 Starting all services..."
sudo docker compose down
sudo docker compose up -d

echo ""
echo "============================================"
echo "  ✅ Installation Complete!"
echo "============================================"
echo ""
echo "  Your n8n instance is now available at:"
echo "  https://$DOMAIN"
echo ""
echo "  First time? Create your admin account at:"
echo "  https://$DOMAIN/setup"
echo ""
echo "============================================"
