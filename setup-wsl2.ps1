# Install script for WSL2 + podman and podman-compose
# Author: Malte Rosenbjerg


# Enable required Windows features
$host.ui.RawUI.WindowTitle = "Installing WSL2 + podman"
Write-Host "Enabling Windows feature: Microsoft-Windows-Subsystem-Linux .."
& dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart | Out-Null

Write-Host "Enabling Windows feature: VirtualMachinePlatform .."
& dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart | Out-Null
Write-Host ""


# Install WSL2 kernel update
Write-Host "Downloading WSL2 kernel update for Windows .."
$Wsl2KernelUpdatePath = "C:\Users\Public\Downloads\wsl_update_x64.msi"
$ProgressPreference = 'SilentlyContinue'  
Invoke-WebRequest -Uri "https://wslstorestorage.blob.core.windows.net/wslblob/wsl_update_x64.msi" -OutFile $Wsl2KernelUpdatePath -UseBasicParsing
$ProgressPreference = 'Continue'
Write-Host "Installing WSL2 kernel update for Windows .."
& msiexec.exe /I $($Wsl2KernelUpdatePath) /qn
Start-Sleep -s 1 # wait for msiexec to release file
Remove-Item $Wsl2KernelUpdatePath
Write-Host ""


# Set default WSL version for distros
Write-Host "Setting default WSL version to 2 .."
& wsl.exe --set-default-version 2 | Out-Null


# Stop and migrate Ubuntu distro if needed
$wslDistros = (& wsl.exe -l -v) -join "" -replace "\u0000",""
if ($wslDistros -match 'Ubuntu\s+[^\s]+\s+1')
{
    if ($wslDistros -match 'Ubuntu\s+Running\s+1')
    {
        Write-Host "The current Ubuntu distro needs to be stopped before being migrated to WSL2. Press enter to continue"
        Read-Host
        & wsl.exe --shutdown | Out-Null
    }
    
    Write-Host "The will now be migrated to WSL2. Press enter to continue"
    Read-Host
    Write-Host "Migrating Ubuntu distro to WSL2 .. "
    & wsl.exe --set-version Ubuntu 2 | Out-Null
}
elseif (!($wslDistros -match 'Ubuntu\s+[^\s]+\s+[12]'))
{
    Write-Host "Ubuntu distro was not found and will now be installed. Press enter to continue .."
    Read-Host

    Write-Host "Downloading Ubuntu WSL2 image .."
    $WslUbuntu = "C:\Users\Public\Downloads\Ubuntu.appx"
    $ProgressPreference = 'SilentlyContinue'  
    Invoke-WebRequest -Uri https://aka.ms/wslubuntu2004 -OutFile "$WslUbuntu" -UseBasicParsing
    $ProgressPreference = 'Continue'
    Write-Host "Installing Ubuntu WSL2 image .."
    Add-AppxPackage "$WslUbuntu" | Out-Null
    Remove-Item "$WslUbuntu" | Out-Null
}


# Print distro info
Write-Host "Distro info:"
& ubuntu run uname -a
Write-Host ""


# podman or docker?
$runtime = ''
while ($runtime -ne 'podman' -And $runtime -ne 'docker') {
    Write-Host 'podman or docker?'
    $runtime = Read-Host
}

Write-Host "$runtime it is!"
Write-Host ""


