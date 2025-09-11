#requires -Version 5.1

<#
.SYNOPSIS
    System Optimization for Tiny11 Advanced
    
.DESCRIPTION
    Handles system-level optimizations including services management,
    scheduled tasks removal, and WinSxS cleanup
#>

function Wait-ForProcessWithSkip {
    <#
    .SYNOPSIS
        Waits for a process with interactive skip capability
        
    .PARAMETER Process
        The process to wait for
        
    .PARAMETER TimeoutSeconds
        Maximum time to wait in seconds
        
    .PARAMETER TaskName
        Name of the task for user messages
    #>
    param(
        [Parameter(Mandatory)]
        [System.Diagnostics.Process]$Process,
        
        [Parameter(Mandatory)]
        [int]$TimeoutSeconds,
        
        [Parameter(Mandatory)]
        [string]$TaskName
    )
    
    $startTime = Get-Date
    $lastProgress = $startTime
    
    while (-not $Process.HasExited) {
        $elapsed = (Get-Date) - $startTime
        
        # Show progress every 30 seconds
        if (((Get-Date) - $lastProgress).TotalSeconds -ge 30) {
            $remainingTime = $TimeoutSeconds - [int]$elapsed.TotalSeconds
            if ($remainingTime -gt 0) {
                Write-Log "Still working on $TaskName... ${remainingTime}s remaining (Press 'S' to skip)" -Level Info
            }
            $lastProgress = Get-Date
        }
        
        # Check for user input to skip
        if ([System.Console]::KeyAvailable) {
            $key = [System.Console]::ReadKey($true)
            if ($key.Key -eq 'S' -or $key.Key -eq 's') {
                Write-Log "User requested to skip $TaskName" -Level Info
                if (-not $Process.HasExited) {
                    $Process.Kill()
                    $Process.WaitForExit(5000)  # Wait up to 5 seconds for graceful exit
                }
                return $true  # User skipped
            }
        }
        
        # Check timeout
        if ($elapsed.TotalSeconds -ge $TimeoutSeconds) {
            break  # Timeout reached
        }
        
        Start-Sleep -Milliseconds 500  # Check every 500ms
    }
    
    return $false  # Not skipped by user
}

