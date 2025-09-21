#!/bin/bash

# Wyrmbot Deployment Script - Spot Instance Resilient
# This script deploys your local source code to the EC2 instance

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Wyrmbot Spot-Resilient Deployment${NC}"
echo "===================================="

# Get the instance IP from Terraform output
echo -e "${YELLOW}Getting instance IP from Terraform...${NC}"
cd _infrastructure
INSTANCE_IP=$(terraform output -raw instance_ip 2>/dev/null)

if [ -z "$INSTANCE_IP" ]; then
    echo -e "${RED}Error: Could not get instance IP from Terraform output${NC}"
    echo "Make sure you've run 'terraform apply' first"
    exit 1
fi

echo -e "${GREEN}Instance IP: $INSTANCE_IP${NC}"

# Check if SSH key exists
KEY_NAME="wyrmbot-key"
if [ ! -f "$KEY_NAME.pem" ]; then
    echo -e "${RED}Error: SSH key file '$KEY_NAME.pem' not found${NC}"
    echo "Please ensure your SSH key is in the current directory"
    exit 1
fi

# Set correct permissions for SSH key
chmod 600 "$KEY_NAME.pem"

cd ..

# Wait for instance to be ready
echo -e "${YELLOW}Waiting for instance to be ready...${NC}"
for i in {1..30}; do
    if ssh -i "$KEY_NAME.pem" -o ConnectTimeout=5 -o StrictHostKeyChecking=no ec2-user@$INSTANCE_IP "echo 'Connected'" 2>/dev/null; then
        echo -e "${GREEN}Instance is ready!${NC}"
        break
    fi
    echo "Attempt $i/30: Instance not ready yet, waiting..."
    sleep 10
done

# Create deployment package (excluding node_modules, .env, etc.)
echo -e "${YELLOW}Creating deployment package...${NC}"
tar --exclude='node_modules' \
    --exclude='.git' \
    --exclude='_infrastructure' \
    --exclude='debug_audio' \
    --exclude='temp' \
    --exclude='.env' \
    -czf /tmp/wyrmbot-src.tar.gz \
    src/ package.json tsconfig.json

# Copy source code to instance
echo -e "${YELLOW}Deploying source code to EC2 instance...${NC}"
scp -i "$KEY_NAME.pem" -o StrictHostKeyChecking=no /tmp/wyrmbot-src.tar.gz ec2-user@$INSTANCE_IP:/tmp/

# Extract and install on the instance
echo -e "${YELLOW}Installing on remote instance...${NC}"
ssh -i "$KEY_NAME.pem" -o StrictHostKeyChecking=no ec2-user@$INSTANCE_IP << 'EOF'
# Stop the service if running
sudo systemctl stop wyrmbot 2>/dev/null || true

# Extract the source code
cd /home/wyrmbot/wyrmbot
sudo -u wyrmbot tar -xzf /tmp/wyrmbot-src.tar.gz

# Install/update dependencies
sudo -u wyrmbot npm install

# Start the service (it's already enabled from user_data)
sudo systemctl start wyrmbot
sleep 3
sudo systemctl status wyrmbot --no-pager

echo "Deployment completed!"
echo "Bot service status:"
sudo systemctl is-active wyrmbot

# Clean up
rm -f /tmp/wyrmbot-src.tar.gz
EOF

# Clean up local temp file
rm -f /tmp/wyrmbot-src.tar.gz

echo -e "${GREEN}✅ Deployment completed successfully!${NC}"
echo ""
echo -e "${GREEN}🔄 Spot Instance Resilience:${NC}"
echo "• Your bot will survive spot instance restarts"
echo "• .env secrets are deployed automatically"
echo "• systemd service starts automatically"
echo "• Run this script again to update code"
echo ""
echo "Useful commands:"
echo -e "${YELLOW}Check logs:${NC} ssh -i $KEY_NAME.pem ec2-user@$INSTANCE_IP 'sudo journalctl -u wyrmbot -f'"
echo -e "${YELLOW}Restart bot:${NC} ssh -i $KEY_NAME.pem ec2-user@$INSTANCE_IP 'sudo systemctl restart wyrmbot'"
echo -e "${YELLOW}SSH to instance:${NC} ssh -i $KEY_NAME.pem ec2-user@$INSTANCE_IP"