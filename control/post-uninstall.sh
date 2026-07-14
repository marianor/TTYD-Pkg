#!/bin/sh

PACKAGE_NAME="ttyd"
PID_FILE="/var/run/${PACKAGE_NAME}.pid"
LOG_FILE="/var/log/${PACKAGE_NAME}.log"
PKG_DIR="/usr/local/AppCentral/${PACKAGE_NAME}"

# Kill ttyd process by PID file
if [ -f "$PID_FILE" ]; then
    kill $(cat "$PID_FILE") 2>/dev/null
    rm -f "$PID_FILE"
fi

# Fallback: kill by process name if still running
if pgrep -x ttyd > /dev/null 2>&1; then
    pkill -x ttyd 2>/dev/null
fi

# Remove log file
rm -f "$LOG_FILE"

exit 0
