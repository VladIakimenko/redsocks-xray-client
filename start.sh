#!/bin/bash

BASE_DIR=$(pwd)


# Load .env variables
if [ -f $BASE_DIR/.env ]; then
    export $(grep -v '^#' $BASE_DIR/.env | xargs)
else
    echo "Error: .env not found"
    exit 1
fi

# Check if the script is run as superuser
if [ "$EUID" -ne 0 ]; then
    echo "Error: run as root or use sudo"
    exit 1
fi


# Define log file paths
LOG_DIR="/home/vladiakimenko/projects/gateway/logs"
REDSOCKS_LOG="$LOG_DIR/redsocks.log"
XRAY_LOG="$LOG_DIR/xray-core.log"

# Define binary paths
REDSOCKS_BINARY="redsocks"
REDSOCKS_CONF="/home/vladiakimenko/projects/gateway/redsocks/redsocks.conf"
XRAY_BINARY="/home/vladiakimenko/projects/gateway/xray-core/xray"
XRAY_CONF="/home/vladiakimenko/projects/gateway/xray-core/config.json"


# Generate configs for redsocks and xray (supstitute placeholders with values from .env)
REDSOCKS_TEMPLATE="$BASE_DIR/redsocks/redsocks.conf.template"
XRAY_TEMPLATE="$BASE_DIR/xray-core/config.json.template"
envsubst < "$REDSOCKS_TEMPLATE" > "$REDSOCKS_CONF"
envsubst < "$XRAY_TEMPLATE" > "$XRAY_CONF"


# Save the current iptables rules
iptables-save > /tmp/iptables-backup.rules

# Define cleanup function to unset variables and restore iptables on exit
cleanup() {
    echo "Cleaning up..."

    # Terminate background processes for redsocks and xray-core
    echo "Stopping redsocks and xray-core..."
    pkill -f redsocks
    pkill -f xray-core

    # Restore the original iptables configuration
    echo "Restoring original iptables settings..."
    iptables-restore < /tmp/iptables-backup.rules
    rm /tmp/iptables-backup.rules

    echo "Iptables rules restored. Exiting"
}

# Trap exit signals to ensure cleanup is called
trap cleanup EXIT


# Set up iptables for redsocks
echo "Setting up iptables rules for redsocks..."

# Configure iptables to route traffic through redsocks
# Redsocks will forward the traffic to xray-core for SOCKS5 processing.

# Step 1: Create a custom chain for redsocks
# This chain will handle traffic redirection to redsocks based on specific rules.
iptables -t nat -N REDSOCKS

# Step 2: Exclude local and private network traffic
# Traffic to the following ranges is excluded to avoid interference with local communications and prevent infinite proxy loops:
# - 0.0.0.0/8: Reserved, non-routable.
# - 10.0.0.0/8: Private network.
# - 127.0.0.0/8: Localhost, including redsocks and xray-core services.
# - 169.254.0.0/16: Link-local addresses (auto-configured if no DHCP is available).
# - 172.16.0.0/12: Private network.
# - 192.168.0.0/16: Private network.
# - 224.0.0.0/4: Multicast addresses.
# - 240.0.0.0/4: Reserved for future use.
iptables -t nat -A REDSOCKS -d 0.0.0.0/8 -j RETURN
iptables -t nat -A REDSOCKS -d 10.0.0.0/8 -j RETURN
iptables -t nat -A REDSOCKS -d 127.0.0.0/8 -j RETURN
iptables -t nat -A REDSOCKS -d 169.254.0.0/16 -j RETURN
iptables -t nat -A REDSOCKS -d 172.16.0.0/12 -j RETURN
iptables -t nat -A REDSOCKS -d 192.168.0.0/16 -j RETURN
iptables -t nat -A REDSOCKS -d 224.0.0.0/4 -j RETURN
iptables -t nat -A REDSOCKS -d 240.0.0.0/4 -j RETURN

# Step 3: Exclude xray traffic to the remote proxy (185.201.252.23:443)
iptables -t nat -A REDSOCKS -d 185.201.252.23 -p tcp --dport 443 -j RETURN

# Step 4: Redirect remaining traffic to redsocks
# All TCP traffic not excluded by the above rules is redirected to port 31338 (the default listening port for redsocks).
iptables -t nat -A REDSOCKS -p tcp -j REDIRECT --to-ports 31338

# Step 5: Apply the redsocks chain to outgoing and prerouting traffic
# Redirect HTTP (port 80) and HTTPS (port 443) traffic to the REDSOCKS chain.
iptables -t nat -A OUTPUT -p tcp --dport 80 -j REDSOCKS
iptables -t nat -A OUTPUT -p tcp --dport 443 -j REDSOCKS
iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDSOCKS
iptables -t nat -A PREROUTING -p tcp --dport 443 -j REDSOCKS


# Ensure log directory exists
mkdir -p "$LOG_DIR"

# Start redsocks as a background process with logging to a file
echo "Starting redsocks..."
"$REDSOCKS_BINARY" -c "$REDSOCKS_CONF" >"$REDSOCKS_LOG" 2>&1 &

# Start xray-core as a background process with logging to a file
echo "Starting xray-core..."
"$XRAY_BINARY" -c "$XRAY_CONF" >"$XRAY_LOG" 2>&1 &

echo "Logs are being written to:"
echo "  Redsocks: $REDSOCKS_LOG"
echo "  Xray-Core: $XRAY_LOG"

# Keep the script running
wait
