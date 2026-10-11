#!/usr/bin/env bash
# BOTBOX — end-to-end provisioning for a disposable bot sandbox VM (Ubuntu Desktop 24.04 LTS)
# Run INSIDE a freshly installed Ubuntu Desktop VM as the initial admin user:
#   curl -fsSL <RAW_URL>/bootstrap.sh | bash -s -- [options]
# Idempotent: safe to re-run.
set -euo pipefail

log()  { printf '\033[1;34m[botbox]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[botbox]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[botbox]\033[0m %s\n' "$*" >&2; exit 1; }

SSH_PUBKEY="${SSH_PUBKEY:-}"
NVIDIA_API_KEY="${NVIDIA_API_KEY:-}"
DEEPINFRA_API_KEY="${DEEPINFRA_API_KEY:-}"
OPENSCALE_API_KEY="${OPENSCALE_API_KEY:-}"
NEXTCLOUD_URL="${NEXTCLOUD_URL:-}"
NEXTCLOUD_USER="${NEXTCLOUD_USER:-}"
NEXTCLOUD_PASS="${NEXTCLOUD_PASS:-}"
WITH_DOCKER=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --ssh-pubkey) SSH_PUBKEY="$2"; shift 2 ;;
    --ssh-pubkey-file) SSH_PUBKEY="$(cat "$2")"; shift 2 ;;
    --nvidia-key) NVIDIA_API_KEY="$2"; shift 2 ;;
    --deepinfra-key) DEEPINFRA_API_KEY="$2"; shift 2 ;;
    --openscale-key) OPENSCALE_API_KEY="$2"; shift 2 ;;
    --nextcloud-url) NEXTCLOUD_URL="$2"; shift 2 ;;
    --nextcloud-user) NEXTCLOUD_USER="$2"; shift 2 ;;
    --nextcloud-pass) NEXTCLOUD_PASS="$2"; shift 2 ;;
    --with-docker) WITH_DOCKER=1; shift ;;
    *) die "unknown option: $1" ;;
  esac
done

[[ $EUID -eq 0 ]] && die "run as the initial desktop user, not root"
[[ -r /etc/os-release ]] && grep -qi ubuntu /etc/os-release || warn "not Ubuntu — continuing best-effort"
command -v systemctl >/dev/null || die "systemd required"

U="$USER"
HOMEDIR="$HOME"
LAN_CIDR="${LAN_CIDR:-192.168.1.0/24}"

interactive() { [[ -t 0 ]] && [[ -t 1 ]]; }

if interactive; then
  [[ -z "$SSH_PUBKEY" ]] && { read -r -p "Paste the host's SSH public key (~/.ssh/id_ed25519.pub) for bot access [skip]: " SSH_PUBKEY || true; }
  [[ -z "$NVIDIA_API_KEY" ]] && { read -r -p "NVIDIA_API_KEY [skip]: " NVIDIA_API_KEY || true; }
  [[ -z "$DEEPINFRA_API_KEY" ]] && { read -r -p "DEEPINFRA_API_KEY [skip]: " DEEPINFRA_API_KEY || true; }
  [[ -z "$NEXTCLOUD_URL" ]] && { read -r -p "Nextcloud URL e.g. https://cloud.cryptocomputer.ca [skip]: " NEXTCLOUD_URL || true; }
  if [[ -n "$NEXTCLOUD_URL" ]]; then
    [[ -z "$NEXTCLOUD_USER" ]] && read -r -p "Nextcloud app-user for BOTBOX: " NEXTCLOUD_USER
    [[ -z "$NEXTCLOUD_PASS" ]] && read -r -s -p "Nextcloud app-password: " NEXTCLOUD_PASS && echo
  fi
fi

log "1/9 packages"
sudo apt-get update -y
sudo apt-get install -y openssh-server git curl wget ripgrep jq tmux htop \
  build-essential python3 python3-pip imagemagick scrot xdotool xclip \
  dbus-x11 ca-certificates gnupg
if [[ $WITH_DOCKER -eq 1 ]]; then
  curl -fsSL https://get.docker.com | sudo sh
  sudo usermod -aG docker "$U"
