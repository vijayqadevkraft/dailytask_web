#!/bin/bash
set -e

print_step() {
    echo "----------------------------------------"
    echo "$1"
    echo "----------------------------------------"
}

# -----------------------------
# Load ENV (FIXED)
# -----------------------------
print_step "Loading environment variables"

ENV_FILE="/opt/.env"

if [ -f "$ENV_FILE" ]; then
    set -a
    source "$ENV_FILE"
    set +a
else
    echo "❌ Env file not found at $ENV_FILE"
    exit 1
fi

# -----------------------------
# Variables
# -----------------------------
APP_NAME=${APP_NAME:-"dailytask-app"}
PROJECT_DIR=${PROJECT_DIR:-"/var/www/dailytask_web"}
REPO_URL=${REPO_URL:-""}
PORT=${PORT:-3000}
DOMAIN=${DOMAIN:-""}
PUBLIC_IP=$(curl -s http://checkip.amazonaws.com)

echo "App: $APP_NAME | Port: $PORT | Domain: $DOMAIN"

# -----------------------------
# Install Dependencies
# -----------------------------
print_step "Installing dependencies"

sudo apt update -y
sudo apt install -y curl git nginx certbot python3-certbot-nginx

# -----------------------------
# Node.js
# -----------------------------
print_step "Checking Node.js"

if ! command -v node &> /dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
    sudo apt install -y nodejs
fi

# -----------------------------
# PM2
# -----------------------------
print_step "Checking PM2"

if ! command -v pm2 &> /dev/null; then
    sudo npm install -g pm2
fi

# -----------------------------
# Use Jenkins Workspace (FIXED)
# -----------------------------
print_step "Using workspace"

WORK_DIR=${WORKSPACE:-$(pwd)}
cd $WORK_DIR

echo "Current Directory: $(pwd)"
ls -l

# -----------------------------
# Install Dependencies
# -----------------------------
print_step "Installing app dependencies"

npm install

# -----------------------------
# Detect Entry File
# -----------------------------
print_step "Detecting entry file"

if [ -f "server.js" ]; then
    ENTRY_FILE="server.js"
elif [ -f "app.js" ]; then
    ENTRY_FILE="app.js"
elif [ -f "index.js" ]; then
    ENTRY_FILE="index.js"
else
    echo "❌ No entry file found"
    exit 1
fi

echo "Using: $ENTRY_FILE"

# -----------------------------
# Start App
# -----------------------------
print_step "Starting app"

export PORT=$PORT

if pm2 list | grep -q "$APP_NAME"; then
    pm2 restart $APP_NAME --update-env
else
    pm2 start $ENTRY_FILE --name $APP_NAME
fi

pm2 save

# -----------------------------
# Configure Nginx (FIXED)
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

# Enable config
sudo ln -sf $NGINX_CONF /etc/nginx/sites-enabled/

# 🔥 REMOVE DEFAULT CONFIG (CRITICAL FIX)
sudo rm -f /etc/nginx/sites-enabled/default

# Restart nginx
sudo nginx -t
sudo systemctl restart nginx

# -----------------------------
# Verify
# -----------------------------
print_step "Verifying deployment"

sleep 3

if curl -s http://localhost > /dev/null; then
    echo "✅ App is reachable via Nginx"
else
    echo "❌ Nginx routing failed"
    exit 1
fi

# -----------------------------
# SSL (Optional)
# -----------------------------
if [ -n "$DOMAIN" ]; then
    print_step "Setting up SSL"

    sudo certbot --nginx -d $DOMAIN --non-interactive --agree-tos -m admin@$DOMAIN || true
fi

# -----------------------------
# Done
# -----------------------------
print_step "Deployment Completed 🎉"

echo "🌐 Access:"
echo "http://$PUBLIC_IP"
echo "http://$DOMAIN"

pm2 status
