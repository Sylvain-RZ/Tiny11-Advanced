#requires -Version 5.1

<#
.SYNOPSIS
    System Optimization for Tiny11 Advanced
    
.DESCRIPTION
    Handles system-level optimizations including services management,
    scheduled tasks removal, and WinSxS cleanup
#>

function Optimize-SystemSettings {
    <#
    .SYNOPSIS
        Applies comprehensive system optimizations to the mounted image
        
    .PARAMETER MountPath
        Path to the mounted Windows image
        
    .PARAMETER EnableDotNet35
        Whether to enable .NET Framework 3.5
        
    .PARAMETER SkipWinSxS
        Skip WinSxS optimization for faster processing
    #>
    param(
        [Parameter(Mandatory)]
        [string]$MountPath,
        
        [switch]$EnableDotNet35,
        
        [switch]$SkipWinSxS
    )
    
    Write-Log "Starting system optimization process..." -Level Info
    
    try {
        # Remove Microsoft Edge browser
        $architecture = Get-SystemArchitecture -MountPath $MountPath
        Remove-EdgeBrowser -MountPath $MountPath -Architecture $architecture
        
        # Remove OneDrive setup
        Remove-OneDrive -MountPath $MountPath
        
        # Disable telemetry services
        Disable-TelemetryServices -MountPath $MountPath
        
        # Remove scheduled tasks
        Remove-TelemetryScheduledTasks -MountPath $MountPath
        
        # Enable .NET 3.5 if requested
        if ($EnableDotNet35) {
            Enable-DotNetFramework35 -MountPath $MountPath
        }
        
        # Optimize WinSxS (advanced cleanup)
        Optimize-WinSxSStore -MountPath $MountPath -SkipWinSxS:$SkipWinSxS
        
        Write-Log "System optimization completed successfully" -Level Success
        return $true
    }
    catch {
        Write-Log "System optimization failed: $($_.Exception.Message)" -Level Error
        return $false
    }
}

function Get-SystemArchitecture {
    <#
    .SYNOPSIS
        Determines the architecture of the Windows image
        
    .PARAMETER MountPath
        Path to the mounted Windows image
    #>
    param(
        [Parameter(Mandatory)]
        [string]$MountPath
    )
    
    try {
        # Try multiple possible locations for the install image
        $possiblePaths = @(
            "$MountPath\..\sources\install.wim",
            "$MountPath\..\sources\install.esd",
            "$MountPath\..\..\sources\install.wim",
            "$MountPath\..\..\sources\install.esd"
        )
        
        foreach ($imagePath in $possiblePaths) {
            if (Test-Path $imagePath) {
                Write-Log "Found image at: $imagePath" -Level Info
                $imageInfo = & dism /English /Get-WimInfo /wimFile:"$imagePath" /index:1
                $lines = $imageInfo -split '\r?\n'
                
                foreach ($line in $lines) {
                    if ($line -like '*Architecture : *') {
                        $architecture = $line -replace 'Architecture : ', ''
                        # Convert x64 to amd64 for consistency
                        if ($architecture -eq 'x64') {
                            $architecture = 'amd64'
                        }
                        Write-Log "Detected architecture: $architecture" -Level Info
                        return $architecture
                    }
                }
                break
            }
        }
        
        # Fallback: Use host system architecture
        $hostArch = $env:PROCESSOR_ARCHITECTURE
        if ($hostArch -eq 'AMD64') {
            Write-Log "Using host system architecture: amd64" -Level Info
            return 'amd64'
        }
        elseif ($hostArch -eq 'ARM64') {
            Write-Log "Using host system architecture: arm64" -Level Info
            return 'arm64'
        }
        
        Write-Log "Architecture not found, defaulting to amd64" -Level Warning
        return 'amd64'
    }
    catch {
        Write-Log "Failed to get architecture: $($_.Exception.Message)" -Level Error
        # Final fallback: Use host system architecture
        $hostArch = $env:PROCESSOR_ARCHITECTURE
        if ($hostArch -eq 'AMD64') {
            return 'amd64'
        }
        elseif ($hostArch -eq 'ARM64') {
            return 'arm64'
        }
        return 'amd64'
    }
}

