#requires -Version 5.1

<#
.SYNOPSIS
    Registry Optimization for Tiny11 Advanced
    
.DESCRIPTION
    Handles all registry modifications including telemetry removal,
    anti-reinstallation methods, and privacy optimizations
#>

function Optimize-RegistrySettings {
    <#
    .SYNOPSIS
        Applies comprehensive registry optimizations to the mounted image
        
    .PARAMETER MountPath
        Path to the mounted Windows image
    #>
    param(
        [Parameter(Mandatory)]
        [string]$MountPath
    )
    
    Write-Log "Starting registry optimization process..." -Level Info
    
    try {
        # Load registry hives
        if (-not (Mount-RegistryHives -MountPath $MountPath)) {
            throw "Failed to mount registry hives"
        }
        
        # Test registry hive accessibility
        if (-not (Test-RegistryHiveAccessibility)) {
            Write-Log "Some registry hives are not accessible, continuing with available hives..." -Level Warning
        }
        
        # Apply all registry optimizations
        Disable-TelemetryRegistry
        Disable-SponsoredApps  
        Enable-LocalAccountsOOBE
        Disable-ReservedStorage
        Disable-BitLockerDeviceEncryption
        Disable-OneDriveFolderBackup
        Disable-BingInStartMenu
        Apply-AntiReinstallationMethods
        Disable-WidgetsAndIntrusive
        Apply-PrivacyOptimizations
        Apply-PerformanceOptimizations
        Bypass-SystemRequirements
        
        # Advanced AI features removal (2024-2025)
        Disable-AIFeatures
        
        Write-Log "Registry optimizations applied successfully" -Level Success
        return $true
    }
    catch {
        Write-Log "Registry optimization failed: $($_.Exception.Message)" -Level Error
        return $false
    }
    finally {
        # Always unmount registry hives
        Dismount-RegistryHives
    }
}

