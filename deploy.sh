#!/bin/bash

# Wyrmbot Deployment Script - Restart EC2 for GitHub Updates
# This script restarts the EC2 instance to pull latest code from GitHub

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Wyrmbot Deployment - Restart Instance${NC}"
echo "======================================"

# Get the instance ID from Terraform output
echo -e "${YELLOW}Getting instance ID from Terraform...${NC}"
cd _infrastructure
INSTANCE_ID=$(terraform output -raw instance_id 2>/dev/null)

if [ -z "$INSTANCE_ID" ]; then
    echo -e "${RED}Error: Could not get instance ID from Terraform output${NC}"
    echo "Make sure you've run 'terraform apply' first"
    exit 1
fi

echo -e "${GREEN}Instance ID: $INSTANCE_ID${NC}"

# Restart the instance
echo -e "${YELLOW}Restarting EC2 instance...${NC}"
aws-vault exec private -- aws ec2 reboot-instances --instance-ids $INSTANCE_ID

echo -e "${GREEN}✅ Instance restart initiated!${NC}"
echo ""
echo -e "${GREEN}🔄 Automatic Deployment Process:${NC}"
echo "• Instance will reboot and automatically pull latest code from GitHub"
echo "• Bot will restart with the latest changes"
echo "• Process takes about 2-3 minutes to complete"
echo ""
echo -e "${YELLOW}Monitor instance status:${NC} aws-vault exec private -- aws ec2 describe-instances --instance-ids $INSTANCE_ID --query 'Reservations[0].Instances[0].State.Name'"