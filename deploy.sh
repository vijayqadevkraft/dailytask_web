#!/bin/bash
set -e

# -----------------------------
# Function
# -----------------------------
print_step() {
    echo "----------------------------------------"
    echo "$1"
    echo "----------------------------------------"
}

# -----------------------------
# Load ENV (from server, not repo)
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
# Default Variables
# -----------------------------
APP_NAME=${APP_NAME:-dailytask-app}
PORT=${PORT:-3000}
DOMAIN=${DOMAIN:-localhost}

echo "App Name: $APP_NAME"
echo "Port: $PORT"
echo "Domain: $DOMAIN"

# -----------------------------
# Step 1: Install Dependencies
# -----------------------------
print_step "Installing dependencies"

sudo apt update -y

install_if_missing() {
    if ! dpkg -l | grep -q "$1"; then
        echo "Installing $1..."
        sudo apt install -y $1
    else
        echo "$1 already installed ✔"
    fi
}

install_if_missing curl
install_if_missing git
install_if_missing nginx

# -----------------------------
# Step 2: Node.js
# -----------------------------
print_step "Checking Node.js"

if ! command -v node &> /dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
    sudo apt install -y nodejs
else
    echo "Node.js already installed ✔"
fi

# -----------------------------
# Step 3: PM2
# -----------------------------
print_step "Checking PM2"

if ! command -v pm2 &> /dev/null; then
    sudo npm install -g pm2
else
    echo "PM2 already installed ✔"
fi

# -----------------------------
# Step 4: Use Jenkins Workspace
# -----------------------------
print_step "Using Jenkins workspace"

WORK_DIR=${WORKSPACE:-$(pwd)}
cd $WORK_DIR

echo "Current Directory: $(pwd)"
ls -l

# -----------------------------
# Step 5: Install App
# -----------------------------
print_step "Installing app dependencies"

if [ -f "package.json" ]; then
    npm install
else
    echo "❌ package.json not found"
    exit 1
fi

# -----------------------------
# Step 6: Detect Entry File
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
# Step 7: Start App
# -----------------------------
print_step "Running app with PM2"

export PORT=$PORT

if pm2 list | grep -q "$APP_NAME"; then
    pm2 restart $APP_NAME --update-env
else
    pm2 start $ENTRY_FILE --name $APP_NAME
fi

pm2 save

# -----------------------------
# Step 8: Configure Nginx
# -----------------------------
print_step "Configuring Nginx"

NGINX_CONF="/etc/nginx/sites-available/$APP_NAME"

sudo tee $NGINX_CONF > /dev/null <<EOL
server {
    listen 80;
    server_name $DOMAIN;

    location / {
        proxy_pass http://localhost:$PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
    }
}
EOL

sudo ln -sf $NGINX_CONF /etc/nginx/sites-enabled/

sudo nginx -t
sudo systemctl restart nginx

# -----------------------------
# Done
# -----------------------------
print_step "Deployment Completed 🎉"

echo "🌐 App running at: http://$DOMAIN"
pm2 status