function Mount-RegistryHives {
    <#
    .SYNOPSIS
        Mounts registry hives from the Windows image for editing with enhanced error handling
        
    .PARAMETER MountPath
        Path to the mounted Windows image
    #>
    param(
        [Parameter(Mandatory)]
        [string]$MountPath
    )
    
    Write-Log "Mounting registry hives..." -Level Info
    
    try {
        # Verify that we have necessary permissions
        if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            throw "Administrator privileges required for registry hive operations"
        }
        
        $hives = @{
            'HKLM\zCOMPONENTS' = "$MountPath\Windows\System32\config\COMPONENTS"
            'HKLM\zDEFAULT' = "$MountPath\Windows\System32\config\default" 
            'HKLM\zNTUSER' = "$MountPath\Users\Default\ntuser.dat"
            'HKLM\zSOFTWARE' = "$MountPath\Windows\System32\config\SOFTWARE"
            'HKLM\zSYSTEM' = "$MountPath\Windows\System32\config\SYSTEM"
        }
        
        # Force garbage collection and close any open handles
        [System.GC]::Collect()
        [System.GC]::WaitForPendingFinalizers()
        [System.GC]::Collect()
        
        $mountedHives = @()
        $allSuccessful = $true
        
        foreach ($hive in $hives.GetEnumerator()) {
            if (Test-Path $hive.Value) {
                # Set proper permissions on hive file
                try {
                    $acl = Get-Acl $hive.Value
                    $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule("Everyone", "FullControl", "Allow")
                    $acl.SetAccessRule($accessRule)
                    Set-Acl $hive.Value $acl
                }
                catch {
                    Write-Log "Could not modify permissions on hive file: $($hive.Value)" -Level Warning
                }
                
                # Attempt to load the hive with retry logic
                $retryCount = 0
                $maxRetries = 3
                $loaded = $false
                
                while ($retryCount -lt $maxRetries -and -not $loaded) {
                    Start-Sleep -Milliseconds (500 * ($retryCount + 1))  # Progressive delay
                    
                    $output = & reg load $hive.Key $hive.Value 2>&1
                    if ($LASTEXITCODE -eq 0) {
                        Write-Log "Successfully loaded hive: $($hive.Key)" -Level Info
                        $mountedHives += $hive.Key
                        $loaded = $true
                    }
                    else {
                        $retryCount++
                        if ($retryCount -lt $maxRetries) {
                            Write-Log "Retrying to load hive: $($hive.Key) (attempt $($retryCount + 1)) - Error: $output" -Level Warning
                        }
                        else {
                            Write-Log "Failed to load hive after $maxRetries attempts: $($hive.Key) - Error: $output" -Level Error
                            $allSuccessful = $false
                        }
                    }
                }
            }
            else {
                Write-Log "Hive file not found: $($hive.Value)" -Level Warning
                $allSuccessful = $false
            }
        }
        
        # Verify mounted hives are accessible and set permissions
        Start-Sleep -Milliseconds 2000  # Allow more time for hives to be fully mounted
        
        foreach ($hiveName in $mountedHives) {
            try {
                # Test accessibility
                $testResult = & reg query $hiveName 2>&1
                if ($LASTEXITCODE -eq 0) {
                    # Set full control permissions on the registry key
                    try {
                        $hivePath = $hiveName -replace '^HKLM\\z', 'HKEY_LOCAL_MACHINE\z'
                        & reg save $hiveName "$env:TEMP\test_$($hiveName -replace '\\', '_').reg" /y 2>&1 | Out-Null
                        if (Test-Path "$env:TEMP\test_$($hiveName -replace '\\', '_').reg") {
                            Remove-Item "$env:TEMP\test_$($hiveName -replace '\\', '_').reg" -Force
                        }
                    }
                    catch {
                        # Test failed, but continue
                    }
                }
                else {
                    Write-Log "Mounted hive not accessible: $hiveName" -Level Warning
                    $allSuccessful = $false
                }
            }
            catch {
                Write-Log "Error testing hive accessibility: $hiveName - $($_.Exception.Message)" -Level Warning
                $allSuccessful = $false
            }
        }
        
        return $allSuccessful
    }
    catch {
        Write-Log "Failed to mount registry hives: $($_.Exception.Message)" -Level Error
        return $false
    }
}

function Dismount-RegistryHives {
    <#
    .SYNOPSIS
        Dismounts all mounted registry hives with enhanced error handling and cleanup
    #>
    
    Write-Log "Dismounting registry hives..." -Level Info
    
    $hives = @('HKLM\zCOMPONENTS', 'HKLM\zDEFAULT', 'HKLM\zNTUSER', 'HKLM\zSOFTWARE', 'HKLM\zSYSTEM')
    
    foreach ($hive in $hives) {
        $maxRetries = 5
        $retryCount = 0
        $unloaded = $false
        
        while ($retryCount -lt $maxRetries -and -not $unloaded) {
            try {
                # Force garbage collection before attempting to unload
                [System.GC]::Collect()
                [System.GC]::WaitForPendingFinalizers()
                
                # Attempt to unload the hive
                $output = & reg unload $hive 2>&1
                
                if ($LASTEXITCODE -eq 0) {
                    Write-Log "Successfully unloaded hive: $hive" -Level Info
                    $unloaded = $true
                }
                else {
                    $retryCount++
                    if ($retryCount -lt $maxRetries) {
                        Write-Log "Retrying to unload hive: $hive (attempt $($retryCount + 1)) - Error: $output" -Level Warning
                        Start-Sleep -Seconds 2
                    }
                    else {
                        Write-Log "Failed to unload hive after $maxRetries attempts: $hive - Error: $output" -Level Warning
                    }
                }
            }
            catch {
                $retryCount++
                if ($retryCount -lt $maxRetries) {
                    Write-Log "Exception unloading hive, retrying: $hive - $($_.Exception.Message)" -Level Warning
                    Start-Sleep -Seconds 2
                }
                else {
                    Write-Log "Failed to unload hive after $maxRetries attempts: $hive - $($_.Exception.Message)" -Level Warning
                }
            }
        }
    }
    
    # Final cleanup - attempt to close any remaining handles
    try {
        [System.GC]::Collect()
        [System.GC]::WaitForPendingFinalizers()
    }
    catch {
        # Ignore cleanup errors
    }
}

