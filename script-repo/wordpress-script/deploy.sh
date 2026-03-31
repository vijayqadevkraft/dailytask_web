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
# The script is in script-repo/wordpress-script/
# The app is in webapplication-repo/backend/ (assuming we use this as the WordPress content placeholder)
cd "$(dirname "$0")/../../webapplication-repo/backend"

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
    echo "❌ Env file not found at $ENV_FILE. Using defaults."
fi

# Defaults
APP_NAME=${APP_NAME:-"wordpress-app"}
PROJECT_DIR=${PROJECT_DIR:-"/var/www/wordpress"}
PORT=${PORT:-80}
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
sudo apt install -y curl git nginx rsync php-fpm php-mysql

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
# Configure Nginx for WordPress (PHP)
# -----------------------------
print_step "Configuring Nginx"

NGINX_CONF="/etc/nginx/sites-available/$APP_NAME"

sudo tee "$NGINX_CONF" > /dev/null <<EOL
server {
    listen 80;
    server_name $SERVER_NAME;

    root $PROJECT_DIR;
    index index.php index.html;

    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php-fpm.sock; # Adjust PHP-FPM version if needed
    }

    location ~* \.(js|css|png|jpg|jpeg|gif|ico)$ {
        expires max;
        log_not_found off;
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
    echo "❌ Application failed to respond. WordPress might need DB config."
    # For a placeholder deployment, we might not have DB ready.
fi

# -----------------------------
# Final Output
# -----------------------------
print_step "Deployment Completed 🎉"

echo "🌐 Access URLs:"
echo "http://$PUBLIC_IP"
[ -n "$DOMAIN" ] && echo "http://$DOMAIN"
