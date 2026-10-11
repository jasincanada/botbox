# BOTBOX seed generator — builds a CIDATA (autoinstall + cloud-init) seed VHD for fully
# unattended Ubuntu Desktop installation + first-boot provisioning via the public bootstrap.
#
# USAGE (recommended — fill in the blanks):
#   copy seed-values.example.ps1 seed-values.ps1
#   notepad seed-values.ps1          # fill every FILL_ME
#   .\make-seed.ps1
#
# Or pass values directly on the command line (they override seed-values.ps1):
#   .\make-seed.ps1 -SshPubKey "$env:USERPROFILE\.ssh\id_ed25519.pub" -NvidiaKey "nvapi-..."
#
# Run in an elevated PowerShell. All secrets stay LOCAL (seed VHD is never committed).
param(
  [string]$SshPubKey = "",
  [string]$NvidiaKey = "",
  [string]$DeepinfraKey = "",
  [string]$OpenscaleKey = "",
  [string]$NextcloudUrl = "",
  [string]$NextcloudUser = "",
  [string]$NextcloudPass = "",
  [string]$SeedVhdx = "",
  [string]$VmUser = "",
  [string]$VmHost = "",
  [string]$ValuesFile = ""
)

if (-not (Get-Command New-VHD -ErrorAction SilentlyContinue)) { throw "Hyper-V module not available (run elevated on the host)" }

$defaults = @{}
if (-not $ValuesFile) { $ValuesFile = Join-Path $PSScriptRoot "seed-values.ps1" }
if (Test-Path $ValuesFile) {
  $vars = & { . $ValuesFile; Get-Variable -Name SshPubKey,NvidiaKey,DeepinfraKey,OpenscaleKey,NextcloudUrl,NextcloudUser,NextcloudPass,SeedVhdx,VmUser,VmHost -ErrorAction SilentlyContinue }
  foreach ($v in $vars) { $defaults[$v.Name] = "$($v.Value)".Trim() }
} elseif ($ValuesFile -eq (Join-Path $PSScriptRoot "seed-values.ps1")) {
  Write-Host "note: no seed-values.ps1 found — relying on command-line parameters only." -ForegroundColor DarkYellow
}

function Pick([string]$Name, [string]$Fallback) {
  if ($PSBoundParameters.ContainsKey($Name)) { return "$($PSBoundParameters[$Name])".Trim() }
  if ($defaults.ContainsKey($Name) -and $defaults[$Name]) { return $defaults[$Name] }
  return "$Fallback".Trim()
}
$SshPubKey = Pick 'SshPubKey' $SshPubKey
$NvidiaKey = Pick 'NvidiaKey' $NvidiaKey
$DeepinfraKey = Pick 'DeepinfraKey' $DeepinfraKey
$OpenscaleKey = Pick 'OpenscaleKey' $OpenscaleKey
$NextcloudUrl = Pick 'NextcloudUrl' $NextcloudUrl
$NextcloudUser = Pick 'NextcloudUser' $NextcloudUser
$NextcloudPass = Pick 'NextcloudPass' $NextcloudPass
$SeedVhdx = Pick 'SeedVhdx' $SeedVhdx
if (-not $SeedVhdx) { $SeedVhdx = "C:\HyperV\BOTBOX-seed.vhdx" }
$VmUser = Pick 'VmUser' $VmUser
if (-not $VmUser) { $VmUser = "botbox" }
$VmHost = Pick 'VmHost' $VmHost
if (-not $VmHost) { $VmHost = "botbox" }

$unfilled = @()
foreach ($pair in @(
    @{ n = '$SshPubKey';    v = $SshPubKey },
    @{ n = '$NvidiaKey';    v = $NvidiaKey },
    @{ n = '$DeepinfraKey'; v = $DeepinfraKey },
    @{ n = '$OpenscaleKey'; v = $OpenscaleKey },
    @{ n = '$NextcloudUrl'; v = $NextcloudUrl },
    @{ n = '$NextcloudUser'; v = $NextcloudUser },
    @{ n = '$NextcloudPass'; v = $NextcloudPass }
  )) {
  if ("$($pair.v)" -match '^FILL_ME') { $unfilled += $pair.n }
}
if ($unfilled) {
  throw ("These fields in seed-values.ps1 still say FILL_ME (fill them in, or leave them EMPTY to skip): " + ($unfilled -join ', '))
}

if (-not $SshPubKey) {
  throw "SshPubKey is required: set `$SshPubKey in seed-values.ps1 to a path like `"$env:USERPROFILE\.ssh\id_ed25519.pub`" or paste the key itself."
}

$ncSet = @($NextcloudUrl, $NextcloudUser, $NextcloudPass) | Where-Object { $_ }
if ($ncSet.Count -gt 0 -and $ncSet.Count -lt 3) {
  throw "Nextcloud is partially configured: you must set ALL THREE of `$NextcloudUrl, `$NextcloudUser, `$NextcloudPass — or clear ALL THREE to skip Nextcloud."
}

