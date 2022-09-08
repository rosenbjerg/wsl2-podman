<#
.SYNOPSIS
  Restores connectivity for WSL in the event that it is disrupted by the AnyConnect client.
#>

Get-NetAdapter `
| Where-Object InterfaceDescription -Like "Cisco AnyConnect" `
| Set-NetIPInterface -ErrorAction SilentlyContinue -InterfaceMetric 6000 `
| Out-Null
