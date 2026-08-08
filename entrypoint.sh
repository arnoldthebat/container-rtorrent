#!/bin/sh
set -eu

RTORRENT_HOME=${RTORRENT_HOME:-/data/rtorrent}
CONFIG_DIR=${CONFIG_DIR:-$RTORRENT_HOME/config}
RTORRENT_RC=${RTORRENT_RC:-$CONFIG_DIR/.rtorrent.rc}
# PUID=${PUID:-1000}
# PGID=${PGID:-1000}

# Path definitions
SESSION_DIR="/data/rtorrent/.session"
PID_FILE="${SESSION_DIR}/rtorrent.pid"
LOCK_FILE="${SESSION_DIR}/rtorrent.lock"

# 1. Pre-flight cleanup
if [ -f "$PID_FILE" ]; then
    echo "[init] Cleaning up stale PID file from previous run..."
    rm -f "$PID_FILE"
fi

# Start Nginx in background
echo "[init] Starting Nginx..."
nginx

# 3. Define Graceful Trap Handler
cleanup() {
    echo "[shutdown] Received termination signal. Stopping rtorrent cleanly..."
    
    # Send SIGINT (Ctrl+C equivalent) to rtorrent inside tmux
    if tmux has-session -t rtorrent-session 2>/dev/null; then
        tmux send-keys -t rtorrent-session:0.0 C-c
        
        # Wait up to 10 seconds for rtorrent process to exit
        COUNT=0
        while tmux has-session -t rtorrent-session 2>/dev/null && [ $COUNT -lt 10 ]; do
            sleep 1
            COUNT=$((COUNT + 1))
        done
        
        # Force kill tmux server if still alive after timeout
        tmux kill-server 2>/dev/null || true
    fi

    # Clean up PID and lock file if rtorrent left it behind
    rm -f "$PID_FILE"
    rm -f "$LOCK_FILE"
    
    # Stop Nginx
    nginx -s stop 2>/dev/null || true

    echo "[shutdown] Cleanup complete. Exiting."
    exit 0
}

# Trap TERM and INT signals from Podman/Docker
trap 'cleanup' INT TERM

# Start rtorrent under tmux as user 'rtorrent'
echo "[init] Starting rtorrent inside tmux..."
# tmux new-session -d -s rtorrent-session rtorrent -n -o import=/data/rtorrent/config/.rtorrent.rc
su-exec rtorrent tmux new-session -d -s rtorrent-session rtorrent -n -o import=/data/rtorrent/config/.rtorrent.rc

# Start nginx
# exec /usr/sbin/nginx

# Keep container PID 1 running and wait for signals
echo "[init] Services started successfully. Monitoring..."
while true; do
    sleep 2 &
    wait $!
done