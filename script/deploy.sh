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
# Setup PATH
# -----------------------------
export PATH=$PATH:/usr/local/bin:/usr/bin

# -----------------------------
# Navigate to Project Root (FIXED)
# -----------------------------
print_step "Navigating to project directory"
cd "$(dirname "$0")/.."

# Debug
print_step "Checking source files"
pwd
ls -l

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
PUBLIC_IP=$(curl -s ifconfig.me || echo "localhost")
SERVER_NAME=${DOMAIN:-$PUBLIC_IP}

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
sudo chown -R $(whoami):$(whoami) "$PROJECT_DIR"

# Verify copy
print_step "Verifying copied files"
ls -l "$PROJECT_DIR"

cd "$PROJECT_DIR"

# -----------------------------
# Install App Dependencies
# -----------------------------
print_step "Installing app dependencies"

npm install --production

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
# Start App with PM2
# -----------------------------
print_step "Starting application with PM2"

pm2 delete "$APP_NAME" || true

pm2 start "$ENTRY_FILE" --name "$APP_NAME" --update-env

sleep 3
pm2 status

if ! pm2 list | grep -q "$APP_NAME"; then
    echo "❌ PM2 failed to start app"
    pm2 logs --lines 50
    exit 1
fi

pm2 save
sudo env PATH=$PATH:/usr/bin pm2 startup systemd -u $(whoami) --hp $HOME

# -----------------------------
# Configure Nginx
# -----------------------------
print_step "Configuring Nginx"

NGINX_CONF="/etc/nginx/sites-available/$APP_NAME"

sudo tee "$NGINX_CONF" > /dev/null <<EOL
server {
    listen 80;
    server_name $SERVER_NAME;

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
sudo systemctl reload nginx || sudo systemctl restart nginx

# -----------------------------
# Verify Deployment
# -----------------------------
print_step "Verifying application"

sleep 5

if curl -s -o /dev/null -w "%{http_code}" http://localhost:$PORT | grep -q "200"; then
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
