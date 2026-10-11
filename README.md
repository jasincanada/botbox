# BOTBOX — the bots' own computer

A disposable Ubuntu Desktop 24.04 LTS sandbox VM (Hyper-V) that a bot community fully owns:
SSH with full sudo, an always-on auto-login desktop (screenshots, GUI automation), its own opencode
server on the LAN with basic auth, and the community's Nextcloud mounted as the shared filesystem.

## What the bootstrap installs

- SSH (key-only, root login off) + the host's pubkey so host-side bots can `ssh botbox@<vm-ip>`
- ufw firewall: ports 22 + 4096 allowed from the LAN only
- opencode (official installer, npm fallback) + a full-allow sandbox config:
  - `permission: {"*": "allow"}` — this box exists to be owned by bots
  - server on 0.0.0.0:4096 with mDNS (`botbox.local`) and basic auth
  - providers: nvidia-live + deepinfra via `{env:...}` keys (prompted, stored in `~/.config/opencode/env`, mode 600)
- `party-host` agent + `~/botbox-workspace/AGENTS.md` (BOTBOX rules for the bots)
- Optional Nextcloud WebDAV mount at `~/botbox-shared` (`davfs2`, app-user + app-password prompted)
- Always-on desktop: gdm auto-login, no lock screen, no suspend, GUI automation tools (`scrot`, `xdotool`, `xclip`)
- systemd service `opencode-botbox` (auto-restart on boot)

## Usage

On the Hyper-V host (elevated PowerShell):

    .\create-vm.ps1 -IsoPath "C:\ISO\ubuntu-24.04.3-desktop-amd64.iso"

Boot the VM, install Ubuntu Desktop 24.04 LTS, open a terminal in the VM, then run:

    curl -fsSL https://raw.githubusercontent.com/jasincanada/botbox/main/bootstrap.sh | bash -s -- \
      --ssh-pubkey "ssh-ed25519 AAAA... host@5900X" \
      --nvidia-key "nvapi-..." \
      --nextcloud-url "https://cloud.cryptocomputer.ca" \
      --nextcloud-user botbox --nextcloud-pass "<app-password>"

Reboot once. Done.

## Fully unattended (optional)

Skip the manual install entirely with an autoinstall seed. Secrets stay local — the seed VHD is
built on your machine and never committed:

    # elevated PowerShell on the Hyper-V host:
    copy seed-values.example.ps1 seed-values.ps1
    notepad seed-values.ps1        # fill every FILL_ME (or leave optional fields empty to skip)
    .\make-seed.ps1               # reads seed-values.ps1; validates; prints one-time console password

    .\create-vm.ps1 -IsoPath "C:\ISO\ubuntu-24.04.5.1-desktop-amd64.iso" -SeedVhdx "C:\HyperV\BOTBOX-seed.vhdx"
    Start-VM -Name BOTBOX

- Ubuntu installs itself (~15-30 min), reboots, and cloud-init pulls the bootstrap from this repo
  on first boot — the VM lands fully provisioned with zero interaction.
- `seed-values.ps1` is git-ignored: your keys never leave the machine. `make-seed.ps1` refuses to
  run if any field still says `FILL_ME`, and tells you exactly which one.
- The Nextcloud section explains where the app password comes from (botbox user → Security →
  Devices & sessions → Create new app password). Leave all three Nextcloud fields empty to skip.
- The seed VHD contains your keys — delete it after installation (`Remove-Item C:\HyperV\BOTBOX-seed.vhdx`).
- If the installer ever opens interactively (seed not detected), that's fine: install manually and
  use the curl one-liner above instead.

## Wiring it into the hub ecosystem

1. opencode web UI (host): add `http://<vm-ip>:4096` as a second server — VM sessions are fully chat-capable there.
2. Host bots get computer access: any host-side session can `ssh botbox@<vm-ip>` and drive the VM.
3. Copy additional personas from the Hub's Bots page onto the VM:
   `scp ~/.config/opencode/agent/bot-*.md botbox@<vm-ip>:.config/opencode/agent/`
4. Files dropped into Nextcloud (local or cloud.cryptocomputer.ca) appear at `~/botbox-shared` for every bot.

## Security posture

- Firewall: LAN-only ingress on 22/4096. Basic auth on the opencode server (credentials in `~/.config/opencode/env`).
- SSH: pubkey-only. The initial VM user has full sudo — that is the point of a sandbox the bots own.
- No secrets in this repo: every credential is prompted at runtime and written with mode 600.
- The sandbox is disposable: snapshot with `Checkpoint-VM`, reset by checkpoint revert.

## Roadmap hooks

- Hub history/RAG currently indexes the host's opencode.db; VM session indexing lands with the
  Postgres+pgvector migration (Phase 2), which also unlocks central bot-community lore.
- Nextcloud MCP (`nc_*` tools, 179 endpoints, mcp.cryptocomputer.ca) can be attached to the VM's
  opencode config later for native notes/files tooling.
