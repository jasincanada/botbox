#!/usr/bin/env bash
# BOTBOX remote control setup — run INSIDE a freshly installed botbox VM,
# as the initial desktop user (NOT root):
#
#   curl -fsSL https://raw.githubusercontent.com/jasincanada/botbox/main/remote-setup.sh | bash
#
# Fetches the host 5900X SSH public key from this repo and runs bootstrap.sh with
# it, so the host (and its opencode/bots) can `ssh botbox@<vm-ip>` and control the
# VM. Any extra args are forwarded to bootstrap.sh, e.g.:
#
#   curl -fsSL <RAW>/remote-setup.sh | bash -s -- --with-docker
#
set -euo pipefail

RAW="${BOTBOX_RAW:-https://raw.githubusercontent.com/jasincanada/botbox/main}"

KEY="$(curl -fsSL "$RAW/hosts/5900x.pub")"
if [[ "$KEY" != ssh-* ]]; then
  echo "[remote-setup] could not fetch the host public key from $RAW/hosts/5900x.pub" >&2
  exit 1
fi

echo "[remote-setup] installing host key: ${KEY%% *} ... (${KEY##* })"
# bootstrap.sh is non-interactive when its stdin is a pipe; --ssh-pubkey supplies the key.
curl -fsSL "$RAW/bootstrap.sh" | bash -s -- --ssh-pubkey "$KEY" "$@"