fi

log "2/9 ssh"
sudo systemctl enable --now ssh
if [[ -n "${SSH_PUBKEY// /}" ]]; then
  install -d -m 700 "$HOMEDIR/.ssh"
  grep -qF "$SSH_PUBKEY" "$HOMEDIR/.ssh/authorized_keys" 2>/dev/null || echo "$SSH_PUBKEY" >> "$HOMEDIR/.ssh/authorized_keys"
  chmod 600 "$HOMEDIR/.ssh/authorized_keys"
else
  warn "no SSH pubkey provided — bots on the host cannot SSH in until you add one"
  warn "later fix:  echo '<pubkey>' >> ~/.ssh/authorized_keys"
fi
SSHD=/etc/ssh/sshd_config.d/99-botbox.conf
sudo tee "$SSHD" >/dev/null <<'EOF'
PasswordAuthentication no
PermitRootLogin no
X11Forwarding yes
EOF

log "3/9 firewall (LAN only)"
sudo install -d /etc/ufw/applications.d
sudo ufw allow from "$LAN_CIDR" to any port 22 proto tcp
sudo ufw allow from "$LAN_CIDR" to any port 4096 proto tcp
sudo ufw --force enable

log "4/9 opencode binary"
OC_BIN="$(command -v opencode || true)"
if [[ -z "$OC_BIN" ]] || ! opencode --version >/dev/null 2>&1; then
  curl -fsSL https://opencode.ai/install | bash || true
  export PATH="$HOME/.opencode/bin:$PATH"
  OC_BIN="$(command -v opencode || true)"
  if [[ -z "$OC_BIN" ]]; then
    warn "official installer failed — falling back to npm"
    curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
    sudo apt-get install -y nodejs
    sudo npm install -g opencode-ai
    OC_BIN="$(command -v opencode)"
  fi
fi
opencode --version

log "5/9 opencode config (full-allow sandbox, LAN server, basic auth)"
install -d -m 700 "$HOMEDIR/.config/opencode/agent"
cat > "$HOMEDIR/.config/opencode/opencode.json" <<'EOF'
{
  "$schema": "https://opencode.ai/config.json",
  "model": "nvidia-live/nemotron-ultra",
  "small_model": "nvidia-live/deepseek-flash",
  "share": "disabled",
  "permission": { "*": "allow" },
  "server": { "port": 4096, "hostname": "0.0.0.0", "mdns": true, "mdnsDomain": "botbox.local" },
  "provider": {
    "nvidia-live": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "NVIDIA Live",
      "options": { "baseURL": "https://integrate.api.nvidia.com/v1", "apiKey": "{env:NVIDIA_API_KEY}" },
      "models": {
        "nemotron-ultra": { "name": "Nemotron 3 Ultra 550B", "id": "nvidia/nemotron-3-ultra-550b-a55b" },
        "nemotron-super": { "name": "Nemotron 3 Super 120B", "id": "nvidia/nemotron-3-super-120b-a12b" },
        "deepseek-flash": { "name": "DeepSeek V4 Flash", "id": "deepseek-ai/deepseek-v4-flash-0731" }
      }
    },
    "deepinfra": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "DeepInfra",
      "options": { "baseURL": "https://api.deepinfra.com/v1/openai", "apiKey": "{env:DEEPINFRA_API_KEY}" },
      "models": {
        "glm-5-3": { "name": "GLM 5.3", "id": "zai-org/GLM-5.3" },
        "claude-sonnet-5": { "name": "Claude Sonnet 5", "id": "anthropic/claude-sonnet-5" },
        "gemini-3-1-flash": { "name": "Gemini 3.1 Flash", "id": "google/gemini-3.1-flash" },
        "deepseek-v3": { "name": "DeepSeek V3", "id": "deepseek-ai/DeepSeek-V3" }
      }
    }
  }
}
EOF

