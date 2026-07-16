#!/bin/sh

. /etc/script/lib/apkg_path.sh

PACKAGE_NAME="ttyd"
PID_FILE="/var/run/${PACKAGE_NAME}.pid"
LOG_FILE="${PKG_DIR}/var/${PACKAGE_NAME}.log"

# Kill ttyd process by PID file
if [ -f "$PID_FILE" ]; then
    kill $(cat "$PID_FILE") 2>/dev/null
    rm -f "$PID_FILE"
fi

# Fallback: kill by process name if still running
if pgrep -x ttyd > /dev/null 2>&1; then
    pkill -x ttyd 2>/dev/null
fi

# Rotate log files (keep last 5)
for i in 5 4 3 2; do
    [ -f "${LOG_FILE}.$i" ] && mv "${LOG_FILE}.$i" "${LOG_FILE}.$((i+1))"
done
[ -f "$LOG_FILE" ] && mv "$LOG_FILE" "${LOG_FILE}.1"

# Remove rotated logs older than 5
rm -f "${LOG_FILE}.6" "${LOG_FILE}.7" "${LOG_FILE}.8" "${LOG_FILE}.9"

exit 0
