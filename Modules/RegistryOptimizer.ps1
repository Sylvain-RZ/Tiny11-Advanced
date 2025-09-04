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
        Mounts registry hives from the Windows image for editing
        
    .PARAMETER MountPath
        Path to the mounted Windows image
    #>
    param(
        [Parameter(Mandatory)]
        [string]$MountPath
    )
    
    Write-Log "Mounting registry hives..." -Level Info
    
    try {
        $hives = @{
            'HKLM\zCOMPONENTS' = "$MountPath\Windows\System32\config\COMPONENTS"
            'HKLM\zDEFAULT' = "$MountPath\Windows\System32\config\default" 
            'HKLM\zNTUSER' = "$MountPath\Users\Default\ntuser.dat"
            'HKLM\zSOFTWARE' = "$MountPath\Windows\System32\config\SOFTWARE"
            'HKLM\zSYSTEM' = "$MountPath\Windows\System32\config\SYSTEM"
        }
        
        foreach ($hive in $hives.GetEnumerator()) {
            if (Test-Path $hive.Value) {
                & reg load $hive.Key $hive.Value | Out-Null
                if ($LASTEXITCODE -eq 0) {
                    Write-Log "Loaded hive: $($hive.Key)" -Level Info
                }
                else {
                    Write-Log "Failed to load hive: $($hive.Key)" -Level Warning
                }
            }
        }
        
        return $true
    }
    catch {
        Write-Log "Failed to mount registry hives: $($_.Exception.Message)" -Level Error
        return $false
    }
}

function Dismount-RegistryHives {
    <#
    .SYNOPSIS
        Dismounts all mounted registry hives
    #>
    
    Write-Log "Dismounting registry hives..." -Level Info
    
    $hives = @('HKLM\zCOMPONENTS', 'HKLM\zDEFAULT', 'HKLM\zNTUSER', 'HKLM\zSOFTWARE', 'HKLM\zSYSTEM')
    
    foreach ($hive in $hives) {
        try {
            & reg unload $hive | Out-Null
            Write-Log "Unloaded hive: $hive" -Level Info
        }
        catch {
            Write-Log "Failed to unload hive: $hive" -Level Warning
        }
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

function Apply-RegistrySettings {
    <#
    .SYNOPSIS
        Applies an array of registry settings
        
    .PARAMETER Settings
        Array of registry settings to apply
    #>
    param(
        [Parameter(Mandatory)]
        [array]$Settings
    )
    
    foreach ($setting in $Settings) {
        try {
            & reg add $setting.Path /v $setting.Name /t $setting.Type /d $setting.Data /f | Out-Null
            
            if ($LASTEXITCODE -eq 0) {
                Write-Log "Applied registry setting: $($setting.Path)\$($setting.Name)" -Level Info
            }
            else {
                Write-Log "Failed to apply registry setting: $($setting.Path)\$($setting.Name)" -Level Warning
            }
        }
        catch {
            Write-Log "Error applying registry setting $($setting.Path)\$($setting.Name): $($_.Exception.Message)" -Level Error
        }
    }
}