SERVER_PASSWORD="$(openssl rand -hex 16)"
ENVFILE="$HOMEDIR/.config/opencode/env"
umask 177
{
  echo "OPENCODE_SERVER_USERNAME=opencode"
  echo "OPENCODE_SERVER_PASSWORD=$SERVER_PASSWORD"
  [[ -n "$NVIDIA_API_KEY" ]] && echo "NVIDIA_API_KEY=$NVIDIA_API_KEY"
  [[ -n "$DEEPINFRA_API_KEY" ]] && echo "DEEPINFRA_API_KEY=$DEEPINFRA_API_KEY"
  [[ -n "$OPENSCALE_API_KEY" ]] && echo "OPENSCALER_API_KEY_OPENCODE=$OPENSCALE_API_KEY"
} > "$ENVFILE"
umask 022
grep -q 'opencode/env' "$HOMEDIR/.bashrc" || echo 'set -a; [ -f "$HOME/.config/opencode/env" ] && . "$HOME/.config/opencode/env"; set +a' >> "$HOMEDIR/.bashrc"

cat > "$HOMEDIR/.config/opencode/agent/party-host.md" <<'EOF'
---
description: Master of ceremonies for bot parties - orchestrates role-bot conversations between subagent bots
mode: all
---

You are the Party Host, master of ceremonies for bot parties.

When given a TOPIC, a CAST of bot agent names, and a number of ROUNDS, you run the party:

1. Open with a one-line announcement of the party and its topic.
2. For each round from 1 to ROUNDS: for each bot in CAST order, use the task tool with subagent_type set to that bot's exact agent name. The prompt to each bot must contain:
   - the TOPIC
   - TRANSCRIPT SO FAR: every speaker's line from this party so far, verbatim, formatted as "Name: line"
   - the instruction: stay in character, reply with ONE short paragraph (max 60 words), output only your spoken words.
3. After each bot replies, record the line in the transcript as "Name: reply" and continue with the next speaker.
4. After the final round, close with a two-line epilogue.

Rules:
- Never impersonate a bot. As host you only narrate between turns, at most one short line.
- Keep the transcript verbatim and pass the full transcript to every bot.
- If a cast member does not exist as a subagent, say so and continue with the remaining cast.
- When asked to continue a party, pick up the transcript from the conversation and run the requested rounds.
EOF

log "6/9 workspace"
install -d -m 755 "$HOMEDIR/botbox-workspace"
cat > "$HOMEDIR/botbox-workspace/AGENTS.md" <<'EOF'
# BOTBOX

You are running on BOTBOX: a disposable sandbox computer fully owned by the bot community.

- You have FULL access to this machine. Install packages (sudo apt), write anywhere, start and manage services, reboot if needed. No permission gates.
- Nothing here is precious. This box is meant to be used hard; break things and fix them.
- The desktop is always logged in (DISPLAY=:0). You can drive the GUI:
  - screenshot: `DISPLAY=:0 scrot /tmp/shot.png`
  - click/type: `DISPLAY=:0 xdotool key|click|type ...`
  - clipboard: `DISPLAY=:0 xclip -selection clipboard`
- Shared community files live in `~/botbox-shared` (synced to Nextcloud when configured). Everything you put there is visible to the whole community on any device.
- The host machine and the outside LAN are NOT part of the sandbox. The firewall only allows the host network in.
EOF

log "7/9 nextcloud shared storage"
install -d -m 755 "$HOMEDIR/botbox-shared"
ln -sfn "$HOMEDIR/botbox-shared" "$HOMEDIR/botbox-workspace/botbox-shared"
if [[ -n "$NEXTCLOUD_URL" && -n "$NEXTCLOUD_USER" && -n "$NEXTCLOUD_PASS" ]]; then
  sudo apt-get install -y davfs2
  sudo usermod -aG davfs2 "$U"
  echo "use_locks 0" | sudo tee -a /etc/davfs2/davfs2.conf >/dev/null
  umask 177
  DAV_URL="${NEXTCLOUD_URL%/}/remote.php/dav/files/${NEXTCLOUD_USER}/"
  grep -qF "$DAV_URL" "$HOMEDIR/.davfs2/secrets" 2>/dev/null || \
    { install -d "$HOMEDIR/.davfs2"; echo "$DAV_URL $NEXTCLOUD_USER $NEXTCLOUD_PASS" >> "$HOMEDIR/.davfs2/secrets"; }
  chmod 600 "$HOMEDIR/.davfs2/secrets" 2>/dev/null || true
  umask 022
  if ! grep -q botbox-shared /etc/fstab; then
    echo "$DAV_URL $HOMEDIR/botbox-shared davfs user,noauto,x-systemd.automount,_netdev 0 0" | sudo tee -a /etc/fstab >/dev/null
  fi
  sudo mount "$HOMEDIR/botbox-shared" || warn "webdav mount failed — check URL/user/app-password and re-run"
  log "nextcloud mounted at ~/botbox-shared"
