#!/bin/bash
set -e

# -----------------------------
# Utility Function
# -----------------------------
print_step() {
    echo ""
    echo "----------------------------------------"
    echo "$1"
    echo "----------------------------------------"
}

# -----------------------------
# Setup PATH (fix for PM2/npm)
# -----------------------------
export PATH=$PATH:/usr/local/bin:/usr/bin

# -----------------------------
# Navigate to web-application
# -----------------------------
print_step "Navigating to web-application directory"
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
    echo "❌ Env file not found at $ENV_FILE"
    exit 1
fi

# Defaults
APP_NAME=${APP_NAME:-"dailytask-app"}
PROJECT_DIR=${PROJECT_DIR:-"/var/www/dailytask_web"}
PORT=${PORT:-3000}
DOMAIN=${DOMAIN:-""}
PUBLIC_IP=$(curl -s http://checkip.amazonaws.com)

echo "App: $APP_NAME | Port: $PORT"
echo "Project Dir: $PROJECT_DIR"

# -----------------------------
# Install Dependencies
# -----------------------------
print_step "Installing system dependencies"

sudo apt update -y
sudo apt install -y curl git nginx rsync

# -----------------------------
# Install Node.js & PM2
# -----------------------------
print_step "Checking Node.js & PM2"

if ! node -v &> /dev/null; then
    echo "Installing Node.js..."
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
    sudo apt install -y nodejs
fi

if ! pm2 -v &> /dev/null; then
    echo "Installing PM2..."
    sudo npm install -g pm2
fi

# -----------------------------
# Copy Code
# -----------------------------
print_step "Deploying application to $PROJECT_DIR"

sudo mkdir -p "$PROJECT_DIR"
sudo rsync -av --delete ./ "$PROJECT_DIR/"
sudo chown -R jenkins:jenkins "$PROJECT_DIR"

cd "$PROJECT_DIR"

# Debug
echo "Files in project:"
ls -l

# -----------------------------
# Install App Dependencies
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
    echo "❌ No entry file found!"
    exit 1
fi

echo "Using entry file: $ENTRY_FILE"

# -----------------------------
# Start App with PM2 (Jenkins user)
# -----------------------------
print_step "Starting application with PM2"

pm2 delete "$APP_NAME" || true

pm2 start "$PROJECT_DIR/$ENTRY_FILE" --name "$APP_NAME" --update-env || {
    echo "❌ PM2 failed to start app"
    exit 1
}

pm2 save

# Optional: auto-start on reboot
pm2 startup || true

# -----------------------------
# Configure Nginx
# -----------------------------
print_step "Configuring Nginx"

NGINX_CONF="/etc/nginx/sites-available/$APP_NAME"

sudo tee "$NGINX_CONF" > /dev/null <<EOL
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

sudo ln -sf "$NGINX_CONF" /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

sudo nginx -t
sudo systemctl restart nginx

# -----------------------------
# Verify Deployment
# -----------------------------
print_step "Verifying application"

sleep 5

if curl -s "http://localhost:$PORT" > /dev/null; then
    echo "✅ Application is running successfully"
else
    echo "❌ Application failed to start"
    pm2 logs "$APP_NAME" --lines 50
    exit 1
fi

# -----------------------------
# Final Output
# -----------------------------
print_step "Deployment Completed 🎉"

echo "🌐 Access URLs:"
echo "http://$PUBLIC_IP"
[ -n "$DOMAIN" ] && echo "http://$DOMAIN"

echo ""
echo "📊 PM2 Status:"
pm2 status
