#!/bin/bash

# Update system and install Node.js + Git
yum update -y
curl -fsSL https://rpm.nodesource.com/setup_lts.x | bash -
yum install -y nodejs git

# Create dedicated user for security
useradd -m -s /bin/bash wyrmbot

# Create app directory and .env file
mkdir -p /home/wyrmbot/wyrmbot
cat > /home/wyrmbot/wyrmbot/.env << 'EOF'
${env_content}
EOF

# Create package.json and source files
cd /home/wyrmbot/wyrmbot
cat > package.json << 'EOF'
{
  "name": "wyrmbot",
  "version": "1.0.0",
  "scripts": {
    "start": "ts-node src/index.ts"
  },
  "dependencies": {
    "discord.js": "^14.22.1",
    "@discordjs/voice": "^0.19.0",
    "openai": "^4.30.0",
    "prism-media": "^1.3.5",
    "typescript": "^5.0.0",
    "ts-node": "^10.9.0"
  }
}
EOF

# Download and extract source code from deployment package
# This will be populated by terraform apply / deploy script
mkdir -p src/voice src/utils

# Install dependencies
sudo -u wyrmbot npm install

# Create systemd service
cat > /etc/systemd/system/wyrmbot.service << 'EOF'
[Unit]
Description=Wyrmbot Discord Bot
After=network.target

[Service]
Type=simple
User=wyrmbot
WorkingDirectory=/home/wyrmbot/wyrmbot
Environment=NODE_ENV=production
ExecStart=/usr/bin/npm start
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Set proper ownership and enable service
chown -R wyrmbot:wyrmbot /home/wyrmbot
systemctl daemon-reload
systemctl enable wyrmbot

# Service will start when code is deployed