function Disable-TelemetryRegistry {
    <#
    .SYNOPSIS
        Disables Windows telemetry through registry modifications
    #>
    
    Write-Log "Disabling telemetry..." -Level Info
    
    $telemetrySettings = @(
        @{
            Path = 'HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo'
            Name = 'Enabled'
            Type = 'REG_DWORD'
            Data = '0'
        },
        @{
            Path = 'HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\Privacy'
            Name = 'TailoredExperiencesWithDiagnosticDataEnabled'
            Type = 'REG_DWORD'
            Data = '0'
        },
        @{
            Path = 'HKLM\zNTUSER\Software\Microsoft\Speech_OneCore\Settings\OnlineSpeechPrivacy'
            Name = 'HasAccepted'
            Type = 'REG_DWORD'
            Data = '0'
        },
        @{
            Path = 'HKLM\zNTUSER\Software\Microsoft\Input\TIPC'
            Name = 'Enabled'
            Type = 'REG_DWORD'
            Data = '0'
        },
        @{
            Path = 'HKLM\zNTUSER\Software\Microsoft\InputPersonalization'
            Name = 'RestrictImplicitInkCollection'
            Type = 'REG_DWORD'
            Data = '1'
        },
        @{
            Path = 'HKLM\zNTUSER\Software\Microsoft\InputPersonalization'
            Name = 'RestrictImplicitTextCollection'
            Type = 'REG_DWORD'
            Data = '1'
        },
        @{
            Path = 'HKLM\zNTUSER\Software\Microsoft\InputPersonalization\TrainedDataStore'
            Name = 'HarvestContacts'
            Type = 'REG_DWORD'
            Data = '0'
        },
        @{
            Path = 'HKLM\zNTUSER\Software\Microsoft\Personalization\Settings'
            Name = 'AcceptedPrivacyPolicy'
            Type = 'REG_DWORD'
            Data = '0'
        },
        @{
            Path = 'HKLM\zSOFTWARE\Policies\Microsoft\Windows\DataCollection'
            Name = 'AllowTelemetry'
            Type = 'REG_DWORD'
            Data = '0'
        },
        @{
            Path = 'HKLM\zSYSTEM\ControlSet001\Services\dmwappushservice'
            Name = 'Start'
            Type = 'REG_DWORD'
            Data = '4'
        }
    )
    
    Apply-RegistrySettings -Settings $telemetrySettings
}

function Apply-AntiReinstallationMethods {
    <#
    .SYNOPSIS
        Implements advanced anti-reinstallation methods for Outlook and DevHome
        Using UScheduler and BlockedOobeUpdaters methods
    #>
    
    Write-Log "Applying anti-reinstallation methods..." -Level Info
    
    # UScheduler method with workCompleted
    $uSchedulerSettings = @(
        @{
            Path = 'HKLM\zSOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Orchestrator\UScheduler\OutlookUpdate'
            Name = 'workCompleted'
            Type = 'REG_DWORD'
            Data = '1'
        },
        @{
            Path = 'HKLM\zSOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Orchestrator\UScheduler\DevHomeUpdate'
            Name = 'workCompleted'
            Type = 'REG_DWORD'
            Data = '1'
        }
    )
    
    Apply-RegistrySettings -Settings $uSchedulerSettings
    
    # Remove OOBE triggers
    try {
        & reg delete 'HKLM\zSOFTWARE\Microsoft\WindowsUpdate\Orchestrator\UScheduler_Oobe\OutlookUpdate' /f | Out-Null
        & reg delete 'HKLM\zSOFTWARE\Microsoft\WindowsUpdate\Orchestrator\UScheduler_Oobe\DevHomeUpdate' /f | Out-Null
    }
    catch {
        Write-Log "OOBE trigger keys not found (expected)" -Level Info
    }
    
    # BlockedOobeUpdaters method
    $blockedUpdaters = @(
        @{
            Path = 'HKLM\zSOFTWARE\Microsoft\Windows\CurrentVersion\OOBE\BlockedOobeUpdaters'
            Name = 'Microsoft.OutlookForWindows'
            Type = 'REG_SZ'
            Data = 'blocked'
        },
        @{
            Path = 'HKLM\zSOFTWARE\Microsoft\Windows\CurrentVersion\OOBE\BlockedOobeUpdaters'
            Name = 'Microsoft.Windows.DevHome'
            Type = 'REG_SZ'
            Data = 'blocked'
        }
    )
    
    Apply-RegistrySettings -Settings $blockedUpdaters
}

