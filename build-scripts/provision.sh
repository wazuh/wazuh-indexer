#!/bin/bash
set -e

# Environment Detection
# Extract OS ID from os-release
OS_ID=$(grep -oP '^ID=\K.*' /etc/os-release | tr -d '"')
# Detect CPU Architecture
ARCH=$(uname -m)

echo "--- Starting Provisioning ---"
echo "OS Detected: $OS_ID"
echo "Architecture Detected: $ARCH"


# Distribution logic (deb or rpm)
case "$OS_ID" in
    ubuntu|debian)
        echo "Processing dependencies for DEB-based system..."
        sudo apt-get update -y && sudo apt-get upgrade -y
        sudo apt-get install -y curl build-essential debmake debhelper-compat \
            libxrender1 libxtst6 libxi6 libatk1.0-0 libatk-bridge2.0-0 libcups2 \
            libdrm2 libatspi2.0-dev libxcomposite-dev libxdamage1 libxfixes3 \
            libxfixes-dev libxrandr2 libgbm-dev libxkbcommon-x11-0 \
            libpangocairo-1.0-0 libcairo2 libcairo2-dev libnss3 libnspr4 \
            libnspr4-dev jq
        sudo apt-get clean -y
        ;;

    centos|rhel|amzn|almalinux|rocky)
        echo "Processing dependencies for RPM-based system..."
        sudo yum update -y
        sudo yum groupinstall -y "Development Tools"
        sudo yum install -y curl jq maven rpm-build cpio openssl-devel
        ;;
    *)
        echo "Warning: Unsupported OS ID '$OS_ID'. Proceeding with generic steps..."
        ;;
esac


# Arquitecture logic
# ==========================================
if [[ "$ARCH" == "aarch64" ]]; then
    echo "ARM64 detected: Executing architecture-specific commands..."

    # If we are on an ARM64 machine but need to build RPMs/General packages
    if [[ "$OS_ID" == "ubuntu" || "$OS_ID" == "debian" ]]; then
        echo "Installing build tools for ARM64 (Ubuntu/Debian)..."
        sudo apt-get update
        sudo apt-get install -y maven rpm cpio

        # Docker installation logic (specifically for ARM64 workflows)
        if ! command -v docker &> /dev/null; then
            echo "Docker not found. Installing Docker for ARM64..."
            sudo apt-get install -y docker.io
            sudo systemctl start docker || true
            sudo chmod 666 /var/run/docker.sock || true
        fi
    fi
fi




