#!/usr/bin/env bash
# BOTBOX: Hyper-V guest services + xrdp so the clipboard works (Enhanced Session / RDP).
set -e
echo "[1/4] hyper-v integration services (time-sync/KVP/VSS/file-copy)"
sudo apt-get update -y
sudo apt-get install -y linux-cloud-tools-virtual || true
echo "[2/4] xrdp (RDP server -> clipboard)"
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y xrdp xorgxrdp
sudo adduser xrdp ssl-cert 2>/dev/null || true
echo "[3/4] force Xorg session (Wayland breaks xrdp)"
sudo mkdir -p /etc/gdm3
if sudo test -f /etc/gdm3/custom.conf; then
  sudo sed -i 's/^#\?WaylandEnable=.*/WaylandEnable=false/' /etc/gdm3/custom.conf
  sudo grep -q '^WaylandEnable=false' /etc/gdm3/custom.conf || printf '\nWaylandEnable=false\n' | sudo tee -a /etc/gdm3/custom.conf >/dev/null
else
  printf '[daemon]\nWaylandEnable=false\n' | sudo tee /etc/gdm3/custom.conf >/dev/null
fi
echo "[4/4] enable xrdp"
sudo systemctl enable --now xrdp
sudo systemctl restart xrdp || true
echo
echo "XRDP_READY"
echo "  clipboard path A: Windows Remote Desktop (mstsc) -> 192.168.1.95   (works now)"
echo "  clipboard path B: Hyper-V Manager -> VM settings -> Enhanced session, then vmconnect"
echo "Reboot recommended: sudo reboot"