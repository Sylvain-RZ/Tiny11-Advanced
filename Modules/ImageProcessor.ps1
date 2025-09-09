#requires -Version 5.1

<#
.SYNOPSIS
    Image Processing for Tiny11 Advanced
    
.DESCRIPTION
    Handles Windows image mounting, processing, and ISO creation
    Manages the complete image lifecycle from source to final ISO
#>

function Copy-WindowsInstallationFiles {
    <#
    .SYNOPSIS
        Copies Windows installation files from source to destination
        
    .PARAMETER SourcePath
        Source path (drive letter or folder)
        
    .PARAMETER DestinationPath
        Destination directory for the copied files
    #>
    param(
        [Parameter(Mandatory)]
        [string]$SourcePath,
        
        [Parameter(Mandatory)]
        [string]$DestinationPath
    )
    
    Write-Log "Copying Windows installation files..." -Level Info
    Write-Log "Source: $SourcePath" -Level Info
    Write-Log "Destination: $DestinationPath" -Level Info
    
    try {
        # Check if we need to convert install.esd to install.wim
        $installWim = Join-Path $SourcePath "sources\install.wim"
        $installEsd = Join-Path $SourcePath "sources\install.esd"
        
        if (-not (Test-Path $installWim) -and (Test-Path $installEsd)) {
            Write-Log "Found install.esd, converting to install.wim..." -Level Info
            
            # Show available images in ESD
            $imageInfo = Get-WindowsImage -ImagePath $installEsd
            Write-Host "`nAvailable Windows images:" -ForegroundColor Yellow
            $imageInfo | Format-Table ImageIndex, ImageName, Architecture, ImageSize -AutoSize | Out-Host
            
            do {
                $index = Read-Host "Please enter the image index to convert"
                $selectedImage = $imageInfo | Where-Object { $_.ImageIndex -eq $index }
                
                if (-not $selectedImage) {
                    Write-Host "Invalid index. Please try again." -ForegroundColor Red
                }
            } while (-not $selectedImage)
            
            Write-Log "Converting install.esd to install.wim (Index: $index)..." -Level Info
            
            # Create destination sources directory
            $destSourcesPath = Join-Path $DestinationPath "sources"
            if (-not (Test-Path $destSourcesPath)) {
                New-Item -ItemType Directory -Path $destSourcesPath -Force | Out-Null
            }
            
            # Convert ESD to WIM
            $destWimPath = Join-Path $destSourcesPath "install.wim"
            Export-WindowsImage -SourceImagePath $installEsd -SourceIndex $index -DestinationImagePath $destWimPath -CompressionType Maximum -CheckIntegrity
            
            if ($LASTEXITCODE -ne 0 -or -not (Test-Path $destWimPath)) {
                throw "Failed to convert install.esd to install.wim"
            }
            
            Write-Log "ESD to WIM conversion completed successfully" -Level Success
        }
        
        # Copy all files from source to destination
        Write-Log "Copying all installation files..." -Level Info
        Copy-Item -Path "$SourcePath\*" -Destination $DestinationPath -Recurse -Force
        
        # Remove install.esd if it exists in destination (we have the WIM now)
        $destEsd = Join-Path $DestinationPath "sources\install.esd"
        if (Test-Path $destEsd) {
            Remove-Item -Path $destEsd -Force -ErrorAction SilentlyContinue
        }
        
        Write-Log "Windows installation files copied successfully" -Level Success
        return $true
    }
    catch {
        Write-Log "Failed to copy Windows installation files: $($_.Exception.Message)" -Level Error
        return $false
    }
}

