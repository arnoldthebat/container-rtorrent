#!/bin/sh
set -u

RPC_HOST="127.0.0.1"
RPC_PORT="8000"
RPC_PATH="/RPC2"

proc_running() {
    for pid_comm in /proc/[0-9]*/comm; do
        [ -r "$pid_comm" ] || continue
        if [ "$(cat "$pid_comm" 2>/dev/null)" = "$1" ]; then
            return 0
        fi
    done
    return 1
}

proc_running_prefix() {
    for pid_comm in /proc/[0-9]*/comm; do
        [ -r "$pid_comm" ] || continue
        case "$(cat "$pid_comm" 2>/dev/null)" in
            "$1"*) return 0 ;;
        esac
    done
    return 1
}

if ! proc_running "nginx"; then
    echo "unhealthy: nginx not running"
    exit 1
fi

if ! su-exec rtorrent tmux has-session -t rtorrent-session 2>/dev/null; then
    echo "unhealthy: rtorrent tmux session not found"
    exit 1
fi

if ! proc_running_prefix "rtorrent"; then
    echo "unhealthy: rtorrent process not found"
    exit 1
fi

python3 - "$RPC_HOST" "$RPC_PORT" "$RPC_PATH" <<'PYEOF'
import http.client
import sys

host, port, path = sys.argv[1], int(sys.argv[2]), sys.argv[3]
body = (
    b'<?xml version="1.0"?>'
    b"<methodCall><methodName>system.pid</methodName><params></params></methodCall>"
)

try:
    conn = http.client.HTTPConnection(host, port, timeout=5)
    conn.request("POST", path, body=body,
                 headers={"Content-Type": "text/xml", "Content-Length": str(len(body))})
    resp = conn.getresponse()
    data = resp.read()
    conn.close()
except Exception as e:
    print(f"unhealthy: HTTP request failed: {e}")
    sys.exit(1)

if resp.status != 200 or b"methodResponse" not in data or b"fault" in data.lower():
    print(f"unhealthy: unexpected RPC response (status={resp.status})")
    sys.exit(1)

sys.exit(0)
PYEOF

if [ $? -ne 0 ]; then
    exit 1
fi

echo "healthy"
exit 0