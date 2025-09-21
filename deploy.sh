#!/bin/bash

# Wyrmbot Deployment Script - Restart EC2 for GitHub Updates
# This script restarts the EC2 instance to pull latest code from GitHub

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if debug flag is passed
DEBUG=false
if [ "$1" = "--debug" ]; then
    DEBUG=true
fi

echo -e "${GREEN}Wyrmbot Deployment - Restart Instance${NC}"
echo "======================================"

# Get the instance ID from Terraform output
echo -e "${YELLOW}Getting instance ID from Terraform...${NC}"
cd _infrastructure

# First try to get the output directly
INSTANCE_ID=$(aws-vault exec private -- terraform output -raw instance_id 2>/dev/null)

if [ "$DEBUG" = true ]; then
    echo "DEBUG: First attempt result: '$INSTANCE_ID'"
fi

# If that fails, try with error filtering
if [ -z "$INSTANCE_ID" ] || [ "$INSTANCE_ID" = "null" ]; then
    echo -e "${YELLOW}Trying alternative method to get instance ID...${NC}"
    INSTANCE_ID=$(aws-vault exec private -- terraform output instance_id 2>/dev/null | tr -d '"')
    
    if [ "$DEBUG" = true ]; then
        echo "DEBUG: Alternative method result: '$INSTANCE_ID'"
    fi
fi

# If still empty, refresh and try again
if [ -z "$INSTANCE_ID" ] || [ "$INSTANCE_ID" = "null" ]; then
    echo -e "${YELLOW}Refreshing terraform state...${NC}"
    aws-vault exec private -- terraform refresh > /dev/null 2>&1
    INSTANCE_ID=$(aws-vault exec private -- terraform output -raw instance_id 2>/dev/null)
    
    if [ "$DEBUG" = true ]; then
        echo "DEBUG: After refresh result: '$INSTANCE_ID'"
    fi
    
    # Try alternative method after refresh
    if [ -z "$INSTANCE_ID" ] || [ "$INSTANCE_ID" = "null" ]; then
        INSTANCE_ID=$(aws-vault exec private -- terraform output instance_id 2>/dev/null | tr -d '"')
        
        if [ "$DEBUG" = true ]; then
            echo "DEBUG: Alternative after refresh result: '$INSTANCE_ID'"
        fi
    fi
fi

# If we can see the instance in the refresh output, extract it manually
if [ -z "$INSTANCE_ID" ] || [ "$INSTANCE_ID" = "null" ]; then
    echo -e "${YELLOW}Extracting instance ID from terraform show...${NC}"
    INSTANCE_ID=$(aws-vault exec private -- terraform show -json 2>/dev/null | grep -o '"id":"i-[^"]*"' | head -1 | cut -d'"' -f4)
    
    if [ "$DEBUG" = true ]; then
        echo "DEBUG: JSON extraction result: '$INSTANCE_ID'"
    fi
fi

if [ -z "$INSTANCE_ID" ] || [ "$INSTANCE_ID" = "null" ]; then
    echo -e "${RED}Still could not get instance ID. Please check your Terraform setup.${NC}"
    echo -e "${YELLOW}You can manually restart the instance with:${NC}"
    echo "aws-vault exec private -- aws ec2 reboot-instances --instance-ids i-06d71fd348230baea"
    exit 1
fi

echo -e "${GREEN}Instance ID: $INSTANCE_ID${NC}"

# Check if this is a forced rebuild
if [ "$1" = "--rebuild" ] || [ "$2" = "--rebuild" ]; then
    echo -e "${YELLOW}🔄 Rebuilding instance with latest infrastructure...${NC}"
    echo -e "${YELLOW}Terminating current instance...${NC}"
    aws-vault exec private -- aws ec2 terminate-instances --instance-ids $INSTANCE_ID
    echo -e "${YELLOW}Waiting for instance to terminate...${NC}"
    aws-vault exec private -- aws ec2 wait instance-terminated --instance-ids $INSTANCE_ID
    echo -e "${YELLOW}Creating new instance...${NC}"
    (cd _infrastructure && aws-vault exec private -- terraform apply -auto-approve)
    echo -e "${GREEN}✅ New instance created and configured!${NC}"
else
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
fi