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
# Navigate to Project Root
# -----------------------------
print_step "Navigating to project directory"
# The script is in script-repo/simple-index-html-script/
# The app is in webapplication-repo/simple-index-html/
# Assuming they are cloned side-by-side during pipeline execution
cd "$(dirname "$0")/../../webapplication-repo/simple-index-html"

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
    # For a simple index.html deployment, we might not strictly need env files,
    # but let's keep it for consistency or provide defaults.
fi

# Defaults
APP_NAME=${APP_NAME:-"simple-html-app"}
PROJECT_DIR=${PROJECT_DIR:-"/var/www/simple-html"}
PORT=${PORT:-80} # For simple HTML, we just serve via Nginx
DOMAIN=${DOMAIN:-""}
PUBLIC_IP=$(curl -s ifconfig.me || echo "localhost")
SERVER_NAME=${DOMAIN:-$PUBLIC_IP}

echo "App: $APP_NAME"
echo "Project Dir: $PROJECT_DIR"

# -----------------------------
# Install Dependencies
# -----------------------------
print_step "Installing system dependencies"

sudo apt update -y
sudo apt install -y curl git nginx rsync

# -----------------------------
# Copy Code
# -----------------------------
print_step "Deploying application to $PROJECT_DIR"

sudo mkdir -p "$PROJECT_DIR"
sudo rsync -av --delete ./ "$PROJECT_DIR/"
sudo chown -R www-data:www-data "$PROJECT_DIR"

# Verify copy
print_step "Verifying copied files"
ls -l "$PROJECT_DIR"

# -----------------------------
# Configure Nginx
# -----------------------------
print_step "Configuring Nginx"

NGINX_CONF="/etc/nginx/sites-available/$APP_NAME"

sudo tee "$NGINX_CONF" > /dev/null <<EOL
server {
    listen 80;
    server_name $SERVER_NAME;

    root $PROJECT_DIR;
    index index.html;

    location / {
        try_files \$uri \$uri/ =404;
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

if curl -s -o /dev/null -w "%{http_code}" http://localhost | grep -q "200"; then
    echo "✅ Application is running successfully"
else
    echo "❌ Application failed to respond"
    exit 1
fi

# -----------------------------
# Final Output
# -----------------------------
print_step "Deployment Completed 🎉"

echo "🌐 Access URLs:"
echo "http://$PUBLIC_IP"
[ -n "$DOMAIN" ] && echo "http://$DOMAIN"