if (Test-Path $SshPubKey) { $pub = (Get-Content $SshPubKey -Raw).Trim() } else { $pub = $SshPubKey.Trim() }
if ($pub -notmatch '^ssh-') { throw "-SshPubKey must be a public key string or a path to a .pub file (got: $($pub.Substring(0, [Math]::Min(40, $pub.Length))...)" }

$openssl = "C:\Program Files\Git\usr\bin\openssl.exe"
if (-not (Test-Path $openssl)) { $openssl = (Get-Command openssl -ErrorAction SilentlyContinue).Source }
if (-not $openssl) { throw "openssl not found (Git for Windows provides one). Install Git or add openssl to PATH." }

$bytes = New-Object byte[] 12
[System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
$plainPassword = [Convert]::ToBase64String($bytes)
$hash = & $openssl passwd -6 $plainPassword
if (-not $hash -match '^\$6\$') { throw "password hashing failed" }

$bootstrapArgs = ""
if ($NvidiaKey)     { $bootstrapArgs += " --nvidia-key '$NvidiaKey'" }
if ($DeepinfraKey)  { $bootstrapArgs += " --deepinfra-key '$DeepinfraKey'" }
if ($OpenscaleKey)  { $bootstrapArgs += " --openscale-key '$OpenscaleKey'" }
if ($NextcloudUrl)  { $bootstrapArgs += " --nextcloud-url '$NextcloudUrl' --nextcloud-user '$NextcloudUser' --nextcloud-pass '$NextcloudPass'" }

$launch = @"
#!/bin/bash
set -e
curl -fsSL https://raw.githubusercontent.com/jasincanada/botbox/main/bootstrap.sh | bash -s --$bootstrapArgs
"@

$userData = @"
#cloud-config
hostname: $VmHost
ssh_authorized_keys:
  - '$pub'
autoinstall:
  version: 1
  locale: en_US.UTF-8
  keyboard:
    layout: us
  identity:
    realname: BOTBOX
    username: $VmUser
    hostname: $VmHost
    password: "$hash"
  storage:
    layout:
      name: direct
  packages:
    - openssh-server
  shutdown: reboot
  late-commands:
    - curtin in-target -- bash -c 'mkdir -p /etc/sudoers.d; echo "$VmUser ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90-botbox; chmod 440 /etc/sudoers.d/90-botbox'
write_files:
  - path: /home/$VmUser/botbox-launch.sh
    owner: ${VmUser}:${VmUser}
    permissions: '0755'
    content: |
$($launch -split "`n" | ForEach-Object { "      $_" }) | Out-String
runcmd:
  - [ su, -l, $VmUser, -c, /home/$VmUser/botbox-launch.sh ]
"@

$metaData = "instance-id: botbox-001`nlocal-hostname: $VmHost`n"

$dir = Join-Path $env:TEMP "botbox-seed-$(Get-Random)"
New-Item -ItemType Directory -Force -Path $dir | Out-Null
try {
  [System.IO.File]::WriteAllText((Join-Path $dir "user-data"), $userData)
  [System.IO.File]::WriteAllText((Join-Path $dir "meta-data"), $metaData)

  if (Test-Path $SeedVhdx) { Remove-Item $SeedVhdx -Force }
  $seedDir = Split-Path $SeedVhdx -Parent
  New-Item -ItemType Directory -Force -Path $seedDir | Out-Null
  New-VHD -Path $SeedVhdx -SizeBytes 32MB -Fixed | Out-Null

  Mount-VHD -Path $SeedVhdx
  $disk = Get-VHD -Path $SeedVhdx | Get-Disk
  $disk | Initialize-Disk -PartitionStyle GPT | Out-Null
  $part = New-Partition -DiskNumber $disk.Number -UseMaximumSize -AssignDriveLetter
  Format-Volume -Partition $part -FileSystem FAT32 -NewFileSystemLabel "CIDATA" -Force | Out-Null
  Copy-Item "$dir\*" "$($part.DriveLetter):\" -Force
  Dismount-VHD -Path $SeedVhdx

  Write-Host ""
  Write-Host "Seed VHD created: $SeedVhdx" -ForegroundColor Green
  $enabled = @()
  if ($NvidiaKey) { $enabled += "nvidia-live" }
  if ($DeepinfraKey) { $enabled += "deepinfra" }
  if ($OpenscaleKey) { $enabled += "openscale" }
  if ($NextcloudUrl) { $enabled += "nextcloud($NextcloudUrl)" }
  Write-Host " enabled: $($enabled -join ', ')"
  Write-Host ""
  Write-Host "Attach with:  .\create-vm.ps1 -IsoPath <ubuntu-24.04-desktop.iso> -SeedVhdx `"$SeedVhdx`""
  Write-Host ""
  Write-Host "Console login (fallback only — SSH key + auto-login are configured):" -ForegroundColor Yellow
  Write-Host "  user: $VmUser   password: $plainPassword"
  Write-Host "The password is stored only as a hash inside the seed. Delete the seed VHD after installation."
}
finally {
  Remove-Item $dir -Recurse -Force -ErrorAction SilentlyContinue
}