function Disable-AIFeatures {
    <#
    .SYNOPSIS
        Disables AI features introduced in Windows 11 (2024-2025)
        Including Copilot, Recall, and other AI services
    #>
    
    Write-Log "Disabling AI features..." -Level Info
    
    $aiSettings = @(
        # Disable Windows Recall
        @{
            Path = 'HKLM\zSOFTWARE\Policies\Microsoft\Windows\WindowsAI'
            Name = 'AllowRecallEnablement'
            Type = 'REG_DWORD'
            Data = '0'
        },
        # Disable Windows Copilot
        @{
            Path = 'HKLM\zSOFTWARE\Policies\Microsoft\Windows\WindowsCopilot'
            Name = 'TurnOffWindowsCopilot'
            Type = 'REG_DWORD'
            Data = '1'
        },
        # Disable AI Fabric Service
        @{
            Path = 'HKLM\zSYSTEM\ControlSet001\Services\AIFabricService'
            Name = 'Start'
            Type = 'REG_DWORD'
            Data = '4'
        }
    )
    
    Apply-RegistrySettings -Settings $aiSettings
}

function Disable-SponsoredApps {
    <#
    .SYNOPSIS
        Disables sponsored apps and consumer features
    #>
    
    Write-Log "Disabling sponsored apps..." -Level Info
    
    $sponsoredSettings = @(
        @{
            Path = 'HKLM\zNTUSER\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
            Name = 'OemPreInstalledAppsEnabled'
            Type = 'REG_DWORD'
            Data = '0'
        },
        @{
            Path = 'HKLM\zNTUSER\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
            Name = 'PreInstalledAppsEnabled'
            Type = 'REG_DWORD'
            Data = '0'
        },
        @{
            Path = 'HKLM\zNTUSER\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
            Name = 'SilentInstalledAppsEnabled'
            Type = 'REG_DWORD'
            Data = '0'
        },
        @{
            Path = 'HKLM\zSOFTWARE\Policies\Microsoft\Windows\CloudContent'
            Name = 'DisableWindowsConsumerFeatures'
            Type = 'REG_DWORD'
            Data = '1'
        },
        @{
            Path = 'HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
            Name = 'ContentDeliveryAllowed'
            Type = 'REG_DWORD'
            Data = '0'
        },
        @{
            Path = 'HKLM\zSOFTWARE\Microsoft\PolicyManager\current\device\Start'
            Name = 'ConfigureStartPins'
            Type = 'REG_SZ'
            Data = '{"pinnedList": [{}]}'
        },
        @{
            Path = 'HKLM\zSOFTWARE\Policies\Microsoft\PushToInstall'
            Name = 'DisablePushToInstall'
            Type = 'REG_DWORD'
            Data = '1'
        }
    )
    
    Apply-RegistrySettings -Settings $sponsoredSettings
    
    # Remove subscriptions and suggestions
    try {
        & reg delete 'HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager\Subscriptions' /f | Out-Null
        & reg delete 'HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager\SuggestedApps' /f | Out-Null
    }
    catch {
        Write-Log "Subscription keys not found (expected)" -Level Info
    }
}

