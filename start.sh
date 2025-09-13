#!/bin/bash
set -e

# Function to run Nginx and restart if it crashes
run_nginx() {
    while true; do
        echo "[NGINX] Starting Nginx..."
        nginx -g 'daemon off;'
        echo "[NGINX] Nginx crashed! Restarting in 2s..."
        sleep 2
    done
}

# Function to run RageMP server and restart if it crashes
run_ragemp() {
    while true; do
        echo "[RAGEMP] Starting RageMP..."
        ./start_server.sh
        echo "[RAGEMP] RageMP crashed! Restarting in 2s..."
        sleep 2
    done
}

# Start both in the background
run_nginx &
NGINX_PID=$!

run_ragemp &
RAGEMP_PID=$!

# Wait for both processes (this keeps the container running)
wait $NGINX_PID $RAGEMP_PID