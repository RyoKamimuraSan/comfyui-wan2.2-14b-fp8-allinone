#!/bin/bash
# Paperspace idle shutdown prevention

if [ "$ENABLE_KEEPALIVE" != "true" ]; then
    echo "[KEEPALIVE] Disabled (set ENABLE_KEEPALIVE=true to enable)"
    exec sleep infinity
fi

INTERVAL=900  # 15分
TARGET_URL="http://localhost:8888/api"

echo "[KEEPALIVE] Starting beacon (interval: ${INTERVAL}s)"

while true; do
    sleep $INTERVAL
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$TARGET_URL" 2>/dev/null || echo "000")
    echo "[KEEPALIVE] Beacon sent (HTTP $HTTP_CODE)"
done
