#!/bin/bash
cd "$(dirname "$0")"
set -euo pipefail

# -----------------------------
# Load config
# -----------------------------
CONFIG_FILE="./novnc.conf"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Config file $CONFIG_FILE not found!"
    exit 1
fi
source "$CONFIG_FILE"

SSH_KEY="$(realpath "$SSH_KEY")"

# Default if not defined in config
NOVNC_DIR="${NOVNC_DIR:-$HOME/noVNC}"

# -----------------------------
# Ensure noVNC repo exists
# -----------------------------
if [ ! -d "$NOVNC_DIR/.git" ]; then
    echo "noVNC not found at $NOVNC_DIR — cloning..."
    git clone https://github.com/novnc/noVNC.git "$NOVNC_DIR"
    git clone https://github.com/novnc/websockify.git "$NOVNC_DIR"/utils/websockify

else
    echo "noVNC repository found at $NOVNC_DIR"
fi

# -----------------------------
# Update noVNC repository
# -----------------------------
echo "Updating noVNC repository..."
cd "$NOVNC_DIR"
git pull

# -----------------------------
# Start noVNC proxy
# -----------------------------
echo "Starting noVNC proxy on port $WEB_PORT..."
nohup ./utils/novnc_proxy --vnc "localhost:$VNC_PORT" --listen "$WEB_PORT" > "$HOME/novnc.log" 2>&1 &
NOVNC_PID=$!
echo "noVNC proxy running in background (PID $NOVNC_PID)"
 
# -----------------------------
# Start SSH tunnel
# -----------------------------
echo "Starting SSH tunnel to $SSH_USER@$SSH_HOST..."
ssh -N -L "$VNC_PORT:localhost:$VNC_PORT" -i "$SSH_KEY" "$SSH_USER@$SSH_HOST" &
SSH_PID=$!
echo "SSH tunnel running (PID $SSH_PID)"

# -----------------------------
# Cleanup on exit
# -----------------------------
trap "echo 'Stopping processes...'; kill $NOVNC_PID $SSH_PID" EXIT

wait

