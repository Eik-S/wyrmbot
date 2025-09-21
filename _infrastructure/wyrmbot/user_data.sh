#!/bin/bash

# Update system and install Node.js + Git
yum update -y
curl -fsSL https://rpm.nodesource.com/setup_lts.x | bash -
yum install -y nodejs git

# Create dedicated user for security
useradd -m -s /bin/bash wyrmbot

# Clone the latest source code from GitHub
cd /home/wyrmbot
sudo -u wyrmbot git clone https://github.com/Eik-S/wyrmbot.git wyrmbot

# Create .env file with secrets
cat > /home/wyrmbot/wyrmbot/.env << 'EOF'
${env_content}
EOF

# Install dependencies
cd /home/wyrmbot/wyrmbot
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

# Create update script for easy maintenance
cat > /home/wyrmbot/update-wyrmbot.sh << 'EOF'
#!/bin/bash
echo "Updating Wyrmbot to latest version..."
cd /home/wyrmbot/wyrmbot
git pull origin main
npm install
sudo systemctl restart wyrmbot
echo "Wyrmbot updated and restarted!"
EOF
chmod +x /home/wyrmbot/update-wyrmbot.sh
chown wyrmbot:wyrmbot /home/wyrmbot/update-wyrmbot.sh

# Set proper ownership and enable service
chown -R wyrmbot:wyrmbot /home/wyrmbot
systemctl daemon-reload
systemctl enable wyrmbot

# Start the service immediately
systemctl start wyrmbot