function Disable-TelemetryServices {
    <#
    .SYNOPSIS
        Disables telemetry-related services without breaking system functionality
        
    .PARAMETER MountPath
        Path to the mounted Windows image
    #>
    param(
        [Parameter(Mandatory)]
        [string]$MountPath
    )
    
    Write-Log "Disabling telemetry services..." -Level Info
    
    try {
        # Load SYSTEM hive if not already loaded
        & reg load HKLM\zSYSTEM "$MountPath\Windows\System32\config\SYSTEM" | Out-Null
        
        # Services to disable
        $servicesToDisable = @(
            'DiagTrack',                                    # Connected User Experiences and Telemetry
            'dmwappushservice',                             # WAP Push Message Routing Service
            'MapsBroker',                                   # Downloaded Maps Manager
            'diagnosticshub.standardcollector.service',    # Microsoft Diagnostics Hub Standard Collector Service
            'DPS',                                          # Diagnostic Policy Service
            'WdiServiceHost',                               # Diagnostic Service Host
            'WdiSystemHost',                                # Diagnostic System Host
            'pcasvc'                                        # Program Compatibility Assistant Service
        )
        
        foreach ($service in $servicesToDisable) {
            try {
                & reg add "HKLM\zSYSTEM\ControlSet001\Services\$service" /v Start /t REG_DWORD /d 4 /f | Out-Null
                
                if ($LASTEXITCODE -eq 0) {
                    Write-Log "Disabled service: $service" -Level Info
                }
                else {
                    Write-Log "Service not found: $service (may not exist in this version)" -Level Info
                }
            }
            catch {
                Write-Log "Failed to disable service $service`: $($_.Exception.Message)" -Level Warning
            }
        }
        
        Write-Log "Telemetry services disabled successfully" -Level Success
        return $true
    }
    catch {
        Write-Log "Failed to disable telemetry services: $($_.Exception.Message)" -Level Error
        return $false
    }
    finally {
        # Unload SYSTEM hive
        & reg unload HKLM\zSYSTEM | Out-Null
    }
}

function Remove-TelemetryScheduledTasks {
    <#
    .SYNOPSIS
        Removes telemetry and data collection scheduled tasks
        
    .PARAMETER MountPath
        Path to the mounted Windows image
    #>
    param(
        [Parameter(Mandatory)]
        [string]$MountPath
    )
    
    Write-Log "Removing telemetry scheduled tasks..." -Level Info
    
    try {
        # Load SOFTWARE hive for scheduled tasks
        & reg load HKLM\zSOFTWARE "$MountPath\Windows\System32\config\SOFTWARE" | Out-Null
        
        # Task GUIDs to remove
        $tasksToRemove = @(
            '{0600DD45-FAF2-4131-A006-0B17509B9F78}',  # Application Compatibility Appraiser
            '{4738DE7A-BCC1-4E2D-B1B0-CADB044BFA81}',  # Customer Experience Improvement Program
            '{6FAC31FA-4A85-4E64-BFD5-2154FF4594B3}',  # Customer Experience Improvement Program
            '{FC931F16-B50A-472E-B061-B6F79A71EF59}',  # Customer Experience Improvement Program
            '{0671EB05-7D95-4153-A32B-1426B9FE61DB}',  # Program Data Updater
            '{87BF85F4-2CE1-4160-96EA-52F554AA28A2}',  # Autochk Proxy
            '{8A9C643C-3D74-4099-B6BD-9C6D170898B1}',  # Autochk Proxy
            '{E3176A65-4E44-4ED3-AA73-3283660ACB9C}'   # QueueReporting
        )
        
        foreach ($taskId in $tasksToRemove) {
            try {
                & reg delete "HKLM\zSOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tasks\$taskId" /f | Out-Null
                
                if ($LASTEXITCODE -eq 0) {
                    Write-Log "Removed scheduled task: $taskId" -Level Info
                }
                else {
                    Write-Log "Task not found: $taskId (may not exist)" -Level Info
                }
            }
            catch {
                Write-Log "Failed to remove task $taskId`: $($_.Exception.Message)" -Level Warning
            }
        }
        
        Write-Log "Telemetry scheduled tasks removal completed" -Level Success
        return $true
    }
    catch {
        Write-Log "Failed to remove scheduled tasks: $($_.Exception.Message)" -Level Error
        return $false
    }
    finally {
        # Unload SOFTWARE hive
        & reg unload HKLM\zSOFTWARE | Out-Null
    }
}

