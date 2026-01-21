#!/bin/bash

DOMAIN="n8n.anovoxlabs.com"

echo "============================================"
echo "  n8n Installation with Cloudflare Tunnel"
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

# Get Cloudflare Tunnel token
echo ""
echo "============================================"
echo "  Cloudflare Tunnel Setup"
echo "============================================"
echo ""
echo "To get your tunnel token:"
echo "1. Go to Cloudflare Dashboard > Zero Trust > Networks > Tunnels"
echo "2. Create a tunnel or select existing one"
echo "3. Click 'Configure' > Copy the token from the install command"
echo "   (It's the long string after 'cloudflared service install')"
echo ""
read -p "Enter your Cloudflare Tunnel Token: " TUNNEL_TOKEN

if [ -z "$TUNNEL_TOKEN" ]; then
    echo "❌ No token provided. Exiting."
    exit 1
fi

# Create compose.yaml with cloudflared
echo "📝 Creating Docker Compose configuration..."
cat > compose.yaml << 'EOF'
services:
  svr_n8n:
    image: n8nio/n8n
    container_name: n8n_container
    restart: unless-stopped
    environment:
      - N8N_HOST=n8n.anovoxlabs.com
      - N8N_PROTOCOL=https
      - N8N_SECURE_COOKIE=true
      - N8N_COMMUNITY_PACKAGES_ALLOW_TOOL_USAGE=true
      - N8N_EDITOR_BASE_URL=https://n8n.anovoxlabs.com
      - WEBHOOK_URL=https://n8n.anovoxlabs.com
      - N8N_DEFAULT_BINARY_DATA_MODE=filesystem
    ports:
      - "5678:5678"
    volumes:
      - /root/n8n_data:/home/node/.n8n

  cloudflared:
    image: cloudflare/cloudflared:latest
    container_name: cloudflared
    restart: unless-stopped
    command: tunnel run
    environment:
      - TUNNEL_TOKEN=${TUNNEL_TOKEN}
    depends_on:
      - svr_n8n
EOF

# Create .env file with token
echo "TUNNEL_TOKEN=$TUNNEL_TOKEN" > .env

# Start services
echo "🚀 Starting all services..."
sudo docker compose up -d

echo ""
echo "============================================"
echo "  ✅ Installation Complete!"
echo "============================================"
echo ""
echo "  IMPORTANT: Configure your tunnel in Cloudflare Dashboard:"
echo ""
echo "  1. Go to: Cloudflare Dashboard > Zero Trust > Networks > Tunnels"
echo "  2. Click on your tunnel > 'Public Hostname' tab"
echo "  3. Add a public hostname:"
echo "     - Subdomain: n8n"
echo "     - Domain: anovoxlabs.com"
echo "     - Service Type: HTTP"
echo "     - URL: svr_n8n:5678"
echo ""
echo "  Once configured, access n8n at:"
echo "  https://$DOMAIN"
echo ""
echo "============================================"