# Create runtime install script
$runtimeInstallScript = ''
if ($runtime -eq 'podman') 
{   # podman install script
    Write-Host "Installing podman and podman-compose in Ubuntu distro .."
    $runtimeInstallScript = @"
podman -v > /dev/null 2>&1 && podman-compose -v > /dev/null 2>&1 && echo "- podman and podman-compose are already installed" && exit 0;

echo "- Adding kubic podman source and key .."
. /etc/os-release
sudo sh -c "printf 'deb http://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/x`${NAME}_`${VERSION_ID}/ /' > /etc/apt/sources.list.d/devel:kubic:libcontainers:stable.list"
wget -q -nv https://download.opensuse.org/repositories/devel:kubic:libcontainers:stable/x`${NAME}_`${VERSION_ID}/Release.key -O ~/Release.key
sudo apt-key add - < ~/Release.key
sudo rm ~/Release.key

echo "- Installing podman .."
sudo apt-get -qq -o=Dpkg::Use-Pty=0 update
sudo apt-get -qq -o=Dpkg::Use-Pty=0 -y install podman

echo "- Installing pip3 .."
sudo apt-get -qq -o=Dpkg::Use-Pty=0 update
sudo apt-get -qq -o=Dpkg::Use-Pty=0 -y install python3-pip

echo "- Installing podman-compose through pip3 .."
sudo pip3 install podman-compose -q

echo "- Adding aliases for docker and docker-compose in .profile .."
grep -Fxq 'alias docker=podman' ~/.profile || printf "\nalias docker=podman" >> ~/.profile
grep -Fxq 'alias docker-compose=podman-compose' ~/.profile || printf "\nalias docker-compose=podman-compose" >> ~/.profile
"@ -replace '"',"`"" -replace "`r",""
}
elseif ($runtime -eq 'docker')
{   # docker install script
    Write-Host "Installing docker and docker-compose in Ubuntu distro .."
    $runtimeInstallScript = @"
docker -v > /dev/null 2>&1 && docker-compose -v > /dev/null 2>&1 && echo "- docker and docker-compose are already installed" && exit 0;

echo "- Adding docker source .."
sudo groupadd docker > /dev/null
sudo usermod -aG docker `${USER}
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu `$(lsb_release -cs) stable" > /dev/null
sudo apt-get -qq -o=Dpkg::Use-Pty=0 update

echo "- Installing docker .."
sudo apt-get -qq -o=Dpkg::Use-Pty=0 install -y docker-ce containerd.io

echo "- Installing pip3 .."
sudo apt-get -qq -o=Dpkg::Use-Pty=0 update
sudo apt-get -qq -o=Dpkg::Use-Pty=0 -y install python3-pip

echo "- Installing docker-compose through pip3 .."
sudo pip3 install docker-compose -q

echo "Permit user `$USER starting docker service without password"
grep -Fxq '/usr/sbin/service docker *' /etc/sudoers || printf "`$USER ALL=(root) NOPASSWD: /usr/sbin/service docker *" | sudo tee -a /etc/sudoers > /dev/null

echo "Setup auto-start docker service on Ubuntu (WSL) started "
grep -Fxq 'sudo service docker status > /dev/null || sudo service docker start > /dev/null' ~/.profile || printf "\nsudo service docker start" >> ~/.profile
"@ -replace '"',"`"" -replace "`r",""
}


# Run install script for runtime
Set-Content -Path "C:\install-wsl2-container-runtime.sh" -Value "$runtimeInstallScript"
& ubuntu.exe run bash "/mnt/c/install-wsl2-container-runtime.sh"
Remove-Item "C:\install-wsl2-container-runtime.sh" | Out-Null
Write-Host ""


# Add convenience .bat files
Write-Host "Adding WSL $runtime wrapper bat files .."
$batFileDir = "C:\docker-bat-wrappers"
[System.IO.Directory]::CreateDirectory($batFileDir) | Out-Null
Set-Content -Path "$batFileDir\docker.bat" -Value "@echo off`r`nubuntu run $runtime %*"
Set-Content -Path "$batFileDir\docker-compose.bat" -Value "@echo off`r`nubuntu run $runtime-compose %*"
if ($runtime -eq 'podman')
{
    Set-Content -Path "$batFileDir\podman.bat" -Value "@echo off`r`nubuntu run podman %*"
    Set-Content -Path "$batFileDir\podman-compose.bat" -Value "@echo off`r`nubuntu run podman-compose %*"
}


# Add to PATH
$oldEnvPath = [Environment]::GetEnvironmentVariable('Path', 'User')
if (!$oldEnvPath.Contains($batFileDir)) {
    Write-Host "Adding bat file directory to current user's PATH environment variable .."
    [Environment]::SetEnvironmentVariable('Path', "$oldEnvPath;$batFileDir", 'User')
    Write-Host ""
}


# Add hosts entries
Write-Host "Adding hosts file entries for convenience .."
$hostsFilePath = "C:\Windows\system32\drivers\etc\hosts"
$oldHostsFile = [IO.File]::ReadAllText($hostsFilePath)
foreach ($hostsFileEntry in @('::1 wsl', '::1 docker', '::1 podman')) {
    if (!$oldHostsFile.Contains($hostsFileEntry)) {
        Write-Host "Adding '$hostsFileEntry' to hosts file"
        [IO.File]::AppendAllText($hostsFilePath, "`r`n$hostsFileEntry")
    }
}
Write-Host ""


# Stop WSL for docker service to initialize properly on next start
if ($runtime -eq 'docker')
{
    Write-Host "Restarting WSL so docker service is ready when WSL is started next time.."
    & wsl.exe --shutdown | Out-Null
    Write-Host ""
}

# bye
Write-Host "You should now have docker, docker-compose, podman and podman-compose available in your terminal"
Write-Host "Please share improvements and suggestions as issues on https://github.com/rosenbjerg/wsl2-podman"
Write-Host ""
Write-Host "Press enter to close this window"
Read-Host
