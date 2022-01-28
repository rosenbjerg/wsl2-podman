# Install script for WSL2 + podman and podman-compose (or docker and docker-compose I guess)
# Author: Malte Rosenbjerg

# Enable required Windows features
$host.ui.RawUI.WindowTitle = "Installing WSL2 + ?"
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
& wsl --set-default-version 2 | Out-Null
Write-Host ""


# Stop and migrate Ubuntu distro if needed
$wslDistros = (& wsl -l -v) -join "" -replace "\u0000",""
$wslDistroRegex = "Ubuntu(-\d\d\.\d\d)?\s+([^\s]+)\s+([12])"
$distro = "Ubuntu$([Regex]::Match($wslDistros, $wslDistroRegex).Groups[1].Value)"
$distroWslVersion = [Regex]::Match($wslDistros, $wslDistroRegex).Groups[3].Value
if ($distroWslVersion -eq '1')
{
    $distroState = [Regex]::Match($wslDistros, $wslDistroRegex).Groups[2].Value
    if ($distroState -eq 'Running')
    {
        Write-Host -ForegroundColor Yellow "The current $distro distro needs to be stopped before being migrated to WSL2. Press enter to continue"
        Read-Host
        & wsl --shutdown | Out-Null
    }
    
    Write-Host -ForegroundColor Yellow "$distro will now be migrated to WSL2. Press enter to continue"
    Read-Host
    Write-Host "Migrating $distro distro to WSL2 .. "
    & wsl --set-version "$distro" 2 | Out-Null
    Write-Host ""
}
elseif ($distroWslVersion -eq '')
{
    Write-Host -ForegroundColor Yellow "Ubuntu distro was not found and will now be installed. Press enter to continue .."
    Read-Host

    Write-Host "Downloading Ubuntu 20.04 WSL2 image (895MB) - this might take a while due to slow servers .."
    $WslUbuntu = "C:\Users\Public\Downloads\Ubuntu.appx"
    $ProgressPreference = 'SilentlyContinue'  
    try {
        Invoke-WebRequest -Uri https://aka.ms/wslubuntu2004 -OutFile "$WslUbuntu" -UseBasicParsing
    }
    catch {
        Write-Host -ForegroundColor Red "Downloading the Ubuntu 20.04 image failed. Please re-run the script to retry"
        Write-Host -ForegroundColor Yellow "Press enter to close"
        Read-Host
        Exit 1
    }
    Write-Host "Installing Ubuntu WSL2 image .."
    Add-AppxPackage "$WslUbuntu" | Out-Null
    $ProgressPreference = 'Continue'
    & ubuntu2004 echo OK
    Remove-Item "$WslUbuntu" | Out-Null
    $distro = "Ubuntu-20.04"
    Write-Host ""
}


# Print distro info
Write-Host "Distro info:"
& wsl -d "$distro" uname -a
Write-Host ""


# podman or docker?
$runtime = ''
while ($runtime -ne 'podman' -And $runtime -ne 'docker') {
    Write-Host -ForegroundColor Yellow 'podman or docker?'
    $runtime = Read-Host
}

Write-Host "$runtime it is!"
$host.ui.RawUI.WindowTitle = "Installing WSL2 + $runtime"
Write-Host ""


# Set priority for Cisco AnyConnect network adapter if found
Get-NetAdapter | Where-Object {$_.InterfaceDescription -Match 'Cisco AnyConnect'} | Set-NetIPInterface -ErrorAction SilentlyContinue -InterfaceMetric 6000 | Out-Null
& wsl --shutdown | Out-Null


