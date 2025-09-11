#requires -Version 5.1
#requires -RunAsAdministrator

<#
.SYNOPSIS
    Advanced Tiny11 Windows 11 Image Creator
    
.DESCRIPTION
    Creates a lightweight, optimized Windows 11 image by removing bloatware,
    disabling telemetry, and implementing advanced anti-reinstallation methods.
    Preserves Windows Update and Windows Store functionality.
    
.PARAMETER SourcePath
    Path to the Windows 11 installation media (drive letter or folder path)
    
.PARAMETER OutputPath
    Output directory for the created image (default: script directory)
    
.PARAMETER ImageIndex
    Windows image index to process (will prompt if not specified)
    
.PARAMETER EnableDotNet35
    Enable .NET Framework 3.5 in the image
    
.PARAMETER DisableDefender
    Disable Windows Defender (can be re-enabled by user)
    
.PARAMETER SkipSystemPackages
    Skip removal of system packages for faster processing

.PARAMETER SkipWinSxS
    Skip WinSxS optimization for faster processing (avoids potential hanging)

.PARAMETER AggressiveWinSxS
    Enable aggressive WinSxS cleanup with /ResetBase (WARNING: breaks language packs and Windows updates)

.PARAMETER RemoveAdditionalLanguages
    Remove additional language packs while preserving primary language
    
.EXAMPLE
    .\Tiny11Advanced.ps1 -SourcePath "D:" -EnableDotNet35 -DisableDefender -AggressiveWinSxS -RemoveAdditionalLanguages
    
.NOTES
    Version: 1.0
    Author: Tiny11 Advanced
    
    IMPORTANT RULES:
    - Preserves Windows Update functionality
    - Preserves Windows Store functionality  
    - Windows Defender is disabled, not removed (can be re-enabled)
    - Creates restore point capabilities
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [ValidateScript({
        if ($_ -match '^[A-Z]:$') { Test-Path $_ }
        elseif (Test-Path $_ -PathType Container) { $true }
        else { throw "Invalid source path: $_" }
    })]
    [string]$SourcePath,
    
    [Parameter(Mandatory = $false)]
    [ValidateScript({
        if ([string]::IsNullOrEmpty($_)) { $true }  # Allow empty, will be set later
        elseif (Test-Path $_ -PathType Container) { $true }
        else { throw "Output path must be a valid directory: $_" }
    })]
    [string]$OutputPath,
    
    [Parameter(Mandatory = $false)]
    [int]$ImageIndex,
    
    [Parameter(Mandatory = $false)]
    [switch]$EnableDotNet35,
    
    [Parameter(Mandatory = $false)]
    [switch]$DisableDefender,
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipSystemPackages,
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipWinSxS,
    
    [Parameter(Mandatory = $false)]
    [switch]$AggressiveWinSxS,
    
    [Parameter(Mandatory = $false)]
    [switch]$RemoveAdditionalLanguages
)

# Import required modules with dependency management
# This ensures proper loading order and error handling
$ModulePath = Join-Path $PSScriptRoot "Modules"
if (-not (Test-Path $ModulePath)) {
    Write-Error "Modules directory not found. Please ensure all module files are present."
    exit 1
}

try {
    . (Join-Path $ModulePath "AppxPackageManager.ps1")
    . (Join-Path $ModulePath "RegistryOptimizer.ps1")
    . (Join-Path $ModulePath "SystemOptimizer.ps1")
    . (Join-Path $ModulePath "SecurityManager.ps1")
    . (Join-Path $ModulePath "ImageProcessor.ps1")
    . (Join-Path $ModulePath "ValidationHelper.ps1")
    Write-Host "All modules loaded successfully" -ForegroundColor Green
}
catch {
    Write-Error "Failed to load required modules: $($_.Exception.Message)"
    exit 1
}

# Global variables - will be initialized after parameter validation

#region Helper Functions

function Write-Log {
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        
        [ValidateSet('Info', 'Warning', 'Error', 'Success')]
        [string]$Level = 'Info'
    )
    
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logEntry = "[$timestamp] [$Level] $Message"
    
    # Write to console with color
    switch ($Level) {
        'Info'    { Write-Host $logEntry -ForegroundColor White }
        'Warning' { Write-Host $logEntry -ForegroundColor Yellow }
        'Error'   { Write-Host $logEntry -ForegroundColor Red }
        'Success' { Write-Host $logEntry -ForegroundColor Green }
    }
    
    # Write to log file
    Add-Content -Path $Global:LogFile -Value $logEntry -ErrorAction SilentlyContinue
}

function Show-Banner {
    Clear-Host
    Write-Host @"
+==============================================================================+
|                        Tiny11 Advanced Image Creator                         |
|                              Version 1.0                                     |
+==============================================================================+
|  Creates optimized Windows 11 images with advanced debloating features       |
|  • Removes bloatware and telemetry                                           |
|  • Preserves Windows Update & Store                                          |
|  • Advanced anti-reinstallation methods                                      |
|  • Professional code architecture                                            |
+==============================================================================+

"@ -ForegroundColor Cyan
}

