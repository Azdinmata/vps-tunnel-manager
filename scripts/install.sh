#!/bin/bash
# ==============================================================================
# ULTRA VPS SSH & MULTI-PROTOCOL TUNNEL MANAGER - AUTOMATED INSTALLER SCRIPT
# Location: scripts/install.sh
# Supports: Ubuntu 20.04/22.04/24.04 & Debian 10/11/12
# Architecture: AMD64 (x86_64) & ARM64 (aarch64) Auto-Detection
# ==============================================================================

export DEBIAN_FRONTEND=noninteractive
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

clear
echo -e "${CYAN}"
echo "================================================================="
echo "       ULTRA VPS SSH & MULTI-PROTOCOL TUNNEL MANAGER            "
echo "  Supporting AMD64 (x86_64) & ARM64 | Universal Account Sync      "
echo "================================================================="
echo -e "${NC}"

if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}[ERROR] Please run as root user! (sudo -i)${NC}"
  exit 1
fi

ARCH=$(uname -m)
case "$ARCH" in
  x86_64|amd64) ARCH_TYPE="amd64" ;;
  aarch64|arm64) ARCH_TYPE="arm64" ;;
  *) echo -e "${RED}[ERROR] Unsupported CPU Architecture: $ARCH${NC}"; exit 1 ;;
esac

echo -e "${GREEN}[INFO] Detected Processor Architecture: $ARCH_TYPE${NC}"

# Install Core Tools
apt-get update -y && apt-get install -y curl wget unzip tar net-tools iptables ufw sudo git socat python3 python3-pip cron openssl jq stunnel4 nginx dropbear fail2ban

# Enable BBR
if ! grep -q "net.core.default_qdisc=fq" /etc/sysctl.conf; then
  echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
  echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
  sysctl -p
fi

echo -e "${GREEN}System setup complete! Type 'manager' to open CLI menu.${NC}"