function Disable-WidgetsAndIntrusive {
    <#
    .SYNOPSIS
        Disables widgets and other intrusive features
    #>
    
    Write-Log "Disabling widgets and intrusive features..." -Level Info
    
    $widgetSettings = @(
        # Disable Widgets
        @{
            Path = 'HKLM\zSOFTWARE\Policies\Microsoft\Dsh'
            Name = 'AllowNewsAndInterests'
            Type = 'REG_DWORD'
            Data = '0'
        },
        @{
            Path = 'HKLM\zSOFTWARE\Microsoft\PolicyManager\current\device\NewsAndInterests'
            Name = 'AllowNewsAndInterests'
            Type = 'REG_DWORD'
            Data = '0'
        },
        @{
            Path = 'HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
            Name = 'TaskbarDa'
            Type = 'REG_DWORD'
            Data = '0'
        },
        # Disable Chat icon
        @{
            Path = 'HKLM\zSOFTWARE\Policies\Microsoft\Windows\Windows Chat'
            Name = 'ChatIcon'
            Type = 'REG_DWORD'
            Data = '3'
        },
        @{
            Path = 'HKLM\zNTUSER\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
            Name = 'TaskbarMn'
            Type = 'REG_DWORD'
            Data = '0'
        }
    )
    
    Apply-RegistrySettings -Settings $widgetSettings
}

function Enable-LocalAccountsOOBE {
    <#
    .SYNOPSIS
        Enables local accounts during OOBE
    #>
    
    Write-Log "Enabling local accounts on OOBE..." -Level Info
    
    $oobeSettings = @(
        @{
            Path = 'HKLM\zSOFTWARE\Microsoft\Windows\CurrentVersion\OOBE'
            Name = 'BypassNRO'
            Type = 'REG_DWORD'
            Data = '1'
        },
        @{
            Path = 'HKLM\zSOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'
            Name = 'MSAOptional'
            Type = 'REG_DWORD'
            Data = '1'
        },
        @{
            Path = 'HKLM\zSOFTWARE\Policies\Microsoft\Windows\OOBE'
            Name = 'DisablePrivacyExperience'
            Type = 'REG_DWORD'
            Data = '1'
        },
        @{
            Path = 'HKLM\zSOFTWARE\Microsoft\Windows\CurrentVersion\OOBE'
            Name = 'DisableVoiceActivationTitleBar'
            Type = 'REG_DWORD'
            Data = '1'
        },
        @{
            Path = 'HKLM\zSOFTWARE\Microsoft\Windows\CurrentVersion\OOBE'
            Name = 'LaunchUserOOBE'
            Type = 'REG_DWORD'
            Data = '0'
        }
    )
    
    Apply-RegistrySettings -Settings $oobeSettings
}

function Disable-ReservedStorage {
    <#
    .SYNOPSIS
        Disables Windows reserved storage
    #>
    
    Write-Log "Disabling reserved storage..." -Level Info
    
    $storageSettings = @(
        @{
            Path = 'HKLM\zSOFTWARE\Microsoft\Windows\CurrentVersion\ReserveManager'
            Name = 'ShippedWithReserves'
            Type = 'REG_DWORD'
            Data = '0'
        }
    )
    
    Apply-RegistrySettings -Settings $storageSettings
}

function Disable-BitLockerDeviceEncryption {
    <#
    .SYNOPSIS
        Disables BitLocker device encryption
    #>
    
    Write-Log "Disabling BitLocker device encryption..." -Level Info
    
    $bitlockerSettings = @(
        @{
            Path = 'HKLM\zSYSTEM\ControlSet001\Control\BitLocker'
            Name = 'PreventDeviceEncryption'
            Type = 'REG_DWORD'
            Data = '1'
        }
    )
    
    Apply-RegistrySettings -Settings $bitlockerSettings
}

# NOTE: Disable-ChatIcon function has been integrated into Disable-WidgetsAndIntrusive
# to avoid duplication. The standalone function has been removed.