function Mount-WindowsImageAdvanced {
    <#
    .SYNOPSIS
        Mounts Windows image with advanced error handling and information gathering
        
    .PARAMETER ImagePath
        Path to the install.wim file
        
    .PARAMETER Index
        Image index to mount (will prompt if not specified)
        
    .PARAMETER MountPath
        Directory where to mount the image
    #>
    param(
        [Parameter(Mandatory)]
        [string]$ImagePath,
        
        [Parameter(Mandatory = $false)]
        [int]$Index,
        
        [Parameter(Mandatory)]
        [string]$MountPath
    )
    
    Write-Log "Mounting Windows image..." -Level Info
    
    try {
        # Ensure mount directory exists and is empty
        if (Test-Path $MountPath) {
            # Check if anything is already mounted here
            $mountedImages = Get-WindowsImage -Mounted
            $existingMount = $mountedImages | Where-Object { $_.Path -eq $MountPath }
            
            if ($existingMount) {
                Write-Log "Dismounting existing image from $MountPath" -Level Warning
                Dismount-WindowsImage -Path $MountPath -Discard
            }
            
            # Clear the directory
            Remove-Item -Path $MountPath -Recurse -Force -ErrorAction SilentlyContinue
        }
        
        New-Item -ItemType Directory -Path $MountPath -Force | Out-Null
        
        # Get image information
        if (-not $Index) {
            $imageInfo = Get-WindowsImage -ImagePath $ImagePath
            Write-Host "`nAvailable Windows images:" -ForegroundColor Yellow
            $imageInfo | Format-Table ImageIndex, ImageName, Architecture, Version, ImageSize -AutoSize | Out-Host
            
            do {
                $Index = Read-Host "Please enter the image index to process"
                $selectedImage = $imageInfo | Where-Object { $_.ImageIndex -eq $Index }
                
                if (-not $selectedImage) {
                    Write-Host "Invalid index. Please try again." -ForegroundColor Red
                }
            } while (-not $selectedImage)
        }
        else {
            $selectedImage = Get-WindowsImage -ImagePath $ImagePath -Index $Index
        }
        
        Write-Log "Selected image: $($selectedImage.ImageName)" -Level Info
        Write-Log "Architecture: $($selectedImage.Architecture)" -Level Info
        Write-Log "Version: $($selectedImage.Version)" -Level Info
        
        # Set file permissions for the WIM file
        & takeown /F $ImagePath | Out-Null
        & icacls $ImagePath /grant "Administrators:(F)" | Out-Null
        
        try {
            Set-ItemProperty -Path $ImagePath -Name IsReadOnly -Value $false -ErrorAction Stop
        }
        catch {
            Write-Log "Could not remove read-only attribute (continuing anyway)" -Level Warning
        }
        
        # Mount the image
        Write-Log "Mounting image index $Index to $MountPath..." -Level Info
        Mount-WindowsImage -ImagePath $ImagePath -Index $Index -Path $MountPath
        
        if ($LASTEXITCODE -ne 0) {
            throw "DISM mount operation failed with exit code: $LASTEXITCODE"
        }
        
        # Verify mount was successful
        Start-Sleep -Seconds 2
        if (-not (Test-Path "$MountPath\Windows")) {
            throw "Mount verification failed - Windows directory not found"
        }
        
        # Get system language
        $languageCode = Get-SystemLanguage -MountPath $MountPath
        
        # Return image information
        $imageDetails = @{
            Index = $Index
            Name = $selectedImage.ImageName
            Architecture = $selectedImage.Architecture
            Version = $selectedImage.Version
            Language = $languageCode
            MountPath = $MountPath
        }
        
        Write-Log "Windows image mounted successfully" -Level Success
        Write-Log "Image details: $($selectedImage.ImageName) ($($selectedImage.Architecture)) - Language: $languageCode" -Level Success
        
        return $imageDetails
    }
    catch {
        Write-Log "Failed to mount Windows image: $($_.Exception.Message)" -Level Error
        
        # Cleanup on failure
        try {
            if (Get-WindowsImage -Mounted | Where-Object { $_.Path -eq $MountPath }) {
                Dismount-WindowsImage -Path $MountPath -Discard
            }
        }
        catch {
            Write-Log "Failed to cleanup mount on error: $($_.Exception.Message)" -Level Warning
        }
        
        return $null
    }
}

function Get-SystemLanguage {
    <#
    .SYNOPSIS
        Determines the system language from the mounted image
        
    .PARAMETER MountPath
        Path to the mounted Windows image
    #>
    param(
        [Parameter(Mandatory)]
        [string]$MountPath
    )
    
    try {
        $imageIntl = & dism /English /Get-Intl "/Image:$MountPath"
        $languageLine = $imageIntl -split '\n' | Where-Object { $_ -match 'Default system UI language : ([a-zA-Z]{2}-[a-zA-Z]{2})' }
        
        if ($languageLine -and $Matches[1]) {
            $languageCode = $Matches[1]
            Write-Log "Detected system language: $languageCode" -Level Info
            return $languageCode
        }
        else {
            Write-Log "Could not detect system language, defaulting to en-US" -Level Warning
            return 'en-US'
        }
    }
    catch {
        Write-Log "Error detecting system language: $($_.Exception.Message)" -Level Warning
        return 'en-US'
    }
}

