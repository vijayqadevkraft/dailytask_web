#!/bin/bash
set -e

print_step() {
    echo "----------------------------------------"
    echo "$1"
    echo "----------------------------------------"
}

# -----------------------------
# Navigate to web-application directory
# -----------------------------
print_step "Navigating to web-application directory"
# This script is located in /script, so we move to /web-application relative to its location
cd "$(dirname "$0")/../web-application"

# -----------------------------
# Load ENV
# -----------------------------
print_step "Loading environment variables"

ENV_FILE="/opt/.env"

if [ -f "$ENV_FILE" ]; then
    set -a
    source "$ENV_FILE"
    set +a
else
    echo "❌ Env file not found"
    # Note: In some environments, we might want to continue with defaults
    # For now, we follow the original script's exit 1.
    exit 1
fi

APP_NAME=${APP_NAME:-"dailytask-app"}
# Assuming the production project dir remains the same or includes the web-application path
PROJECT_DIR=${PROJECT_DIR:-"/var/www/dailytask_web"}
PORT=${PORT:-3000}
DOMAIN=${DOMAIN:-""}
PUBLIC_IP=$(curl -s http://checkip.amazonaws.com)

echo "App: $APP_NAME | Port: $PORT"

# -----------------------------
# Install Dependencies
# -----------------------------
print_step "Installing dependencies"

sudo apt update -y
sudo apt install -y curl git nginx

# -----------------------------
# Node.js + PM2
# -----------------------------
print_step "Checking Node.js & PM2"

if ! command -v node &> /dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
    sudo apt install -y nodejs
fi

if ! command -v pm2 &> /dev/null; then
    sudo npm install -g pm2
fi

# -----------------------------
# Copy code to production dir
# -----------------------------
print_step "Copying code to /var/www"

sudo mkdir -p $PROJECT_DIR
# Note: $WORKSPACE should be set by Jenkins.
# We copy the entire workspace or just the web-application folder?
# The original script copied $WORKSPACE/. Since we moved everything to web-application/,
# we should probably copy the contents of the current directory (web-application/)
sudo rsync -av --delete ./ $PROJECT_DIR/

# 🔥 FIX: give permission to Jenkins (important)
sudo chown -R jenkins:jenkins $PROJECT_DIR

cd $PROJECT_DIR

# -----------------------------
# Install app dependencies
# -----------------------------
print_step "Installing app dependencies"

# 🔥 FIX: run npm as jenkins
sudo -u jenkins npm install

# -----------------------------
# Detect entry file
# -----------------------------
print_step "Detecting entry file"

if [ -f "server.js" ]; then
    ENTRY_FILE="server.js"
elif [ -f "app.js" ]; then
    ENTRY_FILE="app.js"
else
    ENTRY_FILE="index.js"
fi

echo "Using: $ENTRY_FILE"

# -----------------------------
# Start app with PM2
# -----------------------------
print_step "Starting app with PM2 (ubuntu user)"

sudo -u ubuntu pm2 delete $APP_NAME || true
sudo -u ubuntu pm2 start $PROJECT_DIR/$ENTRY_FILE --name $APP_NAME
sudo -u ubuntu pm2 save

# -----------------------------
# Configure Nginx
# -----------------------------
print_step "Configuring Nginx"

NGINX_CONF="/etc/nginx/sites-available/$APP_NAME"

sudo tee $NGINX_CONF > /dev/null <<EOL
server {
    listen 80;
    server_name $DOMAIN $PUBLIC_IP;

    location / {
        proxy_pass http://localhost:$PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOL

sudo ln -sf $NGINX_CONF /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

sudo nginx -t
sudo systemctl restart nginx

# -----------------------------
# Verify
# -----------------------------
print_step "Verifying deployment"

sleep 3

if curl -s http://localhost:$PORT > /dev/null; then
    echo "✅ App is running"
else
    echo "❌ App failed"
    exit 1
fi

# -----------------------------
# Done
# -----------------------------
print_step "Deployment Completed 🎉"

echo "http://$PUBLIC_IP"
echo "http://$DOMAIN"

sudo -u ubuntu pm2 status
