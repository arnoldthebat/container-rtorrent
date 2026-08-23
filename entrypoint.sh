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

# Pre-flight cleanup
if [ -f "$PID_FILE" ]; then
    echo "[init] Cleaning up stale PID file from previous run..."
    rm -f "$PID_FILE"
fi

if [ ! -r "$RTORRENT_RC" ]; then
    echo "[init] rTorrent configuration is missing or unreadable: $RTORRENT_RC" >&2
    exit 1
fi

# Start Nginx in background
echo "[init] Starting Nginx..."
nginx

# 3. Define Graceful Trap Handler
cleanup() {
    echo "[shutdown] Received termination signal. Stopping rtorrent cleanly..."
    
    # Send SIGINT (Ctrl+C equivalent) to rtorrent inside tmux
    if su-exec rtorrent tmux has-session -t rtorrent-session 2>/dev/null; then
        su-exec rtorrent tmux send-keys -t rtorrent-session:0.0 C-c

        COUNT=0
        while su-exec rtorrent tmux has-session -t rtorrent-session 2>/dev/null \
            && [ "$COUNT" -lt 10 ]; do
            sleep 1
            COUNT=$((COUNT + 1))
        done

        if su-exec rtorrent tmux has-session -t rtorrent-session 2>/dev/null; then
            su-exec rtorrent tmux kill-server 2>/dev/null || true
        fi
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
su-exec rtorrent tmux new-session -d -s rtorrent-session \
    rtorrent -n -o "import=${RTORRENT_RC}"

# Start nginx
# exec /usr/sbin/nginx

# Keep container PID 1 running and wait for signals
echo "[init] Services started successfully. Monitoring..."
while true; do
    sleep 2 &
    wait $!
done