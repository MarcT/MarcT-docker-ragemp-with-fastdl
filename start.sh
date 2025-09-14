#!/bin/bash
set -e

# --- SETTINGS ---
NGINX_ACCESS_LOG=/var/log/nginx/access.log
NGINX_ERROR_LOG=/var/log/nginx/error.log
RAGEMP_DIR=/ragemp/ragemp-srv
RAGEMP_CONFIG_GEN=/ragemp/config-generator.pl

# --- ANSI COLORS ---
BLUE="\033[34m"    # NGINX normal
YELLOW="\033[33m"  # RAGEMP normal
GREEN="\033[32m"   # info messages
RED="\033[31m"     # crash/restart
RESET="\033[0m"

# --- Clean shutdown on SIGTERM / SIGINT ---
trap 'echo "Stopping services..."; kill 0' SIGTERM SIGINT

# --- Colorize and timestamp logs ---
colorize() {
    local service="$1" color="$2"
    while IFS= read -r line; do
        ts=$(date "+%Y/%m/%d %H:%M:%S")
        if [[ "$line" =~ [Ss]tarting|[Ii]nfo|[Ll]oaded ]]; then
            echo -e "${GREEN}[${service}] $ts${RESET} $line"
        elif [[ "$line" =~ [Cc]rash|[Ff]ail|[Rr]estart ]]; then
            echo -e "${RED}[${service}] $ts${RESET} $line"
        else
            echo -e "${color}[${service}] $ts${RESET} $line"
        fi
    done
}

# --- Tail NGINX logs directly to stdout ---
stdbuf -oL -eL tail -F "$NGINX_ERROR_LOG" "$NGINX_ACCESS_LOG" | colorize "NGINX" "$BLUE" &

# --- Nginx restart loop ---
run_nginx() {
    while true; do
        echo -e "${GREEN}[NGINX] $(date "+%Y/%m/%d %H:%M:%S")${RESET} Starting Nginx..."
        nginx -g "daemon off;" -c /etc/nginx/nginx.conf
        echo -e "${RED}[NGINX] $(date "+%Y/%m/%d %H:%M:%S")${RESET} Nginx crashed! Restarting in 2s..."
        sleep 2
    done
}

# --- RageMP restart loop ---
run_ragemp() {
    while true; do
        echo -e "${GREEN}[RAGEMP] $(date "+%Y/%m/%d %H:%M:%S")${RESET} Starting RageMP..."
        cd "$RAGEMP_DIR"
        if ! stdbuf -oL -eL "$RAGEMP_CONFIG_GEN" > ./conf.json || [[ ! -s ./conf.json ]]; then
            echo -e "${RED}[RAGEMP] $(date "+%Y/%m/%d %H:%M:%S")${RESET} conf.json generation failed!" 
            sleep 5
            continue
        fi

        # Run ragemp-server detached from TTY
        setsid stdbuf -oL -eL ./ragemp-server \
            > >(colorize "RAGEMP" "$YELLOW") \
            2>&1 < /dev/null &

        RAGEMP_PID=$!
        wait $RAGEMP_PID
        echo -e "${RED}[RAGEMP] $(date "+%Y/%m/%d %H:%M:%S")${RESET} RageMP crashed! Restarting in 2s..."
        sleep 2
    done
}

# --- Start both services ---
run_nginx &
run_ragemp &

wait