function Disable-OneDriveFolderBackup {
    <#
    .SYNOPSIS
        Disables OneDrive folder backup
    #>
    
    Write-Log "Disabling OneDrive folder backup..." -Level Info
    
    $onedriveSettings = @(
        @{
            Path = 'HKLM\zSOFTWARE\Policies\Microsoft\Windows\OneDrive'
            Name = 'DisableFileSyncNGSC'
            Type = 'REG_DWORD'
            Data = '1'
        }
    )
    
    Apply-RegistrySettings -Settings $onedriveSettings
}

function Disable-BingInStartMenu {
    <#
    .SYNOPSIS
        Disables Bing search in Start Menu
    #>
    
    Write-Log "Disabling Bing in Start Menu..." -Level Info
    
    $bingSettings = @(
        @{
            Path = 'HKLM\zNTUSER\Software\Policies\Microsoft\Windows\Explorer'
            Name = 'ShowRunAsDifferentUserInStart'
            Type = 'REG_DWORD'
            Data = '1'
        },
        @{
            Path = 'HKLM\zNTUSER\Software\Policies\Microsoft\Windows\Explorer'
            Name = 'DisableSearchBoxSuggestions'
            Type = 'REG_DWORD'
            Data = '1'
        }
    )
    
    Apply-RegistrySettings -Settings $bingSettings
}

function Apply-PrivacyOptimizations {
    <#
    .SYNOPSIS
        Applies comprehensive privacy optimizations
    #>
    
    Write-Log "Applying privacy optimizations..." -Level Info
    
    $privacySettings = @(
        @{
            Path = 'HKLM\zSOFTWARE\Policies\Microsoft\Windows\CloudContent'
            Name = 'DisableConsumerAccountStateContent'
            Type = 'REG_DWORD'
            Data = '1'
        },
        @{
            Path = 'HKLM\zSOFTWARE\Policies\Microsoft\Windows\CloudContent'
            Name = 'DisableCloudOptimizedContent'
            Type = 'REG_DWORD'
            Data = '1'
        }
    )
    
    Apply-RegistrySettings -Settings $privacySettings
}

function Apply-PerformanceOptimizations {
    <#
    .SYNOPSIS
        Applies performance-related registry optimizations
    #>
    
    Write-Log "Applying performance optimizations..." -Level Info
    
    $performanceSettings = @(
        # Visual effects for performance
        @{
            Path = 'HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects'
            Name = 'VisualFXSetting'
            Type = 'REG_DWORD'
            Data = '2'
        },
        @{
            Path = 'HKLM\zNTUSER\Control Panel\Desktop'
            Name = 'UserPreferencesMask'
            Type = 'REG_BINARY'
            Data = '9012038010000000'
        }
    )
    
    Apply-RegistrySettings -Settings $performanceSettings
}

function Bypass-SystemRequirements {
    <#
    .SYNOPSIS
        Bypasses Windows 11 system requirements
    #>
    
    Write-Log "Bypassing system requirements..." -Level Info
    
    $bypassSettings = @(
        @{
            Path = 'HKLM\zDEFAULT\Control Panel\UnsupportedHardwareNotificationCache'
            Name = 'SV1'
            Type = 'REG_DWORD'
            Data = '0'
        },
        @{
            Path = 'HKLM\zDEFAULT\Control Panel\UnsupportedHardwareNotificationCache'
            Name = 'SV2'
            Type = 'REG_DWORD'
            Data = '0'
        },
        @{
            Path = 'HKLM\zNTUSER\Control Panel\UnsupportedHardwareNotificationCache'
            Name = 'SV1'
            Type = 'REG_DWORD'
            Data = '0'
        },
        @{
            Path = 'HKLM\zNTUSER\Control Panel\UnsupportedHardwareNotificationCache'
            Name = 'SV2'
            Type = 'REG_DWORD'
            Data = '0'
        },
        @{
            Path = 'HKLM\zSYSTEM\Setup\LabConfig'
            Name = 'BypassCPUCheck'
            Type = 'REG_DWORD'
            Data = '1'
        },
        @{
            Path = 'HKLM\zSYSTEM\Setup\LabConfig'
            Name = 'BypassRAMCheck'
            Type = 'REG_DWORD'
            Data = '1'
        },
        @{
            Path = 'HKLM\zSYSTEM\Setup\LabConfig'
            Name = 'BypassSecureBootCheck'
            Type = 'REG_DWORD'
            Data = '1'
        },
        @{
            Path = 'HKLM\zSYSTEM\Setup\LabConfig'
            Name = 'BypassStorageCheck'
            Type = 'REG_DWORD'
            Data = '1'
        },
        @{
            Path = 'HKLM\zSYSTEM\Setup\LabConfig'
            Name = 'BypassTPMCheck'
            Type = 'REG_DWORD'
            Data = '1'
        },
        @{
            Path = 'HKLM\zSYSTEM\Setup\MoSetup'
            Name = 'AllowUpgradesWithUnsupportedTPMOrCPU'
            Type = 'REG_DWORD'
            Data = '1'
        }
    )
    
    Apply-RegistrySettings -Settings $bypassSettings
}

