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
cd "$(dirname "$0")/../web-application"

# -----------------------------
# Install Dependencies
# -----------------------------
print_step "Installing dependencies"
npm install

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
# Start app (Background)
# -----------------------------
print_step "Starting app"
# For a CI environment, we'll start the server in the background and verify it.
# In a real production environment, use PM2 as shown in the original script.
PORT=3000
kill $(lsof -t -i :$PORT) 2>/dev/null || true
node $ENTRY_FILE > server.log 2>&1 &
SERVER_PID=$!

# -----------------------------
# Verify
# -----------------------------
print_step "Verifying deployment"
sleep 5
if curl -s http://localhost:$PORT > /dev/null; then
    echo "✅ App is running"
else
    echo "❌ App failed"
    cat server.log
    exit 1
fi

print_step "Deployment Completed 🎉"