function Invoke-PreflightChecks {
    Write-Log "Performing preflight checks..." -Level Info
    
    # Check PowerShell version
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        Write-Log "PowerShell 5.1 or higher is required" -Level Error
        return $false
    }
    
    # Check admin privileges
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]$currentUser
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Log "Administrator privileges required" -Level Error
        return $false
    }
    
    # Check DISM availability
    if (-not (Get-Command dism.exe -ErrorAction SilentlyContinue)) {
        Write-Log "DISM tool not found" -Level Error
        return $false
    }
    
    # Check disk space (minimum 20GB)
    $drive = Split-Path $OutputPath -Qualifier
    $freeSpace = (Get-WmiObject -Class Win32_LogicalDisk -Filter "DeviceID='$drive'").FreeSpace
    if ($freeSpace -lt 21474836480) {  # 20GB in bytes
        Write-Log "Insufficient disk space. Minimum 20GB required" -Level Warning
    }
    
    Write-Log "Preflight checks completed successfully" -Level Success
    return $true
}

function Get-SourcePath {
    if (-not $SourcePath) {
        do {
            $input = Read-Host "Please enter the Windows 11 source path (drive letter like D: or folder path)"
            
            if ($input -match '^[A-Z]:$') {
                if (Test-Path $input) {
                    $SourcePath = $input
                    break
                }
                else {
                    Write-Host "Drive not found: $input" -ForegroundColor Red
                }
            }
            elseif (Test-Path $input -PathType Container) {
                $SourcePath = $input
                break
            }
            else {
                Write-Host "Invalid path: $input" -ForegroundColor Red
            }
        } while ($true)
    }
    
    Write-Log "Source path set to: $SourcePath" -Level Info
    return $SourcePath
}

function Initialize-WorkingDirectories {
    Write-Log "Initializing working directories..." -Level Info
    
    $directories = @(
        $Global:ScratchDirectory,
        $Global:ImageDirectory,
        (Join-Path $Global:ImageDirectory "sources")
    )
    
    foreach ($dir in $directories) {
        if (-not (Test-Path $dir)) {
            try {
                New-Item -ItemType Directory -Path $dir -Force | Out-Null
                Write-Log "Created directory: $dir" -Level Info
            }
            catch {
                Write-Log "Failed to create directory: $dir - $($_.Exception.Message)" -Level Error
                return $false
            }
        }
    }
    
    Write-Log "Working directories initialized successfully" -Level Success
    return $true
}

function Start-ProcessingWorkflow {
    param(
        [string]$SourcePath,
        [int]$ImageIndex
    )
    
    try {
        # Step 1: Copy source files
        Write-Log "Step 1/8: Copying Windows installation files..." -Level Info
        if (-not (Copy-WindowsInstallationFiles -SourcePath $SourcePath -DestinationPath $Global:ImageDirectory)) {
            throw "Failed to copy installation files"
        }
        
        # Step 2: Mount image
        Write-Log "Step 2/8: Mounting Windows image..." -Level Info
        $imageInfo = Mount-WindowsImageAdvanced -ImagePath (Join-Path $Global:ImageDirectory "sources\install.wim") -Index $ImageIndex -MountPath $Global:ScratchDirectory
        if (-not $imageInfo) {
            throw "Failed to mount Windows image"
        }
        
        # Step 3: Remove AppX packages
        Write-Log "Step 3/8: Removing bloatware applications..." -Level Info
        Remove-BloatwarePackages -MountPath $Global:ScratchDirectory
        
        # Step 4: Remove system packages (optional)
        if (-not $SkipSystemPackages) {
            Write-Log "Step 4/8: Removing system packages..." -Level Info
            $languageCode = if ([string]::IsNullOrEmpty($imageInfo.Language)) { "en-US" } else { $imageInfo.Language }
            Remove-SystemPackages -MountPath $Global:ScratchDirectory -LanguageCode $languageCode
        }
        else {
            Write-Log "Step 4/8: Skipping system packages removal" -Level Warning
        }
        
        # Step 4b: Remove additional language packs (optional)
        if ($RemoveAdditionalLanguages) {
            Write-Log "Step 4b/8: Removing additional language packs..." -Level Info
            $primaryLanguage = if ([string]::IsNullOrEmpty($imageInfo.Language)) { "en-US" } else { $imageInfo.Language }
            Remove-AdditionalLanguagePacks -MountPath $Global:ScratchDirectory -PrimaryLanguage $primaryLanguage
        }
        
        # Step 5: Apply registry optimizations
        Write-Log "Step 5/8: Applying registry optimizations..." -Level Info
        Optimize-RegistrySettings -MountPath $Global:ScratchDirectory
        
        # Step 6: System optimizations
        Write-Log "Step 6/8: Applying system optimizations..." -Level Info
        Optimize-SystemSettings -MountPath $Global:ScratchDirectory -EnableDotNet35:$EnableDotNet35 -SkipWinSxS:$SkipWinSxS -AggressiveWinSxS:$AggressiveWinSxS
        
        # Step 7: Security optimizations
        Write-Log "Step 7/8: Configuring security settings..." -Level Info
        if ($DisableDefender) {
            Disable-WindowsDefender -MountPath $Global:ScratchDirectory
            
            # Create comprehensive Defender management script in the final image
            Write-Log "Creating Windows Defender management script for end users..." -Level Info
            $managementScriptPath = Join-Path $Global:ScratchDirectory "Windows\Temp"
            Create-DefenderManagementScript -OutputPath $managementScriptPath
        }
        
        # Step 8: Finalize and create ISO
        Write-Log "Step 8/8: Finalizing image and creating ISO..." -Level Info
        Complete-ImageProcessing -MountPath $Global:ScratchDirectory -ImagePath (Join-Path $Global:ImageDirectory "sources\install.wim") -Index $ImageIndex
        
        Write-Log "Windows 11 Advanced image creation completed successfully!" -Level Success
        return $true
    }
    catch {
        Write-Log "Processing failed: $($_.Exception.Message)" -Level Error
        return $false
    }
}

