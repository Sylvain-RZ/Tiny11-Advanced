#requires -Version 5.1

<#
.SYNOPSIS
    Validation Helper for Tiny11 Advanced
    
.DESCRIPTION
    Provides validation functions for Windows installation sources,
    system requirements, and image integrity checks
#>

function Test-WindowsInstallationSource {
    <#
    .SYNOPSIS
        Validates that the source path contains a valid Windows installation
        
    .PARAMETER Path
        Path to validate (drive letter or directory)
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )
    
    Write-Log "Validating Windows installation source: $Path" -Level Info
    
    $result = @{
        IsValid = $false
        Error = ""
        Version = ""
        Architecture = ""
        Editions = @()
    }
    
    try {
        # Check if path exists
        if (-not (Test-Path $Path)) {
            $result.Error = "Source path does not exist: $Path"
            return $result
        }
        
        # Check for required files
        $requiredFiles = @(
            "sources\boot.wim"
        )
        
        # Check for bootmgr in multiple possible locations (Windows 11 structure changes)
        $bootmgrPaths = @(
            "bootmgr",           # Modern Windows 11 location (root)
            "boot\bootmgr"       # Legacy location
        )
        
        $bootmgrFound = $false
        foreach ($bootmgrPath in $bootmgrPaths) {
            $fullBootmgrPath = Join-Path $Path $bootmgrPath
            if (Test-Path $fullBootmgrPath) {
                $bootmgrFound = $true
                Write-Log "Found bootmgr at: $bootmgrPath" -Level Info
                break
            }
        }
        
        if (-not $bootmgrFound) {
            $result.Error = "bootmgr not found in expected locations: $($bootmgrPaths -join ', ')"
            return $result
        }
        
        foreach ($file in $requiredFiles) {
            $filePath = Join-Path $Path $file
            if (-not (Test-Path $filePath)) {
                $result.Error = "Required file missing: $file"
                return $result
            }
        }
        
        # Check for install.wim or install.esd
        $installWim = Join-Path $Path "sources\install.wim"
        $installEsd = Join-Path $Path "sources\install.esd"
        
        if (-not (Test-Path $installWim) -and -not (Test-Path $installEsd)) {
            $result.Error = "Neither install.wim nor install.esd found in sources directory"
            return $result
        }
        
        # Get image information
        $imagePath = if (Test-Path $installWim) { $installWim } else { $installEsd }
        
        try {
            $imageInfo = Get-WindowsImage -ImagePath $imagePath -ErrorAction Stop
            
            if ($imageInfo.Count -eq 0) {
                $result.Error = "No valid Windows images found in $imagePath"
                return $result
            }
            
            # Validate this is Windows 11
            $firstImage = $imageInfo[0]
            if ($firstImage.Version -notmatch '^10\.0\.22') {
                Write-Log "Warning: This appears to be Windows $($firstImage.Version), not Windows 11" -Level Warning
            }
            
            $result.Version = $firstImage.Version
            $result.Architecture = $firstImage.Architecture
            $result.Editions = $imageInfo | ForEach-Object { $_.ImageName }
            
            Write-Log "Found valid Windows installation source" -Level Success
            Write-Log "Version: $($result.Version)" -Level Info
            Write-Log "Architecture: $($result.Architecture)" -Level Info
            Write-Log "Editions: $($result.Editions -join ', ')" -Level Info
            
            $result.IsValid = $true
        }
        catch {
            $result.Error = "Failed to read image information: $($_.Exception.Message)"
            return $result
        }
        
        return $result
    }
    catch {
        $result.Error = "Validation failed: $($_.Exception.Message)"
        return $result
    }
}