function Enable-DotNetFramework35 {
    <#
    .SYNOPSIS
        Enables .NET Framework 3.5 in the Windows image
        
    .PARAMETER MountPath
        Path to the mounted Windows image
    #>
    param(
        [Parameter(Mandatory)]
        [string]$MountPath
    )
    
    Write-Log "Enabling .NET Framework 3.5..." -Level Info
    
    try {
        $sourcePath = Join-Path (Split-Path $MountPath) "..\sources\sxs"
        
        if (Test-Path $sourcePath) {
            & dism /Image:$MountPath /Enable-Feature /FeatureName:NetFX3 /All /Source:$sourcePath | Out-Null
            
            if ($LASTEXITCODE -eq 0) {
                Write-Log ".NET Framework 3.5 enabled successfully" -Level Success
                return $true
            }
            else {
                Write-Log ".NET Framework 3.5 enablement failed (Exit code: $LASTEXITCODE)" -Level Warning
                return $false
            }
        }
        else {
            Write-Log ".NET Framework 3.5 source files not found at: $sourcePath" -Level Warning
            return $false
        }
    }
    catch {
        Write-Log "Failed to enable .NET Framework 3.5: $($_.Exception.Message)" -Level Error
        return $false
    }
}

function Optimize-WinSxSStore {
    <#
    .SYNOPSIS
        Performs advanced WinSxS cleanup to reduce image size
        Using safe WinSxS optimization techniques
        
    .PARAMETER MountPath
        Path to the mounted Windows image
        
    .PARAMETER SkipWinSxS
        Skip WinSxS optimization entirely (for faster processing)
    #>
    param(
        [Parameter(Mandatory)]
        [string]$MountPath,
        
        [switch]$SkipWinSxS
    )
    
    if ($SkipWinSxS) {
        Write-Log "Skipping WinSxS optimization as requested" -Level Info
        return $true
    }
    
    Write-Log "Starting WinSxS optimization..." -Level Info
    
    try {
        # First, analyze current WinSxS size
        Write-Log "Analyzing WinSxS component store..." -Level Info
        
        # Run DISM with timeout and proper output handling
        $dismProcess = Start-Process -FilePath "dism" -ArgumentList "/English", "/Image:$MountPath", "/Cleanup-Image", "/AnalyzeComponentStore" -PassThru -WindowStyle Hidden
        
        # Wait for process completion with timeout (5 minutes)
        $timeoutSeconds = 300
        if (-not $dismProcess.WaitForExit($timeoutSeconds * 1000)) {
            Write-Log "WinSxS analysis timed out after $timeoutSeconds seconds, killing process..." -Level Warning
            $dismProcess.Kill()
            Write-Log "Skipping WinSxS optimization due to timeout" -Level Warning
            return $false
        }
        
        if ($dismProcess.ExitCode -ne 0) {
            Write-Log "WinSxS analysis failed (Exit code: $($dismProcess.ExitCode)), skipping optimization" -Level Warning
            return $false
        }
        
        # Perform standard component cleanup
        Write-Log "Performing standard component cleanup..." -Level Info
        $cleanupProcess = Start-Process -FilePath "dism" -ArgumentList "/English", "/Image:$MountPath", "/Cleanup-Image", "/StartComponentCleanup" -PassThru -WindowStyle Hidden
        
        # Wait for cleanup completion with timeout (10 minutes)
        $cleanupTimeoutSeconds = 600
        if (-not $cleanupProcess.WaitForExit($cleanupTimeoutSeconds * 1000)) {
            Write-Log "Component cleanup timed out after $cleanupTimeoutSeconds seconds, killing process..." -Level Warning
            $cleanupProcess.Kill()
            Write-Log "Standard component cleanup was killed due to timeout" -Level Warning
        }
        elseif ($cleanupProcess.ExitCode -ne 0) {
            Write-Log "Standard component cleanup failed (Exit code: $($cleanupProcess.ExitCode))" -Level Warning
        }
        else {
            Write-Log "Standard component cleanup completed" -Level Success
        }
        
        # Advanced cleanup with ResetBase - DÉSACTIVÉ PAR DÉFAUT
        # IMPORTANT: ResetBase empêche l'installation des packs de langues
        # Cette fonctionnalité va à l'encontre de l'usage normal de Windows
        Write-Log "Skipping ResetBase cleanup to preserve language pack installation capability" -Level Info
        Write-Log "Standard cleanup provides sufficient space reduction while maintaining system serviceability" -Level Info
        
        # Pour les utilisateurs avancés qui veulent quand même utiliser ResetBase,
        # décommenter les lignes ci-dessous EN CONNAISSANCE DE CAUSE :
        <#
        Write-Log "Performing advanced component cleanup with ResetBase..." -Level Warning
        Write-Log "WARNING: This will prevent installation of language packs and new components" -Level Warning
        & dism /Image:$MountPath /Cleanup-Image /StartComponentCleanup /ResetBase | Out-Null
        
        if ($LASTEXITCODE -eq 0) {
            Write-Log "Advanced WinSxS cleanup completed successfully" -Level Success
            Write-Log "WARNING: This image cannot install language packs or new Windows components" -Level Warning
        }
        else {
            Write-Log "Advanced WinSxS cleanup failed (Exit code: $LASTEXITCODE)" -Level Warning
        }
        #>
        
        # Final analysis to show space savings
        Write-Log "Performing final WinSxS analysis..." -Level Info
        $finalAnalysisProcess = Start-Process -FilePath "dism" -ArgumentList "/English", "/Image:$MountPath", "/Cleanup-Image", "/AnalyzeComponentStore" -PassThru -WindowStyle Hidden
        
        # Wait for final analysis with timeout (5 minutes)
        if (-not $finalAnalysisProcess.WaitForExit($timeoutSeconds * 1000)) {
            Write-Log "Final WinSxS analysis timed out after $timeoutSeconds seconds, killing process..." -Level Warning
            $finalAnalysisProcess.Kill()
        }
        
        return $true
    }
    catch {
        Write-Log "WinSxS optimization failed: $($_.Exception.Message)" -Level Error
        return $false
    }
}

