# ============================================================================
#  BOTBOX SEED VALUES — copy this file to seed-values.ps1 and fill it in
# ============================================================================
#   copy seed-values.example.ps1 seed-values.ps1
#   notepad seed-values.ps1
#
#  seed-values.ps1 contains your secrets. It is git-ignored. NEVER commit it.
#  Leave a field EMPTY to skip that feature. If a field still says FILL_ME,
#  make-seed.ps1 will refuse to run and tell you which one.
# ============================================================================

# --- REQUIRED ---------------------------------------------------------------
# SSH public key of the HOST machine (5900X) — this is what lets host-side
# bots SSH into BOTBOX. Either a path to your .pub file...
$SshPubKey = "$env:USERPROFILE\.ssh\id_ed25519.pub"
# ...or paste the key itself, like: "ssh-ed25519 AAAAC3Nza... host@5900X"

# --- MODEL API KEYS (optional — leave empty to skip a provider) --------------
# NVIDIA Live key — starts with "nvapi-"
$NvidiaKey = "FILL_ME"

# DeepInfra key — long hex string
$DeepinfraKey = "FILL_ME"

# OpenScale key — rarely used, leave empty to skip
$OpenscaleKey = ""

# --- NEXTCLOUD SHARED STORAGE (optional — leave ALL THREE empty to skip) ----
# Where the app password comes from:
#   1. In Nextcloud, as admin:  Administration settings -> Users -> create user "botbox"
#   2. Log in AS botbox:       avatar -> Personal settings -> Security
#                              -> Devices & sessions -> "Create new app password"
#   3. Paste THAT app password below (NOT a login password)
$NextcloudUrl = "https://cloud.cryptocomputer.ca"   # your Nextcloud, public or local
$NextcloudUser = "botbox"
$NextcloudPass = "FILL_ME"                          # the app password, e.g. "AbC123-xYz789-..."

# --- VM identity (defaults are fine) -----------------------------------------
$VmUser = "botbox"                    # username inside the VM
$VmHost = "botbox"                    # hostname / mDNS name (botbox.local)
$SeedVhdx = "C:\HyperV\BOTBOX-seed.vhdx"  # where the seed VHD gets written