function Wait-ForProcessNoTimeout {
    <#
    .SYNOPSIS
        Waits for a process indefinitely with interactive skip capability only
        
    .PARAMETER Process
        The process to wait for
        
    .PARAMETER TaskName
        Name of the task for user messages
    #>
    param(
        [Parameter(Mandatory)]
        [System.Diagnostics.Process]$Process,
        
        [Parameter(Mandatory)]
        [string]$TaskName
    )
    
    $startTime = Get-Date
    $lastProgress = $startTime
    
    while (-not $Process.HasExited) {
        $elapsed = (Get-Date) - $startTime
        
        # Show progress every 30 seconds
        if (((Get-Date) - $lastProgress).TotalSeconds -ge 30) {
            $elapsedMinutes = [math]::Floor($elapsed.TotalMinutes)
            Write-Log "Still working on $TaskName... ${elapsedMinutes} minutes elapsed (Press 'S' to skip)" -Level Info
            $lastProgress = Get-Date
        }
        
        # Check for user input to skip
        if ([System.Console]::KeyAvailable) {
            $key = [System.Console]::ReadKey($true)
            if ($key.Key -eq 'S' -or $key.Key -eq 's') {
                Write-Log "User requested to skip $TaskName" -Level Info
                if (-not $Process.HasExited) {
                    $Process.Kill()
                    $Process.WaitForExit(5000)  # Wait up to 5 seconds for graceful exit
                }
                return $true  # User skipped
            }
        }
        
        Start-Sleep -Milliseconds 500  # Check every 500ms
    }
    
    return $false  # Not skipped by user
}

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
        
    .PARAMETER AggressiveWinSxS
        Enable aggressive WinSxS cleanup with /ResetBase (WARNING: breaks language packs)
    #>
    param(
        [Parameter(Mandatory)]
        [string]$MountPath,
        
        [switch]$EnableDotNet35,
        
        [switch]$SkipWinSxS,
        
        [switch]$AggressiveWinSxS
    )
    
    Write-Log "Starting system optimization process..." -Level Info
    
    try {
        # Remove Microsoft Edge browser
        $architecture = Get-SystemArchitecture -MountPath $MountPath
        Remove-EdgeBrowser -MountPath $MountPath -Architecture $architecture
        
        # Remove OneDrive setup
        Remove-OneDrive -MountPath $MountPath
        
        # Remove additional system files and components
        Remove-AdditionalSystemFiles -MountPath $MountPath
        
        # Remove Features on Demand (optional Windows capabilities)
        Remove-FeaturesOnDemand -MountPath $MountPath
        
        # Disable telemetry services
        Disable-TelemetryServices -MountPath $MountPath
        
        # Remove scheduled tasks
        Remove-TelemetryScheduledTasks -MountPath $MountPath
        
        # Enable .NET 3.5 if requested
        if ($EnableDotNet35) {
            Enable-DotNetFramework35 -MountPath $MountPath
        }
        
        # Optimize WinSxS (advanced cleanup)
        Optimize-WinSxSStore -MountPath $MountPath -SkipWinSxS:$SkipWinSxS -AggressiveWinSxS:$AggressiveWinSxS
        
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
        Disables telemetry-related services for Windows 11 24H2 without breaking system functionality
        Updated with improved permission handling and Windows 11 24H2 service compatibility
        
    .PARAMETER MountPath
        Path to the mounted Windows image
    #>
    param(
        [Parameter(Mandatory)]
        [string]$MountPath
    )
    
    Write-Log "Disabling telemetry services for Windows 11 24H2..." -Level Info
    
    try {
        # Enhanced SYSTEM hive loading with permission handling
        $systemHivePath = "$MountPath\Windows\System32\config\SYSTEM"
        if (-not (Test-Path $systemHivePath)) {
            Write-Log "SYSTEM hive not found at $systemHivePath" -Level Error
            return $false
        }
        
        # Force unload any existing hive to prevent conflicts
        & reg unload HKLM\zSYSTEM 2>&1 | Out-Null
        Start-Sleep -Seconds 1
        
        Write-Log "Loading SYSTEM hive for service configuration..." -Level Info
        $loadResult = & reg load HKLM\zSYSTEM "$systemHivePath" 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Log "Failed to load SYSTEM hive, attempting permission fix..." -Level Warning
            # Try to fix permissions
            & takeown /f "$systemHivePath" /a 2>&1 | Out-Null
            & icacls "$systemHivePath" /grant "Administrators:(F)" 2>&1 | Out-Null
            
            $loadResult = & reg load HKLM\zSYSTEM "$systemHivePath" 2>&1
            if ($LASTEXITCODE -ne 0) {
                Write-Log "Failed to load SYSTEM hive after permission fix: $loadResult" -Level Error
                return $false
            }
        }
        
        # Wait for hive to be fully loaded
        Start-Sleep -Seconds 2
        
        # Updated services list for Windows 11 24H2 (including AI and new telemetry services)
        $servicesToDisable = @(
            'DiagTrack',                                    # Connected User Experiences and Telemetry (primary telemetry service)
            'dmwappushservice',                             # WAP Push Message Routing Service
            'MapsBroker',                                   # Downloaded Maps Manager
            'diagnosticshub.standardcollector.service',    # Microsoft Diagnostics Hub Standard Collector Service
            'pcasvc',                                       # Program Compatibility Assistant Service
            'PcaSvc',                                       # Program Compatibility Assistant Service (alternative name)
            'AIFabricService',                              # AI Fabric Service (2024-2025)
            'AdjustService',                                # User experience telemetry (2024-2025)
            'MessagingService',                             # Messaging services (Teams/Chat integration)
            'PimIndexMaintenanceSvc',                       # Cortana data indexing service
            'CopilotService'                                # Windows Copilot service (2024-2025)
        )
        
        # Services that may not exist in Windows 11 24H2 but should be checked
        $conditionalServices = @(
            'DPS',                                          # Diagnostic Policy Service (may not exist)
            'WdiServiceHost',                               # Diagnostic Service Host (may not exist)
            'WdiSystemHost',                                # Diagnostic System Host (may not exist)
            'MessagingService_*',                           # Pattern for messaging services
            'PimIndexMaintenanceSvc_*'                      # Pattern for PIM services
        )
        
        $disabledCount = 0
        $notFoundCount = 0
        
        # Process primary telemetry services
        foreach ($service in $servicesToDisable) {
            try {
                # Check if service exists first
                $serviceKey = "HKLM\zSYSTEM\ControlSet001\Services\$service"
                $checkResult = & reg query "$serviceKey" 2>&1
                
                if ($LASTEXITCODE -eq 0) {
                    # Service exists, disable it (set Start = 4 for disabled)
                    $disableResult = & reg add "$serviceKey" /v Start /t REG_DWORD /d 4 /f 2>&1
                    
                    if ($LASTEXITCODE -eq 0) {
                        Write-Log "Disabled service: $service" -Level Info
                        $disabledCount++
                    } else {
                        Write-Log "Failed to disable service $service : $disableResult" -Level Warning
                    }
                } else {
                    Write-Log "Service not found: $service (may not exist in Windows 11 24H2)" -Level Info
                    $notFoundCount++
                }
            }
            catch {
                Write-Log "Failed to process service $service : $($_.Exception.Message)" -Level Warning
            }
        }
        
        # Process conditional services (those that may not exist in newer Windows versions)
        foreach ($service in $conditionalServices) {
            try {
                $serviceKey = "HKLM\zSYSTEM\ControlSet001\Services\$service"
                $checkResult = & reg query "$serviceKey" 2>&1
                
                if ($LASTEXITCODE -eq 0) {
                    $disableResult = & reg add "$serviceKey" /v Start /t REG_DWORD /d 4 /f 2>&1
                    
                    if ($LASTEXITCODE -eq 0) {
                        Write-Log "Disabled conditional service: $service" -Level Info
                        $disabledCount++
                    } else {
                        Write-Log "Failed to disable conditional service $service : $disableResult" -Level Warning
                    }
                } else {
                    Write-Log "Conditional service not found: $service (expected in Windows 11 24H2)" -Level Info
                    $notFoundCount++
                }
            }
            catch {
                Write-Log "Failed to process conditional service $service : $($_.Exception.Message)" -Level Warning
            }
        }
        
        # Also disable in ControlSet002 if it exists (for completeness)
        Write-Log "Checking ControlSet002 for additional service instances..." -Level Info
        $controlSet002Path = "HKLM\zSYSTEM\ControlSet002"
        $cs2CheckResult = & reg query "$controlSet002Path" 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            foreach ($service in $servicesToDisable) {
                try {
                    $serviceKey = "$controlSet002Path\Services\$service"
                    $checkResult = & reg query "$serviceKey" 2>&1
                    
                    if ($LASTEXITCODE -eq 0) {
                        & reg add "$serviceKey" /v Start /t REG_DWORD /d 4 /f 2>&1 | Out-Null
                        if ($LASTEXITCODE -eq 0) {
                            Write-Log "Disabled service in ControlSet002: $service" -Level Info
                        }
                    }
                } catch {
                    # Silently continue for ControlSet002 errors
                }
            }
        }
        
        if ($disabledCount -gt 0) {
            Write-Log "Telemetry services configuration completed - Disabled: $disabledCount, Not found: $notFoundCount" -Level Success
        } else {
            Write-Log "No telemetry services were disabled (all services may have been already disabled or not present)" -Level Warning
        }
        
        return $true
    }
    catch {
        Write-Log "Failed to disable telemetry services: $($_.Exception.Message)" -Level Error
        return $false
    }
    finally {
        # Enhanced SYSTEM hive unloading
        try {
            Write-Log "Unloading SYSTEM hive..." -Level Info
            
            # Force garbage collection to release registry handles
            [GC]::Collect()
            [GC]::WaitForPendingFinalizers()
            
            Start-Sleep -Seconds 2
            
            $unloadResult = & reg unload HKLM\zSYSTEM 2>&1
            if ($LASTEXITCODE -ne 0) {
                Write-Log "First SYSTEM hive unload attempt failed, retrying..." -Level Warning
                Start-Sleep -Seconds 3
                $unloadResult = & reg unload HKLM\zSYSTEM 2>&1
                
                if ($LASTEXITCODE -ne 0) {
                    Write-Log "Warning: Failed to cleanly unload SYSTEM hive: $unloadResult" -Level Warning
                }
            } else {
                Write-Log "SYSTEM hive unloaded successfully" -Level Success
            }
        } catch {
            Write-Log "Error during SYSTEM hive unload: $($_.Exception.Message)" -Level Warning
        }
    }
}