function Remove-WindowsRecovery {
    <#
    .SYNOPSIS
        Removes Windows Recovery Environment to save space
        
    .PARAMETER MountPath
        Path to the mounted Windows image
    #>
    param(
        [Parameter(Mandatory)]
        [string]$MountPath
    )
    
    Write-Log "Removing Windows Recovery Environment..." -Level Info
    
    try {
        $winrePath = "$MountPath\Windows\System32\Recovery\winre.wim"
        
        if (Test-Path $winrePath) {
            # Take ownership and set permissions
            & takeown /f "$MountPath\Windows\System32\Recovery" /r | Out-Null
            & icacls "$MountPath\Windows\System32\Recovery" /grant "Administrators:F" /T /C | Out-Null
            
            # Remove the WinRE file and create placeholder
            Remove-Item -Path $winrePath -Force -ErrorAction SilentlyContinue
            New-Item -Path $winrePath -ItemType File -Force | Out-Null
            
            Write-Log "Windows Recovery Environment removed successfully" -Level Success
        }
        else {
            Write-Log "Windows Recovery Environment not found" -Level Info
        }
        
        return $true
    }
    catch {
        Write-Log "Failed to remove Windows Recovery Environment: $($_.Exception.Message)" -Level Error
        return $false
    }
}

function Optimize-ImageSize {
    <#
    .SYNOPSIS
        Performs comprehensive image size optimization
        
    .PARAMETER MountPath
        Path to the mounted Windows image
    #>
    param(
        [Parameter(Mandatory)]
        [string]$MountPath
    )
    
    Write-Log "Starting comprehensive image size optimization..." -Level Info
    
    try {
        # Remove Windows Recovery
        Remove-WindowsRecovery -MountPath $MountPath
        
        # Clean temporary files
        $tempPaths = @(
            "$MountPath\Windows\Temp",
            "$MountPath\Windows\Logs",
            "$MountPath\Windows\Prefetch"
        )
        
        foreach ($tempPath in $tempPaths) {
            if (Test-Path $tempPath) {
                Write-Log "Cleaning temporary files: $tempPath" -Level Info
                Get-ChildItem -Path $tempPath -Recurse -Force -ErrorAction SilentlyContinue | 
                    Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
            }
        }
        
        # Remove unnecessary drivers (keeping essential ones)
        $driversPath = "$MountPath\Windows\System32\DriverStore\FileRepository"
        if (Test-Path $driversPath) {
            Write-Log "Optimizing driver store..." -Level Info
            
            # Get list of potentially removable driver packages
            # NOTE: This is conservative - only remove very specific unnecessary drivers
            $removableDrivers = @(
                '*holographic*',     # HoloLens drivers
                '*hololens*',        # HoloLens drivers
                '*onecore_iot*'      # IoT-specific drivers
            )
            
            foreach ($driverPattern in $removableDrivers) {
                $driversToRemove = Get-ChildItem -Path $driversPath -Directory -Name -Filter $driverPattern -ErrorAction SilentlyContinue
                
                foreach ($driver in $driversToRemove) {
                    try {
                        $driverPath = Join-Path $driversPath $driver
                        Write-Log "Removing unnecessary driver: $driver" -Level Info
                        Remove-Item -Path $driverPath -Recurse -Force -ErrorAction SilentlyContinue
                    }
                    catch {
                        Write-Log "Failed to remove driver $driver`: $($_.Exception.Message)" -Level Warning
                    }
                }
            }
        }
        
        Write-Log "Image size optimization completed" -Level Success
        return $true
    }
    catch {
        Write-Log "Image size optimization failed: $($_.Exception.Message)" -Level Error
        return $false
    }
}