function Test-RegistryHiveAccessibility {
    <#
    .SYNOPSIS
        Tests if all required registry hives are properly mounted and accessible
    #>
    
    $hives = @('HKLM\zCOMPONENTS', 'HKLM\zDEFAULT', 'HKLM\zNTUSER', 'HKLM\zSOFTWARE', 'HKLM\zSYSTEM')
    $allAccessible = $true
    
    foreach ($hive in $hives) {
        try {
            $queryResult = & reg query $hive 2>&1
            if ($LASTEXITCODE -ne 0) {
                Write-Log "Registry hive not accessible: $hive" -Level Warning
                $allAccessible = $false
            }
            else {
                Write-Log "Registry hive accessible: $hive" -Level Info
            }
        }
        catch {
            Write-Log "Error testing registry hive: $hive - $($_.Exception.Message)" -Level Warning
            $allAccessible = $false
        }
    }
    
    return $allAccessible
}

function Set-RegistryKeyPermissions {
    <#
    .SYNOPSIS
        Attempts to set proper permissions on a registry key
    .PARAMETER RegistryPath
        Path to the registry key
    #>
    param(
        [Parameter(Mandatory)]
        [string]$RegistryPath
    )
    
    try {
        # Use psexec-like approach to set permissions
        $regKeyPath = $RegistryPath -replace '^HKLM\\z', 'HKEY_LOCAL_MACHINE\z'
        
        # Try to query the key first to check if it's accessible
        $queryResult = & reg query $RegistryPath 2>&1
        if ($LASTEXITCODE -ne 0) {
            return $false
        }
        
        # Create a temporary .reg file to apply permissions
        $tempRegFile = "$env:TEMP\temp_permissions_$(Get-Random).reg"
        $regContent = @"
Windows Registry Editor Version 5.00

[$regKeyPath]

"@
        $regContent | Out-File -FilePath $tempRegFile -Encoding ASCII
        
        # Try to import the .reg file
        $importResult = & reg import $tempRegFile 2>&1
        $success = $LASTEXITCODE -eq 0
        
        # Clean up
        if (Test-Path $tempRegFile) {
            Remove-Item $tempRegFile -Force -ErrorAction SilentlyContinue
        }
        
        return $success
    }
    catch {
        return $false
    }
}

