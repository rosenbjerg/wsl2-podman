# wsl2-podman
Script for installing WSL2 + podman and podman-compose and adding Windows "aliases"

## TLDR
Download .bat and .ps1 scripts into same folder and run the .bat script. Then replace `localhost` with `local` or `wsl` (added to `hosts` file by this script)


## Installation
Just download both the bat and ps1 files into the same directory, and run the bat script


## Improvements and other suggestions
Please create issues for improvements or suggestions to the script


## Known problems

### Absolute paths
One problem with this docker-desktop alternate, is that you cannot use absolute paths for mounting.
Instead you will have to either use relative paths or rewrite `C:\` to `/mnt/c/` and use forward slashes

### Problem with resolving localhost in some applications
Many applications automatically resolve localhost to 127.0.0.1 (IPv4), which Windows doesn't forward to WSL2, without checking the Windows `hosts` file.
You may experience problems connecting to the containers running in podman from such applcations.
To solve this problem