function Remove-TelemetryScheduledTasks {
    <#
    .SYNOPSIS
        Removes telemetry and data collection scheduled tasks for Windows 11 24H2
        Updated with modern task detection method based on task names rather than obsolete GUIDs
        
    .PARAMETER MountPath
        Path to the mounted Windows image
    #>
    param(
        [Parameter(Mandatory)]
        [string]$MountPath
    )
    
    Write-Log "Removing telemetry scheduled tasks for Windows 11 24H2..." -Level Info
    
    try {
        # Improved registry hive loading with better error handling
        $softwareHivePath = "$MountPath\Windows\System32\config\SOFTWARE"
        if (-not (Test-Path $softwareHivePath)) {
            Write-Log "SOFTWARE hive not found at $softwareHivePath" -Level Warning
            return $false
        }

        # Force unload any existing hive to prevent conflicts
        & reg unload HKLM\zSOFTWARE 2>&1 | Out-Null
        Start-Sleep -Seconds 1
        
        # Load SOFTWARE hive with enhanced permissions
        Write-Log "Loading SOFTWARE hive for task analysis..." -Level Info
        $loadResult = & reg load HKLM\zSOFTWARE "$softwareHivePath" 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Log "Failed to load SOFTWARE hive: $loadResult" -Level Warning
            # Try alternative approach with takeown
            & takeown /f "$softwareHivePath" /a 2>&1 | Out-Null
            & icacls "$softwareHivePath" /grant "Administrators:(F)" 2>&1 | Out-Null
            
            $loadResult = & reg load HKLM\zSOFTWARE "$softwareHivePath" 2>&1
            if ($LASTEXITCODE -ne 0) {
                Write-Log "Failed to load SOFTWARE hive after permission fix: $loadResult" -Level Error
                return $false
            }
        }
        
        # Wait for hive to be fully loaded
        Start-Sleep -Seconds 3
        
        # Modern Windows 11 24H2 telemetry tasks based on research
        # Using task path-based detection instead of obsolete GUIDs
        $telemetryTaskPaths = @(
            # Application Experience tasks
            "Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser",
            "Microsoft\Windows\Application Experience\ProgramDataUpdater", 
            "Microsoft\Windows\Application Experience\StartupAppTask",
            "Microsoft\Windows\Application Experience\AitAgent",
            "Microsoft\Windows\Application Experience\PcaPatchDbTask",
            
            # Customer Experience Improvement Program tasks
            "Microsoft\Windows\Customer Experience Improvement Program\Consolidator",
            "Microsoft\Windows\Customer Experience Improvement Program\UsbCeip",
            "Microsoft\Windows\Customer Experience Improvement Program\KernelCeipTask",
            
            # Disk Diagnostic telemetry
            "Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector",
            
            # Autochk SQM data collection
            "Microsoft\Windows\Autochk\Proxy"
        )

        $removedCount = 0
        $taskRegistryBase = "HKLM\zSOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache"
        
        # First, discover actual task GUIDs by scanning the Tree structure
        Write-Log "Discovering telemetry task GUIDs in Windows 11 24H2 image..." -Level Info
        $discoveredTasks = @()
        
        foreach ($taskPath in $telemetryTaskPaths) {
            try {
                $treeKey = "$taskRegistryBase\Tree\$taskPath"
                $queryResult = & reg query "$treeKey" /v "Id" 2>&1
                
                if ($LASTEXITCODE -eq 0) {
                    # Extract GUID from registry output
                    $guidMatch = [regex]::Match($queryResult, '\{[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}\}')
                    if ($guidMatch.Success) {
                        $taskGuid = $guidMatch.Value
                        $discoveredTasks += @{
                            Path = $taskPath
                            GUID = $taskGuid
                            TreeKey = $treeKey
                            TaskKey = "$taskRegistryBase\Tasks\$taskGuid"
                        }
                        Write-Log "Discovered telemetry task: $taskPath -> $taskGuid" -Level Info
                    }
                } else {
                    Write-Log "Telemetry task not found: $taskPath (may not exist in this Windows version)" -Level Info
                }
            }
            catch {
                Write-Log "Error discovering task $taskPath : $($_.Exception.Message)" -Level Warning
            }
        }
        
        # Remove discovered telemetry tasks
        Write-Log "Removing $($discoveredTasks.Count) discovered telemetry tasks..." -Level Info
        
        foreach ($task in $discoveredTasks) {
            try {
                $taskRemoved = $false
                
                # Remove from Tasks key (main task definition)
                if (Test-Path "Registry::$($task.TaskKey)") {
                    $deleteResult = & reg delete "$($task.TaskKey)" /f 2>&1
                    if ($LASTEXITCODE -eq 0) {
                        Write-Log "Removed task definition: $($task.Path)" -Level Success
                        $taskRemoved = $true
                    } else {
                        Write-Log "Failed to remove task definition $($task.Path): $deleteResult" -Level Warning
                    }
                }
                
                # Remove from Tree key (task registration)
                $deleteResult = & reg delete "$($task.TreeKey)" /f 2>&1
                if ($LASTEXITCODE -eq 0) {
                    Write-Log "Removed task registration: $($task.Path)" -Level Success
                    $taskRemoved = $true
                } else {
                    Write-Log "Failed to remove task registration $($task.Path): $deleteResult" -Level Warning
                }
                
                # Remove from trigger-specific keys if they exist
                $triggerKeys = @(
                    "$taskRegistryBase\Logon\$($task.GUID)",
                    "$taskRegistryBase\Plain\$($task.GUID)", 
                    "$taskRegistryBase\Boot\$($task.GUID)"
                )
                
                foreach ($triggerKey in $triggerKeys) {
                    $checkResult = & reg query "$triggerKey" 2>&1
                    if ($LASTEXITCODE -eq 0) {
                        $deleteResult = & reg delete "$triggerKey" /f 2>&1
                        if ($LASTEXITCODE -eq 0) {
                            Write-Log "Removed trigger key for: $($task.Path)" -Level Success
                        }
                    }
                }
                
                if ($taskRemoved) {
                    $removedCount++
                }
            }
            catch {
                Write-Log "Failed to process task $($task.Path): $($_.Exception.Message)" -Level Warning
            }
        }
        
        # Also remove XML task files if they exist in the mounted image
        $tasksXmlPath = "$MountPath\Windows\System32\Tasks"
        if (Test-Path $tasksXmlPath) {
            Write-Log "Removing telemetry task XML files..." -Level Info
            
            foreach ($taskPath in $telemetryTaskPaths) {
                try {
                    $xmlTaskPath = Join-Path $tasksXmlPath $taskPath
                    if (Test-Path $xmlTaskPath) {
                        Remove-Item -Path $xmlTaskPath -Force -ErrorAction SilentlyContinue
                        Write-Log "Removed XML task file: $taskPath" -Level Success
                    }
                }
                catch {
                    Write-Log "Failed to remove XML task file $taskPath : $($_.Exception.Message)" -Level Warning
                }
            }
        }
        
        if ($removedCount -gt 0) {
            Write-Log "Telemetry scheduled tasks removal completed - Successfully removed: $removedCount tasks" -Level Success
        } else {
            Write-Log "No telemetry tasks found to remove (clean Windows 11 24H2 image or tasks already removed)" -Level Info
        }
        
        return $true
    }
    catch {
        Write-Log "Failed to remove scheduled tasks: $($_.Exception.Message)" -Level Error
        return $false
    }
    finally {
        # Enhanced hive unloading with multiple retry attempts
        try {
            Write-Log "Unloading SOFTWARE hive..." -Level Info
            
            # Force garbage collection to release registry handles
            [GC]::Collect()
            [GC]::WaitForPendingFinalizers()
            [GC]::Collect()
            
            Start-Sleep -Seconds 2
            
            # Attempt graceful unload
            $unloadResult = & reg unload HKLM\zSOFTWARE 2>&1
            if ($LASTEXITCODE -ne 0) {
                Write-Log "First unload attempt failed, trying alternative method..." -Level Warning
                
                # Force close any remaining handles and retry
                Start-Sleep -Seconds 3
                $unloadResult = & reg unload HKLM\zSOFTWARE 2>&1
                
                if ($LASTEXITCODE -ne 0) {
                    Write-Log "Warning: Failed to cleanly unload SOFTWARE hive: $unloadResult" -Level Warning
                    Write-Log "This may not affect the final image integrity" -Level Info
                }
            } else {
                Write-Log "SOFTWARE hive unloaded successfully" -Level Success
            }
        } catch {
            Write-Log "Error during hive unload: $($_.Exception.Message)" -Level Warning
        }
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
        
    .PARAMETER AggressiveWinSxS
        Enable aggressive WinSxS cleanup with /ResetBase (WARNING: breaks language packs and updates)
    #>
    param(
        [Parameter(Mandatory)]
        [string]$MountPath,
        
        [switch]$SkipWinSxS,
        
        [switch]$AggressiveWinSxS
    )
    
    if ($SkipWinSxS) {
        Write-Log "Skipping WinSxS optimization as requested" -Level Info
        return $true
    }
    
    Write-Log "Starting WinSxS optimization..." -Level Info
    Write-Log "Press 'S' at any time to SKIP WinSxS optimization and continue with the build process" -Level Info
    
    try {
        # First, analyze current WinSxS size
        Write-Log "Analyzing WinSxS component store..." -Level Info
        Write-Log "This may take several minutes. Press 'S' to skip if it takes too long." -Level Info
        Write-Log "DISM output will appear below. Wait for progress updates every 30 seconds..." -Level Info
        
        # Run DISM with timeout and visible output for user feedback
        $dismProcess = Start-Process -FilePath "dism" -ArgumentList "/English", "/Image:$MountPath", "/Cleanup-Image", "/AnalyzeComponentStore" -PassThru -NoNewWindow
        
        # Wait for process completion without timeout (only user skip)
        $skipped = Wait-ForProcessNoTimeout -Process $dismProcess -TaskName "WinSxS analysis"
        
        if ($skipped) {
            Write-Log "WinSxS optimization skipped by user" -Level Info
            return $true
        }
        
        # Process should be finished since Wait-ForProcessNoTimeout only returns when done or skipped
        
        if ($dismProcess.ExitCode -ne 0) {
            Write-Log "WinSxS analysis failed (Exit code: $($dismProcess.ExitCode)), skipping optimization" -Level Warning
            return $false
        }
        
        # Perform standard component cleanup
        Write-Log "Performing standard component cleanup..." -Level Info
        Write-Log "This is the longest step. Press 'S' to skip if it takes too long." -Level Info
        Write-Log "DISM cleanup in progress. Progress updates will appear every 30 seconds..." -Level Info
        $cleanupProcess = Start-Process -FilePath "dism" -ArgumentList "/English", "/Image:$MountPath", "/Cleanup-Image", "/StartComponentCleanup" -PassThru -NoNewWindow
        
        # Wait for cleanup completion without timeout (only user skip)
        $skipped = Wait-ForProcessNoTimeout -Process $cleanupProcess -TaskName "component cleanup"
        
        if ($skipped) {
            Write-Log "WinSxS cleanup skipped by user during component cleanup" -Level Info
            return $true
        }
        
        # Process should be finished since Wait-ForProcessNoTimeout only returns when done or skipped
        if ($cleanupProcess.ExitCode -ne 0) {
            Write-Log "Standard component cleanup failed (Exit code: $($cleanupProcess.ExitCode))" -Level Warning
        }
        else {
            Write-Log "Standard component cleanup completed" -Level Success
        }
        
        # Advanced cleanup with ResetBase (AGGRESSIVE OPTION)
        if ($AggressiveWinSxS) {
            Write-Log "AGGRESSIVE OPTION ENABLED: Performing ResetBase cleanup..." -Level Warning
            Write-Log "⚠️  CRITICAL WARNING: This will break Windows Update and language pack installation!" -Level Warning
            Write-Log "⚠️  The resulting image cannot receive updates or install new Windows components!" -Level Warning
            Write-Log "⚠️  Use this option ONLY if you understand the consequences!" -Level Warning
            Write-Log "Performing advanced component cleanup with ResetBase..." -Level Warning
            
            $resetbaseProcess = Start-Process -FilePath "dism" -ArgumentList "/English", "/Image:$MountPath", "/Cleanup-Image", "/StartComponentCleanup", "/ResetBase" -PassThru -NoNewWindow
            
            # Wait for ResetBase completion without timeout (only user skip)
            $skipped = Wait-ForProcessNoTimeout -Process $resetbaseProcess -TaskName "ResetBase cleanup"
            
            if ($skipped) {
                Write-Log "ResetBase cleanup skipped by user" -Level Info
            }
            elseif ($resetbaseProcess.ExitCode -eq 0) {
                Write-Log "🎯 AGGRESSIVE WinSxS cleanup completed successfully" -Level Success
                Write-Log "💥 Image size reduced by approximately 800MB-1.2GB" -Level Success
                Write-Log "⚠️  WARNING: This image CANNOT install language packs or receive certain Windows updates!" -Level Warning
            }
            else {
                Write-Log "ResetBase cleanup failed (Exit code: $($resetbaseProcess.ExitCode))" -Level Warning
            }
        }
        else {
            Write-Log "Skipping ResetBase cleanup to preserve Windows Update and language pack capability" -Level Info
            Write-Log "💡 Use -AggressiveWinSxS parameter for maximum size reduction (with risks)" -Level Info
        }
        
        # Final analysis to show space savings
        Write-Log "Performing final WinSxS analysis..." -Level Info
        $finalAnalysisProcess = Start-Process -FilePath "dism" -ArgumentList "/English", "/Image:$MountPath", "/Cleanup-Image", "/AnalyzeComponentStore" -PassThru -NoNewWindow
        
        # Wait for final analysis without timeout (only user skip)
        $skipped = Wait-ForProcessNoTimeout -Process $finalAnalysisProcess -TaskName "final analysis"
        
        if ($skipped) {
            Write-Log "Final analysis skipped by user" -Level Info
        }
        # Process should be finished since Wait-ForProcessNoTimeout only returns when done or skipped
        
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

function Remove-FeaturesOnDemand {
    <#
    .SYNOPSIS
        Removes unused Features on Demand to reduce image size
        
    .PARAMETER MountPath
        Path to the mounted Windows image
    #>
    param(
        [Parameter(Mandatory)]
        [string]$MountPath
    )
    
    Write-Log "Starting Features on Demand removal..." -Level Info
    
    try {
        # List of Features on Demand that are commonly unused and safe to remove
        $fodToRemove = @(
            'App.StepsRecorder~~~~0.0.1.0',          # Steps Recorder
            'App.Support.QuickAssist~~~~0.0.1.0',    # Quick Assist
            'Browser.InternetExplorer~~~~0.0.11.0',  # Internet Explorer mode
            'Hello.Face.17658~~~~0.0.1.0',           # Windows Hello Face
            'Language.Handwriting~~~en-US~0.0.1.0',  # Handwriting recognition
            'Language.OCR~~~en-US~0.0.1.0',          # Optical character recognition
            'Language.Speech~~~en-US~0.0.1.0',       # Speech recognition
            'Language.TextToSpeech~~~en-US~0.0.1.0', # Text-to-speech
            'MathRecognizer~~~~0.0.1.0',             # Math Recognizer
            'Media.WindowsMediaPlayer~~~~0.0.12.0',  # Windows Media Player Legacy
            'Microsoft.Windows.MSPaint~~~~0.0.1.0',  # Paint
            'Microsoft.Windows.Notepad~~~~0.0.1.0',  # Notepad
            'Microsoft.Windows.PowerShell.ISE~~~~0.0.1.0',  # PowerShell ISE
            'Microsoft.Windows.WordPad~~~~0.0.1.0',  # WordPad
            'OpenSSH.Client~~~~0.0.1.0',             # OpenSSH Client
            'Print.Fax.Scan~~~~0.0.1.0',             # Windows Fax and Scan
            'Print.Management.Console~~~~0.0.1.0',   # Print Management Console
            'Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0',  # RSAT tools
            'Rsat.CertificateServices.Tools~~~~0.0.1.0',
            'Rsat.DHCP.Tools~~~~0.0.1.0',
            'Rsat.Dns.Tools~~~~0.0.1.0',
            'Rsat.FileServices.Tools~~~~0.0.1.0',
            'Rsat.GroupPolicy.Management.Tools~~~~0.0.1.0',
            'Rsat.ServerManager.Tools~~~~0.0.1.0',
            'WMI-SNMP-Provider.Client~~~~0.0.1.0',   # SNMP WMI Provider
            'XPS.Viewer~~~~0.0.1.0'                  # XPS Viewer
        )
        
        Write-Log "Checking available Features on Demand..." -Level Info
        $dismOutput = & dism /English /Image:$MountPath /Get-Capabilities 2>&1
        
        # Parse available capabilities
        $availableCapabilities = @()
        foreach ($line in $dismOutput) {
            if ($line -match '^Capability Identity\s*:\s*(.+)$') {
                $capabilityName = $matches[1].Trim()
                if (-not [string]::IsNullOrEmpty($capabilityName)) {
                    $availableCapabilities += $capabilityName
                }
            }
        }
        
        Write-Log "Found $($availableCapabilities.Count) total capabilities in image" -Level Info
        
        $removedCount = 0
        $failedCount = 0
        
        foreach ($feature in $fodToRemove) {
            # Check if the exact capability exists
            $exactMatch = $availableCapabilities | Where-Object { $_ -eq $feature }
            if ($exactMatch) {
                try {
                    Write-Log "Removing FOD: $feature" -Level Info
                    $dismResult = & dism /English /Image:$MountPath /Remove-Capability /CapabilityName:$feature 2>&1
                    
                    if ($LASTEXITCODE -eq 0) {
                        Write-Log "Successfully removed: $feature" -Level Success
                        $removedCount++
                    }
                    else {
                        Write-Log "Failed to remove: $feature (Exit code: $LASTEXITCODE)" -Level Warning
                        $failedCount++
                    }
                }
                catch {
                    Write-Log "Error removing FOD $feature`: $($_.Exception.Message)" -Level Warning
                    $failedCount++
                }
            }
            else {
                # Check for partial matches (version differences)
                $partialMatch = $availableCapabilities | Where-Object { $_ -like "$($feature.Split('~')[0])*" }
                if ($partialMatch) {
                    try {
                        Write-Log "Removing FOD (version match): $partialMatch" -Level Info
                        $dismResult = & dism /English /Image:$MountPath /Remove-Capability /CapabilityName:$partialMatch 2>&1
                        
                        if ($LASTEXITCODE -eq 0) {
                            Write-Log "Successfully removed: $partialMatch" -Level Success
                            $removedCount++
                        }
                        else {
                            Write-Log "Failed to remove: $partialMatch (Exit code: $LASTEXITCODE)" -Level Warning
                            $failedCount++
                        }
                    }
                    catch {
                        Write-Log "Error removing FOD $partialMatch`: $($_.Exception.Message)" -Level Warning
                        $failedCount++
                    }
                }
            }
        }
        
        Write-Log "Features on Demand removal completed - Success: $removedCount, Failed: $failedCount" -Level Success
        return $true
    }
    catch {
        Write-Log "Features on Demand removal failed: $($_.Exception.Message)" -Level Error
        return $false
    }
}

function Remove-AdditionalSystemFiles {
    <#
    .SYNOPSIS
        Removes additional system files and legacy components that packages alone might not handle
        
    .PARAMETER MountPath
        Path to the mounted Windows image
    #>
    param(
        [Parameter(Mandatory)]
        [string]$MountPath
    )
    
    Write-Log "Removing additional system files and components..." -Level Info
    
    try {
        $successCount = 0
        $failCount = 0
        
        # Define system files/directories to remove
        $systemItemsToRemove = @(
            # Internet Explorer remnants
            @{
                Path = "$MountPath\Program Files\Internet Explorer"
                Description = "Internet Explorer program files"
                Type = "Directory"
            },
            @{
                Path = "$MountPath\Windows\System32\ie4uinit.exe"
                Description = "Internet Explorer initialization"
                Type = "File"
            },
            @{
                Path = "$MountPath\Windows\System32\iedkcs32.dll"
                Description = "Internet Explorer data binding"
                Type = "File"
            },
            
            # IExpress (legacy packaging tool)
            @{
                Path = "$MountPath\Windows\System32\iexpress.exe"
                Description = "IExpress packaging tool"
                Type = "File"
            },
            
            # Math Input Panel (replaced by touch keyboard)
            @{
                Path = "$MountPath\Program Files\Common Files\Microsoft Shared\ink\mip.exe"
                Description = "Math Input Panel executable"
                Type = "File"
            },
            @{
                Path = "$MountPath\Windows\System32\mip.exe"
                Description = "Math Input Panel system executable"
                Type = "File"
            },
            
            # Steps Recorder (rarely used troubleshooting tool)
            @{
                Path = "$MountPath\Windows\System32\psr.exe"
                Description = "Problem Steps Recorder"
                Type = "File"
            },
            
            # Legacy Windows Media Player files (not the store app)
            @{
                Path = "$MountPath\Program Files\Windows Media Player"
                Description = "Windows Media Player (legacy)"
                Type = "Directory"
            },
            @{
                Path = "$MountPath\Windows\System32\wmplayer.exe"
                Description = "Windows Media Player executable"
                Type = "File"
            },
            
            # XPS Viewer (legacy document viewer)
            @{
                Path = "$MountPath\Windows\System32\xpsrchvw.exe"
                Description = "XPS Viewer"
                Type = "File"
            },
            
            # Legacy PowerShell ISE files (if not removed by package removal)
            @{
                Path = "$MountPath\Windows\System32\WindowsPowerShell\v1.0\PowerShell_ISE.exe"
                Description = "PowerShell ISE executable"
                Type = "File"
            },
            
            # Windows Hello Face files (if not needed)
            @{
                Path = "$MountPath\Windows\System32\WinBioPlugIns\FaceFodUninstaller.exe"
                Description = "Windows Hello Face uninstaller"
                Type = "File"
            },
            
            # Additional bloatware game files
            @{
                Path = "$MountPath\Windows\System32\Microsoft-Windows-GameExplorer"
                Description = "Game Explorer system files"
                Type = "Directory"
            }
        )
        
        foreach ($item in $systemItemsToRemove) {
            try {
                if (Test-Path $item.Path) {
                    Write-Log "Removing $($item.Description): $($item.Path)" -Level Info
                    
                    # Take ownership and set permissions for system files
                    if ($item.Type -eq "Directory") {
                        & takeown /f $item.Path /r /d y 2>&1 | Out-Null
                        & icacls $item.Path /grant "Administrators:(F)" /T /C 2>&1 | Out-Null
                        Remove-Item -Path $item.Path -Recurse -Force -ErrorAction SilentlyContinue
                    }
                    else {
                        & takeown /f $item.Path /d y 2>&1 | Out-Null  
                        & icacls $item.Path /grant "Administrators:(F)" /C 2>&1 | Out-Null
                        Remove-Item -Path $item.Path -Force -ErrorAction SilentlyContinue
                    }
                    
                    # Verify removal
                    if (-not (Test-Path $item.Path)) {
                        Write-Log "Successfully removed: $($item.Description)" -Level Success
                        $successCount++
                    }
                    else {
                        Write-Log "Failed to remove: $($item.Description)" -Level Warning
                        $failCount++
                    }
                }
                else {
                    Write-Log "$($item.Description) not found, skipping" -Level Info
                }
            }
            catch {
                Write-Log "Error removing $($item.Description): $($_.Exception.Message)" -Level Warning
                $failCount++
            }
        }
        
        # Remove additional registry-based bloatware folders if they exist
        $additionalPaths = @(
            "$MountPath\Windows\SystemApps\Microsoft.Windows.Cortana_cw5n1h2txyewy",
            "$MountPath\Windows\SystemApps\Microsoft.XboxGameCallableUI_cw5n1h2txyewy",
            "$MountPath\Windows\SystemApps\Microsoft.XboxApp_48.49.31001.0_x64__8wekyb3d8bbwe"
        )
        
        foreach ($path in $additionalPaths) {
            try {
                if (Test-Path $path) {
                    $folderName = Split-Path $path -Leaf
                    Write-Log "Removing SystemApp: $folderName" -Level Info
                    & takeown /f $path /r /d y 2>&1 | Out-Null
                    & icacls $path /grant "Administrators:(F)" /T /C 2>&1 | Out-Null
                    Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
                    
                    if (-not (Test-Path $path)) {
                        Write-Log "Successfully removed SystemApp: $folderName" -Level Success
                        $successCount++
                    }
                }
            }
            catch {
                Write-Log "Error removing SystemApp $path`: $($_.Exception.Message)" -Level Warning
                $failCount++
            }
        }
        
        Write-Log "Additional system file removal completed - Success: $successCount, Failed: $failCount" -Level Success
        return $true
    }
    catch {
        Write-Log "Additional system file removal failed: $($_.Exception.Message)" -Level Error
        return $false
    }
}