function Invoke-Cleanup {
    Write-Log "Performing cleanup..." -Level Info
    
    try {
        # Use comprehensive DISM cleanup
        Clear-DismMountPoints -MountPath $Global:ScratchDirectory
        
        # Remove working directories
        if (Test-Path $Global:ScratchDirectory) {
            Remove-Item -Path $Global:ScratchDirectory -Recurse -Force -ErrorAction SilentlyContinue
        }
        
        Write-Log "Cleanup completed" -Level Success
    }
    catch {
        Write-Log "Cleanup failed: $($_.Exception.Message)" -Level Warning
    }
}

#endregion

#region Main Execution

function Main {
    try {
        # Initialize OutputPath if not provided
        if ([string]::IsNullOrEmpty($OutputPath)) {
            $OutputPath = if ($PSScriptRoot) { $PSScriptRoot } else { Get-Location -PSProvider FileSystem | Select-Object -ExpandProperty Path }
        }
        
        # Initialize global variables
        $Global:WorkingDirectory = $OutputPath
        $Global:ScratchDirectory = Join-Path $OutputPath "ScratchDir"
        $Global:ImageDirectory = Join-Path $OutputPath "Tiny11Advanced"
        $Global:LogFile = Join-Path $OutputPath "Tiny11Advanced_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
        
        # Initialize logging
        Start-Transcript -Path $Global:LogFile -ErrorAction SilentlyContinue
        
        # Show banner
        Show-Banner
        
        # Preflight checks
        if (-not (Invoke-PreflightChecks)) {
            throw "Preflight checks failed"
        }
        
        # Get source path
        $SourcePath = Get-SourcePath
        
        # Initialize working directories
        if (-not (Initialize-WorkingDirectories)) {
            throw "Failed to initialize working directories"
        }
        
        # Validate source
        $validationResult = Test-WindowsInstallationSource -Path $SourcePath
        if (-not $validationResult.IsValid) {
            throw "Source validation failed: $($validationResult.Error)"
        }
        
        # Get image index if not specified
        if (-not $ImageIndex) {
            $result = Get-WindowsImageIndex -ImagePath (Join-Path $SourcePath "sources\install.wim")
            if (-not $result) {
                throw "Failed to get image index"
            }
            # Ensure we get only the integer value, not an array
            if ($result -is [array]) {
                $ImageIndex = [int]$result[-1]  # Take the last element if it's an array
            } else {
                $ImageIndex = [int]$result
            }
        }
        
        # Show configuration summary
        Write-Host "`n=== Configuration Summary ===" -ForegroundColor Yellow
        Write-Host "Source Path: $SourcePath"
        Write-Host "Output Path: $OutputPath"
        Write-Host "Image Index: $ImageIndex"
        Write-Host "Enable .NET 3.5: $EnableDotNet35"
        Write-Host "Disable Defender: $DisableDefender"
        Write-Host "Skip System Packages: $SkipSystemPackages"
        Write-Host "==============================`n"
        
        $confirmation = Read-Host "Do you want to proceed? (y/N)"
        if ($confirmation -ne 'y' -and $confirmation -ne 'Y') {
            Write-Log "Operation cancelled by user" -Level Warning
            return
        }
        
        # Start processing
        $success = Start-ProcessingWorkflow -SourcePath $SourcePath -ImageIndex $ImageIndex
        
        if ($success) {
            Write-Host "`n" + "="*80 -ForegroundColor Green
            Write-Host "SUCCESS: Tiny11 Advanced image created successfully!" -ForegroundColor Green
            Write-Host "Output location: $OutputPath" -ForegroundColor Green
            Write-Host "Log file: $Global:LogFile" -ForegroundColor Green
            Write-Host "="*80 -ForegroundColor Green
        }
        else {
            throw "Image creation failed"
        }
    }
    catch {
        Write-Log "Fatal error: $($_.Exception.Message)" -Level Error
        Write-Host "`nImage creation failed. Check the log file for details: $Global:LogFile" -ForegroundColor Red
        exit 1
    }
    finally {
        Invoke-Cleanup
        Stop-Transcript -ErrorAction SilentlyContinue
    }
}

# Execute main function
Main

#endregion