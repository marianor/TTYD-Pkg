#!/bin/sh

. /etc/script/lib/apkg_path.sh 2>/dev/null
PKG_DIR="${PKG_DIR:-/usr/local/AppCentral/ttyd}"

PACKAGE_NAME="ttyd"
TTYD_BIN="${PKG_DIR}/bin/ttyd"
PID_FILE="/var/run/${PACKAGE_NAME}.pid"
LOG_FILE="${PKG_DIR}/var/${PACKAGE_NAME}.log"
SETTINGS_FILE="${PKG_DIR}/etc/settings.conf"
CERT_FILE="/usr/builtin/etc/certificate/ssl.crt"
KEY_FILE="/usr/builtin/etc/certificate/ssl.key"

export LOGIN_TIMEOUT=0

start() {
    if [ -f "$PID_FILE" ] && kill -0 $(cat "$PID_FILE") 2>/dev/null; then
        echo "${PACKAGE_NAME} is already running."
        return 1
    fi

    echo "Starting ${PACKAGE_NAME}..."
    mkdir -p "${PKG_DIR}/var"

    # Rotate logs (keep last 5, max 1MB)
    if [ -f "$LOG_FILE" ]; then
        SIZE=$(wc -c < "$LOG_FILE" 2>/dev/null || echo 0)
        if [ "$SIZE" -gt 1048576 ]; then
            for i in 5 4 3 2; do
                [ -f "${LOG_FILE}.$i" ] && mv "${LOG_FILE}.$i" "${LOG_FILE}.$((i+1))"
            done
            mv "$LOG_FILE" "${LOG_FILE}.1"
            rm -f "${LOG_FILE}.6" "${LOG_FILE}.7" "${LOG_FILE}.8" "${LOG_FILE}.9"
        fi
    fi

    PORT=$(sed -n '/\[General\]/,/^\[/p' "$SETTINGS_FILE" | grep '^port=' | cut -d'=' -f2)
    MAX_CLIENTS=$(sed -n '/\[General\]/,/^\[/p' "$SETTINGS_FILE" | grep '^max-clients=' | cut -d'=' -f2)
    PING_INTERVAL=$(sed -n '/\[General\]/,/^\[/p' "$SETTINGS_FILE" | grep '^ping-interval=' | cut -d'=' -f2)

    set --
    while IFS= read -r line; do
        set -- "$@" "--client-option" "$line"
    done <<EOF
$(sed -n '/\[ClientOptions\]/,$p' "$SETTINGS_FILE" | grep -v '^\[' | grep -v '^$')
EOF

    "$TTYD_BIN" \
        --port "${PORT:-7681}" \
        --ssl \
        --ssl-cert "$CERT_FILE" \
        --ssl-key "$KEY_FILE" \
        --max-clients "${MAX_CLIENTS:-1}" \
        --ping-interval "${PING_INTERVAL:-5}" \
        "$@" \
        --writable /bin/login >> "$LOG_FILE" 2>&1 &

    echo $! > "$PID_FILE"
    echo "${PACKAGE_NAME} started."
}

stop() {
    if [ -f "$PID_FILE" ]; then
        echo "Stopping ${PACKAGE_NAME}..."
        kill $(cat "$PID_FILE") 2>/dev/null
        rm -f "$PID_FILE"
    fi
    echo "${PACKAGE_NAME} stopped."
}

restart() {
    stop
    sleep 1
    start
}

case "$1" in
    start)   start ;;
    stop)    stop ;;
    restart) restart ;;
    *)       echo "Usage: $0 {start|stop|restart}" ;;
esac

exit 0