function Set-AdvancedSystemOptimizations {
    <#
    .SYNOPSIS
        Applies advanced system optimizations for better performance
        
    .PARAMETER MountPath
        Path to the mounted Windows image
    #>
    param(
        [Parameter(Mandatory)]
        [string]$MountPath
    )
    
    Write-Log "Applying advanced system optimizations..." -Level Info
    
    try {
        # Load SYSTEM registry hive
        & reg load HKLM\zSYSTEM "$MountPath\Windows\System32\config\SYSTEM" | Out-Null
        
        # Optimize system services for better performance
        $serviceOptimizations = @{
            'Fax' = 4                           # Disable Fax service
            'SharedAccess' = 4                  # Disable Internet Connection Sharing
            'TapiSrv' = 4                       # Disable Telephony service
            'TermService' = 4                   # Disable Remote Desktop (can be re-enabled)
            'Themes' = 2                        # Keep Themes service (needed for basic UI)
            'AudioSrv' = 2                      # Keep Audio service
            'AudioEndpointBuilder' = 2          # Keep Audio Endpoint Builder
            'BITS' = 3                          # Set BITS to manual (needed for Windows Update)
            'wuauserv' = 2                      # Keep Windows Update service (automatic)
        }
        
        foreach ($service in $serviceOptimizations.GetEnumerator()) {
            try {
                & reg add "HKLM\zSYSTEM\ControlSet001\Services\$($service.Key)" /v Start /t REG_DWORD /d $service.Value /f | Out-Null
                Write-Log "Optimized service: $($service.Key) -> $($service.Value)" -Level Info
            }
            catch {
                Write-Log "Failed to optimize service $($service.Key): $($_.Exception.Message)" -Level Warning
            }
        }
        
        Write-Log "Advanced system optimizations applied successfully" -Level Success
        return $true
    }
    catch {
        Write-Log "Advanced system optimizations failed: $($_.Exception.Message)" -Level Error
        return $false
    }
    finally {
        # Unload SYSTEM hive
        & reg unload HKLM\zSYSTEM | Out-Null
    }
}