# Create runtime install script
$runtimeInstallScript = ''
if ($runtime -eq 'podman') 
{   # podman install script
    Write-Host "Installing podman and podman-compose in Ubuntu distro .."
    $runtimeInstallScript = @"
podman -v > /dev/null 2>&1 && {
    echo " podman is already installed";
} || {
    echo "Adding kubic podman source and key ..";
    . /etc/os-release;
    sudo sh -c "printf 'deb http://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/x`${NAME}_`${VERSION_ID}/ /' > /etc/apt/sources.list.d/devel:kubic:libcontainers:stable.list";
    wget -q -nv https://download.opensuse.org/repositories/devel:kubic:libcontainers:stable/x`${NAME}_`${VERSION_ID}/Release.key -O ~/Release.key;
    sudo apt-key add - < ~/Release.key;
    sudo rm ~/Release.key;

    echo "Installing podman ..";
    sudo apt-get -qq update > /dev/null;
    sudo apt-get -qq -y install podman > /dev/null;
}
grep -Fq 'refresh_rootless_podman_after_reboot' ~/.profile || {
    echo "Adding podman tmp file clearing";
    printf "
function refresh_rootless_podman_after_reboot {
    local boot_id=\"\`$(cat /proc/sys/kernel/random/boot_id)\";
    local boot_id_file=\"/tmp/last-podman-wipe-boot-id\";
    local libpod_tmp=\"/tmp/podman-run-\`$(id -u)/libpod/tmp\";
    ! test -f \`$boot_id_file || ! grep -Fq \"\`$boot_id\" \"\`$boot_id_file\" && {
      rm -rf \"\`$libpod_tmp\";
      printf \"\`$boot_id\" > \"\`$boot_id_file\";
    }
  }
refresh_rootless_podman_after_reboot;" >> ~/.profile;
}

podman-compose -v > /dev/null 2>&1 && {
    echo " podman-compose is already installed";
} || {
    echo "Installing pip3 ..";
    sudo apt-get -qq update > /dev/null;
    sudo apt-get -qq -y install python3-pip > /dev/null 2>&1;

    echo "Installing podman-compose through pip3 ..";
    sudo pip3 install podman-compose -q > /dev/null;
}

echo "Adding aliases for docker and docker-compose in .profile ..";
grep -Fxq 'alias docker=podman' ~/.profile || printf "\nalias docker=podman" >> ~/.profile;
grep -Fxq 'alias docker-compose=podman-compose' ~/.profile || printf "\nalias docker-compose=podman-compose" >> ~/.profile;
"@ -replace '"',"`"" -replace "`r",""
}
elseif ($runtime -eq 'docker')
{   # docker install script
    Write-Host "Installing docker and docker-compose in Ubuntu distro .."
    $runtimeInstallScript = @"
docker -v > /dev/null 2>&1 && {
    echo " docker is already installed";
} || {
    echo "Adding docker source ..";
    sudo groupadd docker > /dev/null;
    sudo usermod -aG docker `${USER};
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu `$(lsb_release -cs) stable" > /dev/null;
    sudo apt-get -qq update > /dev/null;
    
    echo "Installing docker .."
    sudo apt-get -qq -y install docker-ce containerd.io > /dev/null;
}

docker-compose -v > /dev/null 2>&1 && {
    echo " docker-compose is already installed";
} || {
    echo "Installing pip3 ..";
    sudo apt-get -qq update > /dev/null;
    sudo apt-get -qq -y install python3-pip > /dev/null 2>&1;
    
    echo "Installing docker-compose through pip3 ..";
    sudo pip3 install docker-compose -q > /dev/null;
}

echo "Setup auto-start docker service on Ubuntu (WSL) started";
grep -Fq 'sudo service docker start' ~/.profile || printf "\nsudo service docker status > /dev/null || sudo service docker start > /dev/null" >> ~/.profile;

echo "Permit user `$USER starting docker service without password";
sudo grep -Fq '/usr/sbin/service docker *' /etc/sudoers || printf "\n`$USER ALL=(root) NOPASSWD: /usr/sbin/service docker *\n" | sudo tee -a /etc/sudoers > /dev/null;
"@ -replace '"',"`"" -replace "`r",""
}


# Run install script for runtime
[System.IO.File]::WriteAllText('C:\install-wsl2-container-runtime.sh', "$runtimeInstallScript")
& wsl -d "$distro" bash "/mnt/c/install-wsl2-container-runtime.sh"
Remove-Item "C:\install-wsl2-container-runtime.sh" | Out-Null
Write-Host ""


# Add convenience .bat files
Write-Host "Adding WSL $runtime wrapper bat files .."
$batFileDir = "C:\docker-bat-wrappers"
[System.IO.Directory]::CreateDirectory($batFileDir) | Out-Null
[System.IO.File]::WriteAllText("$batFileDir\docker.bat", "@echo off`r`nwsl -d $distro $runtime %*")
[System.IO.File]::WriteAllText("$batFileDir\docker-compose.bat", "@echo off`r`nwsl -d $distro $runtime-compose %*")
if ($runtime -eq 'podman')
{
    [System.IO.File]::WriteAllText("$batFileDir\podman.bat", "@echo off`r`nwsl -d $distro podman %*")
    [System.IO.File]::WriteAllText("$batFileDir\podman-compose.bat", "@echo off`r`nwsl -d $distro podman-compose %*")
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
    & wsl --shutdown | Out-Null
    & wsl -d "$distro" echo OK | Out-Null
    Write-Host ""
}

# bye
Write-Host -ForegroundColor Green "You should now have $runtime, $runtime-compose available in your terminal"
if ($runtime -eq 'podman')
{
    Write-Host "The aliases docker and docker-compose were also added"
}
Write-Host "Please share improvements and suggestions as issues on https://github.com/rosenbjerg/wsl2-podman"
Write-Host ""
Write-Host -ForegroundColor Yellow "Press enter to close this window"
Read-Host