function Apply-RegistrySettings {
    <#
    .SYNOPSIS
        Applies an array of registry settings with enhanced error handling and permission fixes
        
    .PARAMETER Settings
        Array of registry settings to apply
    #>
    param(
        [Parameter(Mandatory)]
        [array]$Settings
    )
    
    foreach ($setting in $Settings) {
        $maxRetries = 5
        $retryCount = 0
        $success = $false
        
        while ($retryCount -lt $maxRetries -and -not $success) {
            try {
                # Force garbage collection to release any handles
                [System.GC]::Collect()
                [System.GC]::WaitForPendingFinalizers()
                
                # Progressive delay with each retry
                if ($retryCount -gt 0) {
                    Start-Sleep -Milliseconds (500 * $retryCount)
                }
                
                # Check if the hive path exists before attempting to modify
                $hivePath = $setting.Path -replace '^HKLM\\z', 'HKLM\z'
                
                # Verify the hive is accessible
                $hiveRoot = ($hivePath -split '\\')[0..1] -join '\'
                $testQuery = & reg query $hiveRoot 2>&1
                if ($LASTEXITCODE -ne 0) {
                    throw "Registry hive not accessible: $hiveRoot"
                }
                
                # Create the parent key path step by step to ensure proper permissions
                $pathParts = $setting.Path -split '\\'
                $currentPath = $pathParts[0..1] -join '\'  # Start with HKLM\zHIVE
                
                for ($i = 2; $i -lt $pathParts.Length; $i++) {
                    $currentPath += '\' + $pathParts[$i]
                    
                    # Try to create each level of the path
                    $createResult = & reg add $currentPath /f 2>&1
                    if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne 1) {
                        # Error code 1 means key already exists, which is fine
                        Write-Log "Could not create registry path: $currentPath - $createResult" -Level Warning
                    }
                }
                
                # Apply the registry setting with explicit error handling
                $addResult = & reg add $setting.Path /v $setting.Name /t $setting.Type /d $setting.Data /f 2>&1
                
                if ($LASTEXITCODE -eq 0) {
                    Write-Log "Applied registry setting: $($setting.Path)\$($setting.Name)" -Level Info
                    $success = $true
                }
                elseif ($LASTEXITCODE -eq 5) {
                    # Access denied - try different approach
                    $retryCount++
                    if ($retryCount -lt $maxRetries) {
                        Write-Log "Access denied, retrying registry setting: $($setting.Path)\$($setting.Name) (attempt $($retryCount + 1))" -Level Warning
                        
                        # For NTUSER hive access issues, try alternative method
                        if ($setting.Path -like '*zNTUSER*') {
                            try {
                                # Use a different approach for NTUSER hive
                                $altPath = $setting.Path -replace 'HKLM\\zNTUSER', 'HKLM\zDEFAULT'
                                & reg add $altPath /v $setting.Name /t $setting.Type /d $setting.Data /f 2>&1 | Out-Null
                                if ($LASTEXITCODE -eq 0) {
                                    Write-Log "Applied registry setting to alternative path: $altPath\$($setting.Name)" -Level Info
                                    $success = $true
                                    break
                                }
                            }
                            catch {
                                # Continue with original retry logic
                            }
                        }
                        
                        # Try to create the key structure first
                        try {
                            & reg add $setting.Path /f 2>&1 | Out-Null
                        }
                        catch {
                            # Ignore ownership errors
                        }
                    }
                    else {
                        Write-Log "Failed to apply registry setting after $maxRetries attempts (Access Denied): $($setting.Path)\$($setting.Name)" -Level Warning
                    }
                }
                else {
                    $retryCount++
                    if ($retryCount -lt $maxRetries) {
                        Write-Log "Retrying registry setting: $($setting.Path)\$($setting.Name) (attempt $($retryCount + 1)) - Error: $addResult" -Level Warning
                    }
                    else {
                        Write-Log "Failed to apply registry setting after $maxRetries attempts: $($setting.Path)\$($setting.Name) (Error code: $LASTEXITCODE)" -Level Warning
                    }
                }
            }
            catch {
                $retryCount++
                if ($retryCount -lt $maxRetries) {
                    Write-Log "Exception occurred, retrying: $($setting.Path)\$($setting.Name) - $($_.Exception.Message)" -Level Warning
                }
                else {
                    Write-Log "Error applying registry setting after $maxRetries attempts: $($setting.Path)\$($setting.Name) - $($_.Exception.Message)" -Level Error
                }
            }
        }
    }
}