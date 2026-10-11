# BOTBOX VM creator — run in an elevated PowerShell on the Hyper-V host (5900X).
# Creates a Gen2 VM ready for Ubuntu Desktop 24.04 LTS installation.
# Usage:
#   .\create-vm.ps1 -IsoPath "C:\ISO\ubuntu-24.04.3-desktop-amd64.iso"
#   .\create-vm.ps1 -IsoPath "...iso" -Name BOTBOX -MemoryGB 8 -DiskGB 80 -SwitchName "Default Switch"
param(
  [Parameter(Mandatory = $true)][string]$IsoPath,
  [string]$Name = "BOTBOX",
  [int]$MemoryGB = 8,
  [int]$DiskGB = 80,
  [string]$SwitchName = "Default Switch",
  [string]$VmDir = "C:\HyperV\$Name"
)

if (-not (Test-Path $IsoPath)) { throw "ISO not found: $IsoPath" }
if (-not (Get-VMSwitch -Name $SwitchName -ErrorAction SilentlyContinue)) { throw "Switch not found: $SwitchName" }

if (Get-VM -Name $Name -ErrorAction SilentlyContinue) { throw "VM $Name already exists" }
New-Item -ItemType Directory -Force -Path $VmDir | Out-Null

New-VM -Name $Name -Generation 2 -MemoryStartupBytes ($MemoryGB * 1GB) `
  -VHDPath "$VmDir\$Name.vhdx" -NewVHDPathBytes 0 -SwitchName $SwitchName | Out-Null
Set-VM -Name $Name -ProcessorCount 4 -DynamicMemory -MemoryMinimumBytes 2GB -MemoryMaximumBytes ($MemoryGB * 1GB)
Set-VHD -Path "$VmDir\$Name.vhdx" -SizeBytes ($DiskGB * 1GB)
Add-VMDvdDrive -VMName $Name -Path $IsoPath
Set-VMFirmware -VMName $Name -EnableSecureBoot On -SecureBootTemplate "MicrosoftUEFICertificateAuthority" -FirstBootDevice (Get-VMDvdDrive -VMName $Name)
Get-VMIntegrationService -VMName $Name | Enable-VMIntegrationService -ErrorAction SilentlyContinue | Out-Null

Write-Host "VM '$Name' created." -ForegroundColor Green
Write-Host "Next:"
Write-Host "  1. Start-VM -Name $Name ; connect with vmconnect.exe `"$Name`""
Write-Host "  2. Install Ubuntu Desktop 24.04 LTS (user: pick a name you like, e.g. 'botbox'; passwordless sudo is configured by bootstrap)"
Write-Host "  3. In the VM terminal run the BOTBOX bootstrap (see botbox/README.md), then reboot once"
Write-Host "Optional snapshot before first boot:"
Write-Host "  Checkpoint-VM -Name $Name -SnapshotName 'fresh-install'"
