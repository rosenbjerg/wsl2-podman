# WSL2 podman/docker install script
Script for installing WSL2 + `podman` and `podman-compose` (or `docker` and `docker-compose`), and adding Windows "aliases" for convenience


## Installation
- Download `.bat` and `.ps1` scripts into same folder and run the `.bat` script (will prompt for admin rights)
- Switch from `localhost` to `::1` or `wsl` if you experience problems connecting to a container from some application on the host


## Improvements and other suggestions
Please create issues for improvements or suggestions to the script


## Known problems

### Absolute paths
One problem with this docker-desktop alternative is that you cannot use absolute paths for mounting.
Instead you will have to either use relative paths or rewrite `C:\` to `/mnt/c/` and use forward slashes

### Connecting to containers using `localhost`
Some applications automatically resolve localhost to `127.0.0.1` (IPv4) which Windows doesn't forward to WSL2, without checking the Windows `hosts` file.
This means you may experience problems connecting to the containers running in WSL2, if using `localhost`. 

If you do, try changing from `localhost`/`127.0.0.1` to `::1` or `wsl` for TCP connections (`[::1]` when used with HTTP)
