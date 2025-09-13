#!/bin/bash
set -e

# Named pipes for log forwarding
NGINX_LOG_PIPE=/tmp/nginx.log.pipe
RAGEMP_LOG_PIPE=/tmp/ragemp.log.pipe

# Create FIFOs if they don't exist
[ ! -p $NGINX_LOG_PIPE ] && mkfifo $NGINX_LOG_PIPE
[ ! -p $RAGEMP_LOG_PIPE ] && mkfifo $RAGEMP_LOG_PIPE

# ANSI colors
BLUE="\033[34m"    # NGINX normal
YELLOW="\033[33m"  # RAGEMP normal
GREEN="\033[32m"   # info messages
RED="\033[31m"     # crash/restart
RESET="\033[0m"

# Function to colorize and timestamp logs
colorize() {
    local service="$1"
    while IFS= read -r line; do
        TIMESTAMP=$(date "+%Y/%m/%d %H:%M:%S")
        if [[ "$line" =~ [Ss]tarting|[Ii]nfo|[Ll]oaded ]]; then
            echo -e "${GREEN}[${service}] $TIMESTAMP${RESET} $line"
        elif [[ "$line" =~ [Cc]rash|[Ff]ail|[Rr]estart ]]; then
            echo -e "${RED}[${service}] $TIMESTAMP${RESET} $line"
        else
            if [[ "$service" == "NGINX" ]]; then
                echo -e "${BLUE}[${service}] $TIMESTAMP${RESET} $line"
            else
                echo -e "${YELLOW}[${service}] $TIMESTAMP${RESET} $line"
            fi
        fi
    done
}

# Forward logs to colorizer
tail -f $NGINX_LOG_PIPE | colorize "NGINX" &
tail -f $RAGEMP_LOG_PIPE | colorize "RAGEMP" &

# Nginx restart loop
run_nginx() {
    while true; do
        echo "Starting Nginx..." > $NGINX_LOG_PIPE
        # Link logs to FIFO
        ln -sf /tmp/nginx-error.log $NGINX_LOG_PIPE
        ln -sf /tmp/nginx-access.log $NGINX_LOG_PIPE
        # Run nginx in foreground
        nginx -g "daemon off;" -c /etc/nginx/nginx.conf
        echo "Nginx crashed! Restarting in 2s..." > $NGINX_LOG_PIPE
        sleep 2
    done
}

# RageMP restart loop
run_ragemp() {
    while true; do
        echo "Starting RageMP..." > $RAGEMP_LOG_PIPE
        cd /ragemp/ragemp-srv
        # Generate conf.json
        stdbuf -oL -eL /ragemp/config-generator.pl > ./conf.json
        if [[ ! -s ./conf.json ]]; then
            echo "RageMP: conf.json is empty, check config-generator.pl" > $RAGEMP_LOG_PIPE
        fi
        # Run ragemp-server in foreground with log redirection
        stdbuf -oL -eL ./ragemp-server \
            > >(while IFS= read -r line; do echo "$line" > $RAGEMP_LOG_PIPE; done) \
            2>&1 &
        RAGEMP_PID=$!
        wait $RAGEMP_PID
        echo "RageMP crashed! Restarting in 2s..." > $RAGEMP_LOG_PIPE
        sleep 2
    done
}

# Start both services
run_nginx &
run_ragemp &

wait