function Complete-ImageProcessing {
    <#
    .SYNOPSIS
        Completes image processing by dismounting, cleaning up, and creating ISO
        
    .PARAMETER MountPath
        Path where the image is mounted
        
    .PARAMETER ImagePath
        Path to the install.wim file
        
    .PARAMETER Index
        Image index being processed
    #>
    param(
        [Parameter(Mandatory)]
        [string]$MountPath,
        
        [Parameter(Mandatory)]
        [string]$ImagePath,
        
        [Parameter(Mandatory)]
        [int]$Index
    )
    
    Write-Log "Finalizing image processing..." -Level Info
    
    try {
        # Perform final image cleanup
        Write-Log "Performing final image cleanup..." -Level Info
        Repair-WindowsImage -Path $MountPath -StartComponentCleanup -ResetBase
        
        if ($LASTEXITCODE -ne 0) {
            Write-Log "Component cleanup failed, continuing anyway..." -Level Warning
        }
        
        # Dismount and commit changes
        Write-Log "Dismounting and committing image changes..." -Level Info
        Dismount-WindowsImage -Path $MountPath -Save
        
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to dismount and save image"
        }
        
        # Export image with maximum compression
        Write-Log "Exporting image with optimized compression..." -Level Info
        $imageDir = Split-Path $ImagePath
        $tempImagePath = Join-Path $imageDir "install_temp.wim"
        
        Export-WindowsImage -SourceImagePath $ImagePath -SourceIndex $Index -DestinationImagePath $tempImagePath -CompressionType Maximum
        
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to export optimized image"
        }
        
        # Replace original with optimized version
        Remove-Item -Path $ImagePath -Force
        Move-Item -Path $tempImagePath -Destination $ImagePath
        
        # Process boot.wim if it exists
        $bootWimPath = Join-Path (Split-Path $imageDir) "boot.wim"
        if (Test-Path $bootWimPath) {
            Process-BootImage -BootWimPath $bootWimPath -MountPath $MountPath
        }
        
        # Create the ISO
        Create-OptimizedISO -ImageDirectory (Split-Path $imageDir) -OutputPath (Split-Path (Split-Path $imageDir))
        
        Write-Log "Image processing completed successfully" -Level Success
        return $true
    }
    catch {
        Write-Log "Failed to complete image processing: $($_.Exception.Message)" -Level Error
        return $false
    }
}

function Process-BootImage {
    <#
    .SYNOPSIS
        Processes the boot.wim image to apply system requirement bypasses
        
    .PARAMETER BootWimPath
        Path to the boot.wim file
        
    .PARAMETER MountPath
        Temporary mount path for boot image
    #>
    param(
        [Parameter(Mandatory)]
        [string]$BootWimPath,
        
        [Parameter(Mandatory)]
        [string]$MountPath
    )
    
    Write-Log "Processing boot image..." -Level Info
    
    try {
        # Ensure mount path is clean
        if (Test-Path $MountPath) {
            Remove-Item -Path $MountPath -Recurse -Force
        }
        New-Item -ItemType Directory -Path $MountPath -Force | Out-Null
        
        # Set permissions on boot.wim
        & takeown /F $BootWimPath | Out-Null
        & icacls $BootWimPath /grant "Administrators:(F)" | Out-Null
        Set-ItemProperty -Path $BootWimPath -Name IsReadOnly -Value $false -ErrorAction SilentlyContinue
        
        # Mount boot image (index 2 is typically Windows Setup)
        Mount-WindowsImage -ImagePath $BootWimPath -Index 2 -Path $MountPath
        
        # Apply system requirement bypasses to boot image
        Write-Log "Applying system requirement bypasses to boot image..." -Level Info
        
        # Load registry hives
        & reg load HKLM\zDEFAULT "$MountPath\Windows\System32\config\default" | Out-Null
        & reg load HKLM\zNTUSER "$MountPath\Users\Default\ntuser.dat" | Out-Null
        & reg load HKLM\zSYSTEM "$MountPath\Windows\System32\config\SYSTEM" | Out-Null
        
        # Apply bypasses
        $bypassSettings = @(
            @{ Path = 'HKLM\zDEFAULT\Control Panel\UnsupportedHardwareNotificationCache'; Name = 'SV1'; Data = '0' },
            @{ Path = 'HKLM\zDEFAULT\Control Panel\UnsupportedHardwareNotificationCache'; Name = 'SV2'; Data = '0' },
            @{ Path = 'HKLM\zNTUSER\Control Panel\UnsupportedHardwareNotificationCache'; Name = 'SV1'; Data = '0' },
            @{ Path = 'HKLM\zNTUSER\Control Panel\UnsupportedHardwareNotificationCache'; Name = 'SV2'; Data = '0' },
            @{ Path = 'HKLM\zSYSTEM\Setup\LabConfig'; Name = 'BypassCPUCheck'; Data = '1' },
            @{ Path = 'HKLM\zSYSTEM\Setup\LabConfig'; Name = 'BypassRAMCheck'; Data = '1' },
            @{ Path = 'HKLM\zSYSTEM\Setup\LabConfig'; Name = 'BypassSecureBootCheck'; Data = '1' },
            @{ Path = 'HKLM\zSYSTEM\Setup\LabConfig'; Name = 'BypassStorageCheck'; Data = '1' },
            @{ Path = 'HKLM\zSYSTEM\Setup\LabConfig'; Name = 'BypassTPMCheck'; Data = '1' },
            @{ Path = 'HKLM\zSYSTEM\Setup\MoSetup'; Name = 'AllowUpgradesWithUnsupportedTPMOrCPU'; Data = '1' }
        )
        
        foreach ($setting in $bypassSettings) {
            & reg add $setting.Path /v $setting.Name /t REG_DWORD /d $setting.Data /f | Out-Null
        }
        
        # Unload registry hives
        & reg unload HKLM\zDEFAULT | Out-Null
        & reg unload HKLM\zNTUSER | Out-Null
        & reg unload HKLM\zSYSTEM | Out-Null
        
        # Dismount boot image
        Dismount-WindowsImage -Path $MountPath -Save
        
        Write-Log "Boot image processing completed" -Level Success
        return $true
    }
    catch {
        Write-Log "Boot image processing failed: $($_.Exception.Message)" -Level Error
        return $false
    }
}

