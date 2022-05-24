Get-NetAdapter | Where-Object {$_.InterfaceDescription -Match 'Cisco AnyConnect'} | Set-NetIPInterface -ErrorAction SilentlyContinue -InterfaceMetric 6000 | Out-Null