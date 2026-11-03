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
WATCH_PID_FILE="/var/run/${PACKAGE_NAME}-watch.pid"
CERT_CHECK_INTERVAL=3600
CERT_SETTLE_TIME=5
CERT_PENDING_INTERVAL=60
CERT_MAX_DEFER=604800

export LOGIN_TIMEOUT=0

cert_state() {
    [ -s "$CERT_FILE" ] && [ -s "$KEY_FILE" ] || return 0
    cat "$CERT_FILE" "$KEY_FILE" 2>/dev/null
}

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [cert-watch] $*"
}

start_ttyd() {
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

    CERT_SNAPSHOT=$(cert_state)

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

    sleep 1
    if kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        return 0
    fi
    CERT_SNAPSHOT=""
    return 1
}

stop_ttyd() {
    if [ -f "$PID_FILE" ]; then
        kill $(cat "$PID_FILE") 2>/dev/null
        rm -f "$PID_FILE"
    fi
}

client_count() {
    hex=$(printf '%04X' "${PORT:-7681}")
    awk -v p="$hex" '$4 == "01" { n = split($2, a, ":"); if (toupper(a[n]) == p) c++ } END { print c + 0 }' \
        /proc/net/tcp /proc/net/tcp6 2>/dev/null
}

# ttyd only reads its certificate at startup, so restart it when the NAS renews it,
# waiting for open sessions to end (up to CERT_MAX_DEFER seconds).
watch_cert() {
    log "watching ${CERT_FILE} every ${CERT_CHECK_INTERVAL}s"
    pending_since=""
    wait_time="$CERT_CHECK_INTERVAL"
    while sleep "$wait_time"; do
        now=$(cert_state)
        if [ -z "$now" ] || [ "$now" = "$CERT_SNAPSHOT" ]; then
            pending_since=""
            wait_time="$CERT_CHECK_INTERVAL"
            continue
        fi

        sleep "$CERT_SETTLE_TIME"
        [ "$(cert_state)" = "$now" ] || continue

        now_ts=$(date +%s)
        if [ -z "$pending_since" ]; then
            pending_since="$now_ts"
            log "certificate changed"
        fi

        clients=$(client_count)
        if [ "${clients:-0}" -gt 0 ] && [ $((now_ts - pending_since)) -lt "$CERT_MAX_DEFER" ]; then
            [ "$wait_time" = "$CERT_PENDING_INTERVAL" ] || log "${clients} client(s) connected, waiting for them to disconnect"
            wait_time="$CERT_PENDING_INTERVAL"
            continue
        fi

        log "restarting ${PACKAGE_NAME} to load the new certificate (${clients:-0} client(s) connected)"
        stop_ttyd
        sleep 1
        if start_ttyd; then
            log "${PACKAGE_NAME} restarted"
        else
            log "${PACKAGE_NAME} failed to restart, will retry"
        fi
        pending_since=""
        wait_time="$CERT_CHECK_INTERVAL"
    done
}

start() {
    if [ -f "$PID_FILE" ] && kill -0 $(cat "$PID_FILE") 2>/dev/null; then
        echo "${PACKAGE_NAME} is already running."
        return 1
    fi

    echo "Starting ${PACKAGE_NAME}..."
    if start_ttyd; then
        echo "${PACKAGE_NAME} started."
    else
        echo "${PACKAGE_NAME} failed to start, see ${LOG_FILE}."
    fi

    watch_cert >> "$LOG_FILE" 2>&1 < /dev/null &
    echo $! > "$WATCH_PID_FILE"
}

stop() {
    if [ -f "$WATCH_PID_FILE" ]; then
        kill $(cat "$WATCH_PID_FILE") 2>/dev/null
        rm -f "$WATCH_PID_FILE"
    fi
    if [ -f "$PID_FILE" ]; then
        echo "Stopping ${PACKAGE_NAME}..."
        stop_ttyd
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