function Create-OptimizedISO {
    <#
    .SYNOPSIS
        Creates an optimized ISO file from the processed Windows image
        
    .PARAMETER ImageDirectory
        Directory containing the processed Windows files
        
    .PARAMETER OutputPath
        Path where to create the ISO file
    #>
    param(
        [Parameter(Mandatory)]
        [string]$ImageDirectory,
        
        [Parameter(Mandatory)]
        [string]$OutputPath
    )
    
    Write-Log "Creating optimized ISO image..." -Level Info
    
    try {
        # Determine oscdimg.exe location
        $hostArch = $env:PROCESSOR_ARCHITECTURE
        $adkPath = "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\$hostArch\Oscdimg"
        $localOscdimg = Join-Path $PSScriptRoot "oscdimg.exe"
        
        $oscdimgPath = $null
        
        if (Test-Path "$adkPath\oscdimg.exe") {
            $oscdimgPath = "$adkPath\oscdimg.exe"
            Write-Log "Using oscdimg.exe from Windows ADK" -Level Info
        }
        elseif (Test-Path $localOscdimg) {
            $oscdimgPath = $localOscdimg
            Write-Log "Using local oscdimg.exe" -Level Info
        }
        else {
            # Download oscdimg.exe
            Write-Log "Downloading oscdimg.exe..." -Level Info
            $downloadUrl = "https://msdl.microsoft.com/download/symbols/oscdimg.exe/3D44737265000/oscdimg.exe"
            
            try {
                Invoke-WebRequest -Uri $downloadUrl -OutFile $localOscdimg -UseBasicParsing
                
                if (Test-Path $localOscdimg) {
                    $oscdimgPath = $localOscdimg
                    Write-Log "oscdimg.exe downloaded successfully" -Level Success
                }
                else {
                    throw "Download verification failed"
                }
            }
            catch {
                Write-Log "Failed to download oscdimg.exe: $($_.Exception.Message)" -Level Error
                throw "Cannot create ISO without oscdimg.exe"
            }
        }
        
        # Create autounattend.xml for OOBE bypass if it doesn't exist
        $autoUnattendPath = Join-Path $ImageDirectory "autounattend.xml"
        if (-not (Test-Path $autoUnattendPath)) {
            Create-AutoUnattendXML -OutputPath $autoUnattendPath
        }
        
        # Generate ISO filename with timestamp
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $isoFileName = "Tiny11Advanced_$timestamp.iso"
        $isoPath = Join-Path $OutputPath $isoFileName
        
        Write-Log "Creating ISO: $isoFileName" -Level Info
        
        # Build oscdimg command
        $bootData = "2#p0,e,b$ImageDirectory\boot\etfsboot.com#pEF,e,b$ImageDirectory\efi\microsoft\boot\efisys.bin"
        
        $oscdimgArgs = @(
            '-m',
            '-o',
            '-u2',
            '-udfver102',
            "-bootdata:$bootData",
            $ImageDirectory,
            $isoPath
        )
        
        # Execute oscdimg
        & $oscdimgPath @oscdimgArgs
        
        if ($LASTEXITCODE -eq 0 -and (Test-Path $isoPath)) {
            $isoSize = [math]::Round((Get-Item $isoPath).Length / 1GB, 2)
            Write-Log "ISO created successfully: $isoFileName ($isoSize GB)" -Level Success
            Write-Log "ISO location: $isoPath" -Level Success
            return $true
        }
        else {
            throw "oscdimg.exe failed with exit code: $LASTEXITCODE"
        }
    }
    catch {
        Write-Log "Failed to create ISO: $($_.Exception.Message)" -Level Error
        return $false
    }
}

