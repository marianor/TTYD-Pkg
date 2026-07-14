#!/bin/sh

PACKAGE_NAME="ttyd"
PKG_DIR="/usr/local/AppCentral/${PACKAGE_NAME}"
TTYD_BIN="${PKG_DIR}/bin/ttyd"
PID_FILE="/var/run/${PACKAGE_NAME}.pid"
LOG_FILE="/var/log/${PACKAGE_NAME}.log"
CERT_FILE="/usr/builtin/etc/certificate/ssl.crt"
KEY_FILE="/usr/builtin/etc/certificate/ssl.key"

PORT="7681"

start() {
    if [ -f "$PID_FILE" ] && kill -0 $(cat "$PID_FILE") 2>/dev/null; then
        echo "${PACKAGE_NAME} is already running."
        return 1
    fi

    echo "Starting ${PACKAGE_NAME}..."
    "${PKG_DIR}/gen-html.sh"

    $TTYD_BIN \
        -p $PORT \
        --ssl --ssl-cert "$CERT_FILE" --ssl-key "$KEY_FILE" \
        --writable \
        --max-clients 1 \
        --check-origin \
        --ping-interval 5 \
        -I "${PKG_DIR}/index.html" \
        login >> $LOG_FILE 2>&1 &

    echo $! > "$PID_FILE"
    echo "${PACKAGE_NAME} started on 0.0.0.0:${PORT} (TLS)"
}

stop() {
    if [ -f "$PID_FILE" ]; then
        echo "Stopping ${PACKAGE_NAME}..."
        kill $(cat "$PID_FILE") 2>/dev/null
        rm -f "$PID_FILE"
        echo "${PACKAGE_NAME} stopped."
    else
        echo "${PACKAGE_NAME} is not running."
    fi
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