function Remove-EdgeBrowser {
    <#
    .SYNOPSIS
        Removes Microsoft Edge browser from the mounted image
        Moved from AppxPackageManager.ps1 for better organization
        
    .PARAMETER MountPath
        Path to the mounted Windows image
        
    .PARAMETER Architecture
        System architecture (amd64 or arm64)
    #>
    param(
        [Parameter(Mandatory)]
        [string]$MountPath,
        
        [Parameter(Mandatory)]
        [string]$Architecture
    )
    
    Write-Log "Removing Microsoft Edge browser..." -Level Info
    
    try {
        # Remove Edge directories
        $edgePaths = @(
            "$MountPath\Program Files (x86)\Microsoft\Edge",
            "$MountPath\Program Files (x86)\Microsoft\EdgeUpdate", 
            "$MountPath\Program Files (x86)\Microsoft\EdgeCore"
        )
        
        foreach ($path in $edgePaths) {
            if (Test-Path $path) {
                Write-Log "Removing Edge directory: $path" -Level Info
                Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
        
        # Remove Edge WebView based on architecture
        $webviewPattern = if ($Architecture -eq 'amd64') {
            "amd64_microsoft-edge-webview_31bf3856ad364e35*"
        }
        elseif ($Architecture -eq 'arm64') {
            "arm64_microsoft-edge-webview_31bf3856ad364e35*"
        }
        else {
            Write-Log "Unknown architecture: $Architecture" -Level Warning
            return $false
        }
        
        $webviewPath = Get-ChildItem -Path "$MountPath\Windows\WinSxS" -Filter $webviewPattern -Directory -ErrorAction SilentlyContinue
        if ($webviewPath) {
            foreach ($path in $webviewPath) {
                Write-Log "Removing Edge WebView: $($path.FullName)" -Level Info
                & takeown /f $path.FullName /r | Out-Null
                & icacls $path.FullName /grant "Administrators:(F)" /T /C | Out-Null
                Remove-Item -Path $path.FullName -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
        
        # Remove Edge WebView system directory
        $systemWebViewPath = "$MountPath\Windows\System32\Microsoft-Edge-Webview"
        if (Test-Path $systemWebViewPath) {
            Write-Log "Removing system Edge WebView directory" -Level Info
            & takeown /f $systemWebViewPath /r | Out-Null
            & icacls $systemWebViewPath /grant "Administrators:(F)" /T /C | Out-Null
            Remove-Item -Path $systemWebViewPath -Recurse -Force -ErrorAction SilentlyContinue
        }
        
        Write-Log "Microsoft Edge browser removal completed" -Level Success
        return $true
    }
    catch {
        Write-Log "Edge removal failed: $($_.Exception.Message)" -Level Error
        return $false
    }
}

function Remove-OneDrive {
    <#
    .SYNOPSIS
        Removes OneDrive setup from the mounted image
        Moved from AppxPackageManager.ps1 for better organization
        
    .PARAMETER MountPath
        Path to the mounted Windows image
    #>
    param(
        [Parameter(Mandatory)]
        [string]$MountPath
    )
    
    Write-Log "Removing OneDrive setup..." -Level Info
    
    try {
        $oneDriveSetup = "$MountPath\Windows\System32\OneDriveSetup.exe"
        
        if (Test-Path $oneDriveSetup) {
            & takeown /f $oneDriveSetup | Out-Null
            & icacls $oneDriveSetup /grant "Administrators:(F)" /T /C | Out-Null
            Remove-Item -Path $oneDriveSetup -Force -ErrorAction SilentlyContinue
            Write-Log "OneDrive setup removed successfully" -Level Success
        }
        else {
            Write-Log "OneDrive setup not found" -Level Info
        }
        
        return $true
    }
    catch {
        Write-Log "OneDrive removal failed: $($_.Exception.Message)" -Level Error
        return $false
    }
}