function Test-SystemRequirements {
    <#
    .SYNOPSIS
        Tests system requirements for running Tiny11 Advanced
    #>
    
    Write-Log "Checking system requirements..." -Level Info
    
    $requirements = @{
        PowerShellVersion = $true
        AdminRights = $true
        DiskSpace = $true
        DismAvailable = $true
        Details = @{}
    }
    
    try {
        # Check PowerShell version (5.1+)
        $psVersion = $PSVersionTable.PSVersion
        $requirements.Details.PowerShellVersion = $psVersion.ToString()
        
        if ($psVersion.Major -lt 5 -or ($psVersion.Major -eq 5 -and $psVersion.Minor -lt 1)) {
            $requirements.PowerShellVersion = $false
            Write-Log "PowerShell version $psVersion is not supported. Requires 5.1 or higher." -Level Error
        }
        else {
            Write-Log "PowerShell version: $psVersion [OK]" -Level Success
        }
        
        # Check admin rights
        $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = [Security.Principal.WindowsPrincipal]$currentUser
        $isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        $requirements.AdminRights = $isAdmin
        $requirements.Details.AdminRights = $isAdmin
        
        if ($isAdmin) {
            Write-Log "Administrator privileges: [OK]" -Level Success
        }
        else {
            Write-Log "Administrator privileges required but not present" -Level Error
        }
        
        # Check disk space (at least 25GB free)
        $scriptDrive = Split-Path $PSScriptRoot -Qualifier
        try {
            $drive = Get-WmiObject -Class Win32_LogicalDisk -Filter "DeviceID='$scriptDrive'"
            $freeSpaceGB = [math]::Round($drive.FreeSpace / 1GB, 2)
            $requirements.Details.FreeSpaceGB = $freeSpaceGB
            
            if ($freeSpaceGB -ge 25) {
                Write-Log "Available disk space: $freeSpaceGB GB [OK]" -Level Success
            }
            else {
                $requirements.DiskSpace = $false
                Write-Log "Insufficient disk space. Available: $freeSpaceGB GB, Required: 25 GB" -Level Error
            }
        }
        catch {
            Write-Log "Could not check disk space: $($_.Exception.Message)" -Level Warning
            $requirements.Details.FreeSpaceGB = "Unknown"
        }
        
        # Check DISM availability
        try {
            $dismPath = Get-Command dism.exe -ErrorAction Stop
            $requirements.Details.DismPath = $dismPath.Source
            Write-Log "DISM available: $($dismPath.Source) [OK]" -Level Success
        }
        catch {
            $requirements.DismAvailable = $false
            Write-Log "DISM (Deployment Image Servicing and Management) tool not found" -Level Error
        }
        
        # Check Windows ADK (optional)
        $adkPath = "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit"
        if (Test-Path $adkPath) {
            Write-Log "Windows ADK detected: $adkPath [OK]" -Level Success
            $requirements.Details.WindowsADK = $true
        }
        else {
            Write-Log "Windows ADK not found (will download oscdimg.exe if needed)" -Level Info
            $requirements.Details.WindowsADK = $false
        }
        
        # Overall result
        $allRequirementsMet = $requirements.PowerShellVersion -and $requirements.AdminRights -and $requirements.DiskSpace -and $requirements.DismAvailable
        
        if ($allRequirementsMet) {
            Write-Log "All system requirements met [OK]" -Level Success
        }
        else {
            Write-Log "Some system requirements not met" -Level Error
        }
        
        return $requirements
    } catch {
        Write-Log "System requirements check failed: $($_.Exception.Message)" -Level Error
        return $requirements
    }
}

