#Requires -Version 7

<#
.SYNOPSIS
  Installs Podman or Docker into an existing WSL Ubuntu distro.

.PARAMETER Docker
  When true, docker-ce will be installed instead of podman.

.NOTES
  This script expects Ubuntu to be installed in WSL.
#>

using namespace System.Management.Automation
using namespace System.IO

[CmdletBinding()]
param (
  [switch]
  $Docker
)

$InformationPreference = [ActionPreference]::Continue

$PSDefaultParameterValues = @{
  "Select-String:SimpleMatch" = $true;
  "Select-String:Quiet"       = $true;
}

$runtime = if ($Docker) { "docker" } else { "podman" }

if (-not  (wsl --list | Select-String "Ubuntu")) {
  throw "Failed to detect Ubuntu installation in WSL"
}

Write-Information "Running shell script"

$runtimeInstallScriptPath = [Path]::Join($PSScriptRoot, "install-container-runtime.sh")

wsl -d Ubuntu bash ($runtimeInstallScriptPath -replace "C:", "/mnt/c" -replace "\\", "/") $runtime

Write-Information "Creating shims"

$localBin = [Path]::Join($Env:USERPROFILE, ".local", "bin")

[Directory]::CreateDirectory($localBin) | Out-Null

$userPath = $Env:PATH -split ";" | Where-Object { $_.StartsWith($Env:USERPROFILE) }

if (-not $userPath -contains $localBin) {
  Write-Information "Adding $localBin to PATH"
  $userPath = @($localBin) + $userPath
  [Environment]::SetEnvironmentVariable("Path", ($userPath -join ";"), [EnvironmentVariableTarget]::User)
}

$shims = ("docker", "docker-compose", $runtime, "$runtime-compose") | Select-Object -Unique

$shims.ForEach({
    [File]::WriteAllText("$localBin\$_.ps1", "wsl -d Ubuntu $_ @Args")
  })

$hostsPath = [Path]::Join($Env:SYSTEMROOT, "System32", "drivers", "etc", "hosts")

$targetHostsEntries = (
  "0:0:0:0:0:0:0:1 wsl",
  "0:0:0:0:0:0:0:1 $runtime"
)

$targetHostsEntries.ForEach({
    if (-not (Select-String -Path $hostsPath $_)) {
      Write-Information "Adding '$_' to hosts file"
      [File]::AppendAllText($hostsPath, "`r`n$_")
    }
  })


if ($Docker) {
  Write-Information "Restarting WSL"
  wsl --shutdown
  wsl -d Ubuntu :
}

Write-Host -ForegroundColor Green "`nInstall successful! Try running $runtime or $runtime-compose`n"
Write-Host -ForegroundColor Yellow "Press any key to exit"
Read-Host
