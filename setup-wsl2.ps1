# Install script for WSL2 + podman and podman-compose
# Author: Malte Rosenbjerg

$host.ui.RawUI.WindowTitle = "Installing WSL2 + podman"
Write-Host "Enabling Windows feature: Microsoft-Windows-Subsystem-Linux .."
& dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart | Out-Null

Write-Host "Enabling Windows feature: VirtualMachinePlatform .."
& dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart | Out-Null
Write-Host ""

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

Write-Host "Setting default WSL version to 2 .."
& wsl.exe --set-default-version 2 | Out-Null

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
    Add-AppxPackage "$WslUbuntu"
    Remove-Item "$WslUbuntu"
}
else 
{
    Write-Host "The installed Ubuntu distro is already using WSL2"
}

Write-Host "Distro info:"
& ubuntu run uname -a
Write-Host ""

$runtime = ''
while ($runtime -ne 'podman' -And $runtime -ne 'docker') {
    Write-Host 'podman or docker?'
    $runtime = Read-Host
}

Write-Host "$runtime it is!"

$runtimeInstallScript = ''
if ($runtime -eq 'podman') 
{
    Write-Host "Installing podman and podman-compose in Ubuntu distro .."
    $runtimeInstallScript = @"
podman -v > /dev/null 2>&1 && podman-compose -v > /dev/null 2>&1 && echo "- podman and podman-compose are already installed" && exit 0;
echo "- Adding kubic podman source and key .."
. /etc/os-release
sudo sh -c "echo 'deb http://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/x`${NAME}_`${VERSION_ID}/ /' > /etc/apt/sources.list.d/devel:kubic:libcontainers:stable.list"
wget -q -nv https://download.opensuse.org/repositories/devel:kubic:libcontainers:stable/x`${NAME}_`${VERSION_ID}/Release.key -O ~/Release.key
sudo apt-key add - < ~/Release.key
sudo rm ~/Release.key
echo "- Installing podman .."
sudo apt-get update -qq 2>&1
sudo apt-get -qq -y install podman
echo "- Installing pip3 .."
sudo apt-get update -qq 2>&1
sudo apt-get -qq -y install python3-pip 2>&1
echo "- Installing podman-compose through pip3 .."
sudo pip3 install podman-compose -qq
echo "- Adding aliases for docker and docker-compose .."
printf "\nalias docker=podman" >> ~/.profile
printf "\nalias docker-compose=podman-compose" >> ~/.profile
"@ -replace '"',"`"" -replace "`r",""
}
elseif ($runtime -eq 'docker')
{
    Write-Host "Installing docker and docker-compose in Ubuntu distro .."
    $runtimeInstallScript = @"
docker -v > /dev/null 2>&1 && docker-compose -v > /dev/null 2>&1 && echo "- docker and docker-compose are already installed" && exit 0;
echo "- Adding docker source .."
sudo groupadd docker
sudo usermod -aG docker `${USER}
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu `$(lsb_release -cs) stable"
sudo apt-get update -qq 2>&1
echo "- Installing docker .."
sudo apt-get install -qq -y docker-ce containerd.io
echo "- Installing docker-compose .."
sudo curl -sSL https://github.com/docker/compose/releases/download/`$(curl -s https://github.com/docker/compose/tags | grep "compose/releases/tag" | sed -r 's|.*([0-9]+\.[0-9]+\.[0-9]+).*|\1|p' | head -n 1)/docker-compose-`$(uname -s)-`$(uname -m) -o /usr/local/bin/docker-compose && sudo chmod +x /usr/local/bin/docker-compose
sudo service docker start
"@ -replace '"',"`"" -replace "`r",""
}


Set-Content -Path "C:\install-wsl2-container-runtime.sh" -Value "$runtimeInstallScript"
& ubuntu.exe run bash "/mnt/c/install-wsl2-container-runtime.sh"
Remove-Item "C:\install-wsl2-container-runtime.sh"
Write-Host ""


Write-Host "Adding WSL podman/docker wrapper bat files .."
$batFileDir = "C:\NoInstall\docker"
[System.IO.Directory]::CreateDirectory($batFileDir) *>$null
Set-Content -Path "$batFileDir\docker.bat" -Value "@echo off`r`nubuntu run $runtime %*"
Set-Content -Path "$batFileDir\docker-compose.bat" -Value "@echo off`r`nubuntu run $runtime-compose %*"
if ($runtime -eq 'podman')
{
    Set-Content -Path "$batFileDir\podman.bat" -Value "@echo off`r`nubuntu run podman %*"
    Set-Content -Path "$batFileDir\podman-compose.bat" -Value "@echo off`r`nubuntu run podman-compose %*"
}

Write-Host "Adding bat file directory to current user's PATH environment variable .."


$oldEnvPath = [Environment]::GetEnvironmentVariable('Path', 'User')
if (!$oldEnvPath.Contains($batFileDir)) {
    $newEnvPath = "$oldEnvPath;$batFileDir"
    [Environment]::SetEnvironmentVariable('Path', $newEnvPath, 'User')
}
else {
    Write-Host "Current user's PATH environment variable already contains the path. Not modified"
}
Write-Host ""


Write-Host "Adding hosts file entries for convenience .."
$hostsFilePath = "C:\Windows\system32\drivers\etc\hosts"
$oldHostsFile = [IO.File]::ReadAllText($hostsFilePath)

$hostsFileEntries = @('::1 wsl', '::1 docker', '::1 podman')
foreach ($hostsFileEntry in $hostsFileEntries) {
    if (!$oldHostsFile.Contains($hostsFileEntry)) {
        Write-Host "Adding '$hostsFileEntry' to hosts file"
        [IO.File]::AppendAllText($hostsFilePath, "`r`n$hostsFileEntry")
    }
}
Write-Host ""



Write-Host "You should now have docker, docker-compose, podman and podman-compose available in your terminal"
Write-Host "Please share improvements and suggestions as issues on https://github.com/rosenbjerg/wsl2-podman"
Write-Host ""
Write-Host "Press enter to close this window"
Read-Host