function Test-ImageIntegrity {
    <#
    .SYNOPSIS
        Tests the integrity of a Windows image file
        
    .PARAMETER ImagePath
        Path to the image file to test
        
    .PARAMETER Index
        Optional image index to test (tests all if not specified)
    #>
    param(
        [Parameter(Mandatory)]
        [string]$ImagePath,
        
        [Parameter(Mandatory = $false)]
        [int]$Index
    )
    
    Write-Log "Testing image integrity: $ImagePath" -Level Info
    
    try {
        if (-not (Test-Path $ImagePath)) {
            throw "Image file not found: $ImagePath"
        }
        
        # Test file accessibility
        try {
            $fileInfo = Get-Item $ImagePath
            Write-Log "Image file size: $([math]::Round($fileInfo.Length / 1GB, 2)) GB" -Level Info
        }
        catch {
            throw "Cannot access image file: $($_.Exception.Message)"
        }
        
        # Test image structure
        if ($Index) {
            Write-Log "Testing image index $Index..." -Level Info
            $testResult = & dism /English /Get-WimInfo "/WimFile:$ImagePath" "/Index:$Index"
        }
        else {
            Write-Log "Testing all images in WIM..." -Level Info
            $testResult = & dism /English /Get-WimInfo "/WimFile:$ImagePath"
        }
        
        if ($LASTEXITCODE -ne 0) {
            throw "DISM reported errors when reading image (Exit code: $LASTEXITCODE)"
        }
        
        # Additional integrity check
        Write-Log "Performing additional integrity verification..." -Level Info
        $checkResult = & dism /English /CheckImageHealth "/ImageFile:$ImagePath"
        
        if ($LASTEXITCODE -eq 0) {
            Write-Log "Image integrity test passed [OK]" -Level Success
            return $true
        }
        else {
            Write-Log "Image integrity test failed (Exit code: $LASTEXITCODE)" -Level Error
            return $false
        }
    }
    catch {
        Write-Log "Image integrity test failed: $($_.Exception.Message)" -Level Error
        return $false
    }
}

function Test-MountedImages {
    <#
    .SYNOPSIS
        Checks for any currently mounted Windows images and optionally cleans them up
        
    .PARAMETER CleanupOrphaned
        If true, dismounts any orphaned mounted images
    #>
    param(
        [switch]$CleanupOrphaned
    )
    
    Write-Log "Checking for mounted Windows images..." -Level Info
    
    try {
        $mountedImages = Get-WindowsImage -Mounted -ErrorAction SilentlyContinue
        
        if (-not $mountedImages) {
            Write-Log "No mounted images found [OK]" -Level Success
            return $true
        }
        
        Write-Log "Found $($mountedImages.Count) mounted image(s):" -Level Warning
        
        foreach ($image in $mountedImages) {
            Write-Log "  - $($image.ImagePath) mounted at $($image.Path)" -Level Info
            Write-Log "    Status: $($image.MountStatus)" -Level Info
            
            if ($CleanupOrphaned) {
                if ($image.MountStatus -eq 'NeedsRemount' -or $image.MountStatus -eq 'Invalid') {
                    Write-Log "Cleaning up orphaned mount: $($image.Path)" -Level Warning
                    try {
                        Dismount-WindowsImage -Path $image.Path -Discard -ErrorAction Stop
                        Write-Log "Successfully dismounted orphaned image" -Level Success
                    }
                    catch {
                        Write-Log "Failed to dismount orphaned image: $($_.Exception.Message)" -Level Error
                        & dism /Cleanup-Wim | Out-Null
                    }
                }
            }
        }
        
        if ($CleanupOrphaned) {
            # Final cleanup attempt
            & dism /Cleanup-Mountpoints | Out-Null
            Write-Log "Performed mount point cleanup" -Level Info
        }
        
        return $true
    }
    catch {
        Write-Log "Failed to check mounted images: $($_.Exception.Message)" -Level Error
        return $false
    }
}

