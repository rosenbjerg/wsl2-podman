# WSL2 podman/docker install script
Script for installing WSL2 + `podman` and `podman-compose` (or `docker` and `docker-compose`), and adding Windows "aliases" for convenience


## Installation
- [Download](https://github.com/rosenbjerg/wsl2-podman/archive/refs/heads/main.zip) and extract the `.bat` and `.ps1` files into same folder and run the `.bat` script (will prompt for admin rights)
- Switch from `localhost` to `::1` or `wsl` if you experience problems connecting to a container from some application on the host


## Improvements and other suggestions
Please create issues for improvements or suggestions to the script


## Known problems

### Running the installer
If you experience problems starting the installer using the `.bat` script, it may be because the `.ps1` file is blocked in Windows. 

Right-click on the `.ps1` file and select Properties. Then in the General tab, you will see the option to unblock it. 
After unblocking, you should be able to start the install script.

If that doesn't solve it, you may need to move the two files to another directory, possibly due OneDrive synchronization of the current folder.
Moving the two files to the root of `C:\` should resolve the issue.

### Absolute paths
One problem with this docker-desktop alternative is that you cannot use absolute paths for mounting.
Instead you will have to either use relative paths or rewrite `C:\` to `/mnt/c/` and use forward slashes

### Connecting to containers using `localhost`
Some applications automatically resolve localhost to `127.0.0.1` (IPv4) which Windows doesn't forward to WSL2, without checking the Windows `hosts` file.
This means you may experience problems connecting to the containers running in WSL2, if using `localhost`. 

If you do experience this, try changing `localhost`/`127.0.0.1` to `::1` (for TCP connections and `[::1]` for HTTP) or to `wsl`

### Missing internet connectivity when using Cisco AnyConnect on Windows host
Connecting or disconnecting the AnyConnect client can cause internet connectivity problems in WSL2. Running the following powershell command with elevated rights fixes this:
```powershell
Get-NetAdapter | Where-Object {$_.InterfaceDescription -Match 'Cisco AnyConnect'} | Set-NetIPInterface -ErrorAction SilentlyContinue -InterfaceMetric 6000 | Out-Null
```
