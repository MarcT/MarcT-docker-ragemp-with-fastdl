#!/bin/bash
set -e

# Named pipes for log forwarding
NGINX_LOG_PIPE=/tmp/nginx.log.pipe
RAGEMP_LOG_PIPE=/tmp/ragemp.log.pipe

mkfifo $NGINX_LOG_PIPE $RAGEMP_LOG_PIPE

# ANSI color codes
BLUE="\033[34m"    # NGINX normal output
YELLOW="\033[33m"  # RAGEMP normal output
GREEN="\033[32m"   # info messages
RED="\033[31m"     # crash/restart
RESET="\033[0m"

# Function to colorize logs based on keywords
colorize() {
    local service="$1"
    while IFS= read -r line; do
        # Info messages
        if [[ "$line" =~ [Ss]tarting|[Ii]nfo|[Ll]oaded ]]; then
            echo -e "${GREEN}[${service}]${RESET} $line"
        # Crash/restart messages
        elif [[ "$line" =~ [Cc]rash|[Ff]ail|[Rr]estart ]]; then
            echo -e "${RED}[${service}]${RESET} $line"
        # Normal output
        else
            if [[ "$service" == "NGINX" ]]; then
                echo -e "${BLUE}[${service}]${RESET} $line"
            else
                echo -e "${YELLOW}[${service}]${RESET} $line"
            fi
        fi
    done
}

# Forward logs to Docker stdout
tail -f $NGINX_LOG_PIPE | colorize "NGINX" &
tail -f $RAGEMP_LOG_PIPE | colorize "RAGEMP" &

# Function to run Nginx with restart
run_nginx() {
    while true; do
        echo "Starting Nginx..." > $NGINX_LOG_PIPE
        nginx -g 'daemon off;' > $NGINX_LOG_PIPE 2>&1
        echo "Nginx crashed! Restarting in 2s..." > $NGINX_LOG_PIPE
        sleep 2
    done
}

# Function to run RageMP with restart
run_ragemp() {
    while true; do
        echo "Starting RageMP..." > $RAGEMP_LOG_PIPE
        ./start_server.sh > $RAGEMP_LOG_PIPE 2>&1
        echo "RageMP crashed! Restarting in 2s..." > $RAGEMP_LOG_PIPE
        sleep 2
    done
}

# Start both processes
run_nginx &
run_ragemp &

# Wait forever
wait