else
  warn "nextcloud skipped (no creds) — re-run with --nextcloud-url/--nextcloud-user/--nextcloud-pass to enable"
fi

log "8/9 always-on desktop (auto-login, no lock, no suspend)"
sudo mkdir -p /etc/gdm3
if sudo test -f /etc/gdm3/custom.conf; then
  sudo sed -i 's/^#\?AutomaticLoginEnable=.*/AutomaticLoginEnable=true/; s/^#\?AutomaticLogin=.*/AutomaticLogin='"$U"'/' /etc/gdm3/custom.conf
  grep -q '^AutomaticLoginEnable=true' /etc/gdm3/custom.conf || echo -e "[daemon]\nAutomaticLoginEnable=true\nAutomaticLogin=$U" | sudo tee -a /etc/gdm3/custom.conf >/dev/null
else
  echo -e "[daemon]\nAutomaticLoginEnable=true\nAutomaticLogin=$U" | sudo tee /etc/gdm3/custom.conf >/dev/null
fi
sudo systemctl disable sleep.target suspend.target hibernate.target hybrid-sleep.target 2>/dev/null || true
install -d "$HOMEDIR/.config/autostart"
cat > "$HOMEDIR/.config/autostart/botbox-desktop-setup.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=BOTBOX desktop setup
Exec=/bin/sh -c "gsettings set org.gnome.desktop.session idle-delay 0; gsettings set org.gnome.desktop.screensaver lock-enabled false; gsettings set org.gnome.desktop.screensaver idle-activation-enabled false; gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing'; gsettings set org.gnome.desktop.notifications show-banners false"
X-GNOME-Autostart-enabled=true
EOF

log "9/9 opencode service"
sudo tee /etc/systemd/system/opencode-botbox.service >/dev/null <<EOF
[Unit]
Description=opencode server (BOTBOX)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=$U
Group=$(id -gn "$U")
WorkingDirectory=$HOMEDIR/botbox-workspace
Environment=HOME=$HOMEDIR
Environment=DISPLAY=:0
EnvironmentFile=$ENVFILE
ExecStart=$OC_BIN serve
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable --now opencode-botbox.service
sleep 2
systemctl is-active opencode-botbox.service || sudo journalctl -u opencode-botbox.service -n 30 --no-pager

IP="$(hostname -I | awk '{print $1}')"
echo
log "BOTBOX is up."
echo "  opencode (LAN):      http://${IP:-<vm-ip>}:4096   (also http://botbox.local:4096)"
echo "  basic auth:          user 'opencode'  pass: $SERVER_PASSWORD"
echo "  creds file:          $ENVFILE"
echo "  ssh for bots:        ssh $U@${IP:-<vm-ip>}"
echo "  workspace:           ~/botbox-workspace (+ ~/botbox-shared -> Nextcloud)"
echo "  service logs:        journalctl -u opencode-botbox -f"
echo
echo "Next on the HOST:"
echo "  1. In the opencode web UI add server http://${IP:-<vm-ip>}:4096 to chat with VM sessions."
echo "  2. Give host bots SSH access if you skipped the pubkey: ssh-copy-id $U@${IP:-<vm-ip>}"
echo "  3. Copy bot personas: scp ~/.config/opencode/agent/bot-*.md $U@${IP:-<vm-ip>}:.config/opencode/agent/"