function Create-AutoUnattendXML {
    <#
    .SYNOPSIS
        Creates an autounattend.xml file for bypassing OOBE requirements
        
    .PARAMETER OutputPath
        Path where to create the autounattend.xml file
    #>
    param(
        [Parameter(Mandatory)]
        [string]$OutputPath
    )
    
    Write-Log "Creating autounattend.xml for OOBE bypass..." -Level Info
    
    $autoUnattendContent = @'
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
    <settings pass="oobeSystem">
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <OOBE>
                <HideEULAPage>true</HideEULAPage>
                <HideLocalAccountScreen>false</HideLocalAccountScreen>
                <HideOEMRegistrationScreen>true</HideOEMRegistrationScreen>
                <HideOnlineAccountScreens>true</HideOnlineAccountScreens>
                <HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE>
                <NetworkLocation>Home</NetworkLocation>
                <ProtectYourPC>1</ProtectYourPC>
                <SkipUserOOBE>false</SkipUserOOBE>
                <SkipMachineOOBE>true</SkipMachineOOBE>
            </OOBE>
            <UserAccounts>
                <LocalAccounts>
                    <LocalAccount wcm:action="add">
                        <Password>
                            <Value></Value>
                            <PlainText>true</PlainText>
                        </Password>
                        <Description>Default User Account</Description>
                        <DisplayName>User</DisplayName>
                        <Group>Administrators</Group>
                        <Name>User</Name>
                    </LocalAccount>
                </LocalAccounts>
            </UserAccounts>
        </component>
    </settings>
</unattend>
'@

    try {
        Set-Content -Path $OutputPath -Value $autoUnattendContent -Encoding UTF8
        Write-Log "autounattend.xml created successfully" -Level Success
        return $true
    }
    catch {
        Write-Log "Failed to create autounattend.xml: $($_.Exception.Message)" -Level Error
        return $false
    }
}

function Get-WindowsImageIndex {
    <#
    .SYNOPSIS
        Interactive function to get Windows image index from user
        
    .PARAMETER ImagePath
        Path to the install.wim file
    #>
    param(
        [Parameter(Mandatory)]
        [string]$ImagePath
    )
    
    try {
        if (-not (Test-Path $ImagePath)) {
            $ImagePath = Join-Path $ImagePath "sources\install.wim"
            if (-not (Test-Path $ImagePath)) {
                throw "install.wim not found"
            }
        }
        
        $imageInfo = Get-WindowsImage -ImagePath $ImagePath
        
        Write-Host "`n" + "="*80 -ForegroundColor Cyan | Out-Null
        Write-Host "Available Windows Images" -ForegroundColor Cyan | Out-Null
        Write-Host "="*80 -ForegroundColor Cyan | Out-Null
        
        $null = $imageInfo | Format-Table @(
            @{Label="Index"; Expression={$_.ImageIndex}; Width=5},
            @{Label="Name"; Expression={$_.ImageName}; Width=35},
            @{Label="Architecture"; Expression={$_.Architecture}; Width=12},
            @{Label="Version"; Expression={$_.Version}; Width=15},
            @{Label="Size (GB)"; Expression={[math]::Round($_.ImageSize/1GB, 2)}; Width=10}
        ) -AutoSize | Out-Host
        
        do {
            $index = Read-Host "Please enter the image index to process"
            $selectedImage = $imageInfo | Where-Object { $_.ImageIndex -eq $index }
            
            if (-not $selectedImage) {
                Write-Host "Invalid index '$index'. Please choose from the available indexes." -ForegroundColor Red | Out-Null
            }
            else {
                Write-Host "Selected: $($selectedImage.ImageName)" -ForegroundColor Green | Out-Null
                $confirm = Read-Host "Is this correct? (y/n)"
                if ($confirm -eq 'y' -or $confirm -eq 'Y') {
                    # Ensure we return only an integer, not an array
                    $result = [int]$index
                    return $result
                }
                else {
                    $selectedImage = $null
                }
            }
        } while (-not $selectedImage)
    }
    catch {
        Write-Log "Failed to get image index: $($_.Exception.Message)" -Level Error
        return $null
    }
}