function Get-WindowsImageSummary {
    <#
    .SYNOPSIS
        Provides a detailed summary of a Windows image
        
    .PARAMETER ImagePath
        Path to the image file
    #>
    param(
        [Parameter(Mandatory)]
        [string]$ImagePath
    )
    
    Write-Log "Generating Windows image summary..." -Level Info
    
    try {
        if (-not (Test-Path $ImagePath)) {
            throw "Image file not found: $ImagePath"
        }
        
        $imageInfo = Get-WindowsImage -ImagePath $ImagePath
        $fileInfo = Get-Item $ImagePath
        
        $summary = @{
            FilePath = $ImagePath
            FileSize = $fileInfo.Length
            FileSizeGB = [math]::Round($fileInfo.Length / 1GB, 2)
            CreationTime = $fileInfo.CreationTime
            LastWriteTime = $fileInfo.LastWriteTime
            ImageCount = $imageInfo.Count
            Images = @()
        }
        
        foreach ($image in $imageInfo) {
            $imageDetails = @{
                Index = $image.ImageIndex
                Name = $image.ImageName
                Description = $image.ImageDescription
                Version = $image.Version
                Architecture = $image.Architecture
                Language = $image.Language
                Size = $image.ImageSize
                SizeGB = [math]::Round($image.ImageSize / 1GB, 2)
                CreatedTime = $image.CreatedTime
                ModifiedTime = $image.ModifiedTime
            }
            
            $summary.Images += $imageDetails
        }
        
        # Display summary
        Write-Host "`n" + "="*80 -ForegroundColor Green
        Write-Host "Windows Image Summary" -ForegroundColor Green
        Write-Host "="*80 -ForegroundColor Green
        
        Write-Host "File: $($summary.FilePath)" -ForegroundColor White
        Write-Host "Size: $($summary.FileSizeGB) GB" -ForegroundColor White
        Write-Host "Created: $($summary.CreationTime)" -ForegroundColor White
        Write-Host "Modified: $($summary.LastWriteTime)" -ForegroundColor White
        Write-Host "Image Count: $($summary.ImageCount)" -ForegroundColor White
        
        Write-Host "`nAvailable Images:" -ForegroundColor Yellow
        $summary.Images | Format-Table @(
            @{Label="Index"; Expression={$_.Index}; Width=5},
            @{Label="Name"; Expression={$_.Name}; Width=30},
            @{Label="Version"; Expression={$_.Version}; Width=15},
            @{Label="Architecture"; Expression={$_.Architecture}; Width=12},
            @{Label="Size (GB)"; Expression={$_.SizeGB}; Width=10}
        ) -AutoSize
        
        return $summary
    }
    catch {
        Write-Log "Failed to generate image summary: $($_.Exception.Message)" -Level Error
        return $null
    }
}

function Confirm-UserAction {
    <#
    .SYNOPSIS
        Prompts user for confirmation with detailed information
        
    .PARAMETER Message
        The confirmation message to display
        
    .PARAMETER Details
        Optional array of detail lines to display
        
    .PARAMETER DefaultYes
        If true, defaults to Yes when user presses Enter
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [string[]]$Details,
        
        [switch]$DefaultYes
    )
    
    Write-Host "`n" + "="*60 -ForegroundColor Yellow
    Write-Host "CONFIRMATION REQUIRED" -ForegroundColor Yellow
    Write-Host "="*60 -ForegroundColor Yellow
    
    Write-Host $Message -ForegroundColor White
    
    if ($Details) {
        Write-Host "`nDetails:" -ForegroundColor Cyan
        foreach ($detail in $Details) {
            Write-Host "  • $detail" -ForegroundColor Gray
        }
    }
    
    Write-Host "`n" + "="*60 -ForegroundColor Yellow
    
    if ($DefaultYes) {
        $prompt = "Do you want to continue? [Y/n]"
        $defaultResponse = 'y'
    }
    else {
        $prompt = "Do you want to continue? [y/N]"
        $defaultResponse = 'n'
    }
    
    do {
        $response = Read-Host $prompt
        
        if ([string]::IsNullOrWhiteSpace($response)) {
            $response = $defaultResponse
        }
        
        $response = $response.ToLower()
        
        if ($response -eq 'y' -or $response -eq 'yes') {
            return $true
        }
        elseif ($response -eq 'n' -or $response -eq 'no') {
            return $false
        }
        else {
            Write-Host "Please enter 'y' for yes or 'n' for no." -ForegroundColor Red
        }
    } while ($true)
}