# Podman in WSL 2

> Note: For Podman on Windows, see the [1st-party installation guide][podman-for-windows].

[![License][license-shield]][LICENSE]

## Getting Started

### Prerequisites

- [PowerShell Core][get-powershell]
- [Windows Subsystem for Linux (WSL)][install-wsl]

### Usage

1. [Clone or download][clone-repository] this repository
2. In an Administrator prompt, run the [`Install-ContainerRuntime.ps1`][Install-ContainerRuntime.ps1] script

```powershell
# Defaults to podman, add -Docker to install docker-ce instead
.\scripts\Install-ContainerRuntime.ps1
```

### Known Issues

#### Absolute paths

By default, the shims created by the installation scripts do not support absolute paths for mounting.
Instead you will have to either use relative paths or rewrite `C:\` to `/mnt/c/` and use forward slashes.

Alternatively, consider installing the [`WslInterop` module][wsl-interop] for easier access from PowerShell.

#### Connecting to containers using `localhost`

Some applications automatically resolve `localhost` to `127.0.0.1` (IPv4), which Windows doesn't forward to WSL, without checking the Windows `hosts` file.
This means you may experience problems connecting to the containers running in WSL when using `localhost`.

If you do experience this, try swapping `localhost`/`127.0.0.1` for `::1` (TCP), `[::1]` (HTTP), or simply `wsl`.

#### No internet connectivity when using a VPN

Refer to the [WSL troubleshooting page][vpn-troubleshooting].

## Contributing

If you have a suggestion that would make this better, please fork the repo and create a pull request.
You can also simply open an issue.

## License

[GPL][LICENSE]

<!-- LINKS & IMAGES -->
[podman-for-windows]: https://github.com/containers/podman/blob/95eff1aa402c3d159c8ad25d8140b879d5feccf2/docs/tutorials/podman-for-windows.md
[license-shield]: https://img.shields.io/github/license/rosenbjerg/wsl2-podman?style=flat-square
[LICENSE]: LICENSE
[get-powershell]:https://github.com/powershell/powershell#get-powershell
[install-wsl]: https://docs.microsoft.com/en-us/windows/wsl/install
[clone-repository]: https://docs.github.com/en/repositories/creating-and-managing-repositories/cloning-a-repository
[Install-ContainerRuntime.ps1]: scripts/Install-ContainerRuntime.ps1
[wsl-interop]: https://github.com/mikebattista/PowerShell-WSL-Interop
[vpn-troubleshooting]: https://docs.microsoft.com/en-us/windows/wsl/troubleshooting#wsl-has-no-network-connectivity-once-connected-to-a-vpn
