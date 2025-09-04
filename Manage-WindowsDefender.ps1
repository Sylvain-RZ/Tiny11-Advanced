#requires -Version 5.1
#requires -RunAsAdministrator

<#
.SYNOPSIS
    Manage Windows Defender - Enable or Disable functionality
    
.DESCRIPTION
    This script can both enable and disable Windows Defender services and policies.
    
    Enable Mode:
    - Re-enables Windows Defender services
    - Removes disable policies
    - Restores Windows Security UI
    - Configures real-time protection
    
    Disable Mode:
    - Disables Windows Defender services
    - Applies disable policies
    - Hides Windows Security UI
    - Maintains files for future re-enablement
    
.PARAMETER Action
    Specify 'Enable' or 'Disable' to control Windows Defender state
    
.EXAMPLE
    .\Manage-WindowsDefender.ps1 -Action Enable
    Re-enables Windows Defender
    
.EXAMPLE
    .\Manage-WindowsDefender.ps1 -Action Disable
    Disables Windows Defender
    
.NOTES
    Created by: Tiny11 Advanced
    Version: 2.0
    
    This script provides bidirectional control over Windows Defender,
    allowing users to enable or disable antivirus protection as needed.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [ValidateSet('Enable', 'Disable')]
    [string]$Action
)

# Import common functions if available
$ModulePath = Join-Path $PSScriptRoot "Modules"
if (Test-Path (Join-Path $ModulePath "SecurityManager.ps1")) {
    try {
        . (Join-Path $ModulePath "SecurityManager.ps1")
        $UseModuleFunctions = $true
    }
    catch {
        $UseModuleFunctions = $false
    }
}
else {
    $UseModuleFunctions = $false
}

function Write-StatusMessage {
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        
        [ValidateSet('Info', 'Success', 'Warning', 'Error')]
        [string]$Level = 'Info'
    )
    
    $color = switch ($Level) {
        'Info' { 'White' }
        'Success' { 'Green' }
        'Warning' { 'Yellow' }
        'Error' { 'Red' }
    }
    
    $prefix = switch ($Level) {
        'Info' { '[INFO]' }
        'Success' { '[✓]' }
        'Warning' { '[!]' }
        'Error' { '[✗]' }
    }
    
    Write-Host "$prefix $Message" -ForegroundColor $color
}

function Show-DefenderBanner {
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Enable', 'Disable')]
        [string]$Mode
    )
    
    Clear-Host
    
    if ($Mode -eq 'Enable') {
        Write-Host @"
╔══════════════════════════════════════════════════════════════════════════════╗
║                       Windows Defender Re-enablement                        ║
║                              Version 2.0                                    ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  Restores Windows Defender functionality after Tiny11 Advanced processing  ║
║                                                                              ║
║  This script will:                                                          ║
║  • Re-enable Windows Defender services                                      ║
║  • Remove disable policies                                                  ║
║  • Restore Windows Security UI                                              ║
║  • Configure real-time protection                                           ║
╚══════════════════════════════════════════════════════════════════════════════╝

"@ -ForegroundColor Green
        
        Write-StatusMessage "This script will restore Windows Defender to its default state." -Level Warning
    }
    else {
        Write-Host @"
╔══════════════════════════════════════════════════════════════════════════════╗
║                        Windows Defender Disablement                        ║
║                              Version 2.0                                    ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  Disables Windows Defender while preserving files for future re-enablement ║
║                                                                              ║
║  This script will:                                                          ║
║  • Disable Windows Defender services                                        ║
║  • Apply disable policies                                                   ║
║  • Hide Windows Security UI                                                 ║
║  • Preserve all files for future restoration                                ║
╚══════════════════════════════════════════════════════════════════════════════╝

"@ -ForegroundColor Red
        
        Write-StatusMessage "This script will disable Windows Defender but preserve all files." -Level Warning
    }
    
    Write-StatusMessage "Please ensure you have Administrator privileges before continuing." -Level Info
    Write-Host ""
}

function Test-AdministratorPrivileges {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]$currentUser
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Enable-DefenderServices {
    Write-StatusMessage "Re-enabling Windows Defender services..." -Level Info
    
    $services = @(
        @{ Name = 'WinDefend'; DisplayName = 'Windows Defender Antivirus Service' },
        @{ Name = 'WdNisSvc'; DisplayName = 'Windows Defender Network Inspection Service' },
        @{ Name = 'WdNisDrv'; DisplayName = 'Windows Defender Network Inspection Driver' },
        @{ Name = 'WdFilter'; DisplayName = 'Windows Defender Mini-Filter Driver' },
        @{ Name = 'Sense'; DisplayName = 'Windows Defender Advanced Threat Protection' }
    )
    
    $successCount = 0
    
    foreach ($service in $services) {
        try {
            Write-Host "  Processing $($service.DisplayName)..." -ForegroundColor Gray
            
            # Set service to automatic startup
            & reg add "HKLM\SYSTEM\CurrentControlSet\Services\$($service.Name)" /v Start /t REG_DWORD /d 2 /f | Out-Null
            
            if ($LASTEXITCODE -eq 0) {
                try {
                    # Try to start the service using PowerShell cmdlets first
                    Set-Service -Name $service.Name -StartupType Automatic -ErrorAction Stop
                    Start-Service -Name $service.Name -ErrorAction Stop
                    Write-StatusMessage "Service $($service.Name) re-enabled and started" -Level Success
                    $successCount++
                }
                catch {
                    # If PowerShell fails, the registry change was still applied
                    Write-StatusMessage "Service $($service.Name) configured (will start on next boot)" -Level Warning
                    $successCount++
                }
            }
            else {
                Write-StatusMessage "Failed to configure service $($service.Name)" -Level Error
            }
        }
        catch {
            Write-StatusMessage "Error processing service $($service.Name): $($_.Exception.Message)" -Level Error
        }
    }
    
    Write-StatusMessage "Services processed: $successCount/$($services.Count)" -Level Info
    return $successCount -gt 0
}

function Remove-DefenderDisablePolicies {
    Write-StatusMessage "Removing Windows Defender disable policies..." -Level Info
    
    $policyPaths = @(
        'HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection',
        'HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Signature Updates',
        'HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Spynet',
        'HKLM\SOFTWARE\Policies\Microsoft\Windows Defender'
    )
    
    $removedCount = 0
    
    foreach ($path in $policyPaths) {
        try {
            $result = & reg delete $path /f 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-StatusMessage "Removed policy: $path" -Level Success
                $removedCount++
            }
            else {
                Write-Host "  Policy not found: $path (may not have existed)" -ForegroundColor Gray
            }
        }
        catch {
            Write-Host "  Could not remove policy: $path" -ForegroundColor Gray
        }
    }
    
    # Remove specific disable values
    $specificPolicies = @(
        @{ Path = 'HKLM\SOFTWARE\Policies\Microsoft\Windows Defender'; Value = 'DisableAntiSpyware' },
        @{ Path = 'HKLM\SOFTWARE\Policies\Microsoft\Windows Defender'; Value = 'DisableAntiVirus' }
    )
    
    foreach ($policy in $specificPolicies) {
        try {
            & reg delete $policy.Path /v $policy.Value /f 2>$null | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-StatusMessage "Removed policy value: $($policy.Value)" -Level Success
                $removedCount++
            }
        }
        catch {
            # Ignore - policy may not exist
        }
    }
    
    Write-StatusMessage "Removed $removedCount policy entries" -Level Info
    return $true
}

function Restore-DefenderUI {
    Write-StatusMessage "Restoring Windows Defender UI visibility..." -Level Info
    
    try {
        # Remove SettingsPageVisibility that hides Defender UI
        & reg delete 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer' /v SettingsPageVisibility /f 2>$null | Out-Null
        
        if ($LASTEXITCODE -eq 0) {
            Write-StatusMessage "Windows Defender UI visibility restored" -Level Success
        }
        else {
            Write-StatusMessage "UI visibility setting not found (may already be correct)" -Level Info
        }
        
        return $true
    }
    catch {
        Write-StatusMessage "Failed to restore UI visibility: $($_.Exception.Message)" -Level Warning
        return $false
    }
}

function Enable-RealtimeProtection {
    Write-StatusMessage "Attempting to enable real-time protection..." -Level Info
    
    try {
        # Try using PowerShell Defender cmdlets
        if (Get-Command Set-MpPreference -ErrorAction SilentlyContinue) {
            Set-MpPreference -DisableRealtimeMonitoring $false -ErrorAction Stop
            Write-StatusMessage "Real-time protection enabled via PowerShell" -Level Success
            return $true
        }
        else {
            Write-StatusMessage "PowerShell Defender cmdlets not available" -Level Warning
        }
    }
    catch {
        Write-StatusMessage "Could not enable real-time protection via PowerShell: $($_.Exception.Message)" -Level Warning
    }
    
    try {
        # Try registry method as fallback
        & reg delete 'HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection' /v DisableRealtimeMonitoring /f 2>$null | Out-Null
        Write-StatusMessage "Real-time protection registry blocks removed" -Level Success
        return $true
    }
    catch {
        Write-StatusMessage "Could not modify real-time protection settings" -Level Warning
        return $false
    }
}

function Update-DefenderSignatures {
    Write-StatusMessage "Attempting to update Windows Defender signatures..." -Level Info
    
    try {
        if (Get-Command Update-MpSignature -ErrorAction SilentlyContinue) {
            Write-Host "  This may take a moment..." -ForegroundColor Gray
            Update-MpSignature -ErrorAction Stop
            Write-StatusMessage "Defender signatures updated successfully" -Level Success
            return $true
        }
        else {
            Write-StatusMessage "Update-MpSignature cmdlet not available" -Level Warning
        }
    }
    catch {
        Write-StatusMessage "Could not update signatures: $($_.Exception.Message)" -Level Warning
    }
    
    return $false
}

function Disable-DefenderServices {
    Write-StatusMessage "Disabling Windows Defender services..." -Level Info
    
    $services = @(
        @{ Name = 'WinDefend'; DisplayName = 'Windows Defender Antivirus Service' },
        @{ Name = 'WdNisSvc'; DisplayName = 'Windows Defender Network Inspection Service' },
        @{ Name = 'WdNisDrv'; DisplayName = 'Windows Defender Network Inspection Driver' },
        @{ Name = 'WdFilter'; DisplayName = 'Windows Defender Mini-Filter Driver' },
        @{ Name = 'Sense'; DisplayName = 'Windows Defender Advanced Threat Protection' }
    )
    
    $successCount = 0
    
    foreach ($service in $services) {
        try {
            Write-Host "  Processing $($service.DisplayName)..." -ForegroundColor Gray
            
            # Stop the service first
            try {
                Stop-Service -Name $service.Name -Force -ErrorAction SilentlyContinue
            }
            catch {
                # Ignore stop errors - service may already be stopped
            }
            
            # Set service to disabled startup
            & reg add "HKLM\SYSTEM\CurrentControlSet\Services\$($service.Name)" /v Start /t REG_DWORD /d 4 /f | Out-Null
            
            if ($LASTEXITCODE -eq 0) {
                Write-StatusMessage "Service $($service.Name) disabled" -Level Success
                $successCount++
            }
            else {
                Write-StatusMessage "Failed to disable service $($service.Name)" -Level Error
            }
        }
        catch {
            Write-StatusMessage "Error processing service $($service.Name): $($_.Exception.Message)" -Level Error
        }
    }
    
    Write-StatusMessage "Services processed: $successCount/$($services.Count)" -Level Info
    return $successCount -gt 0
}

function Apply-DefenderDisablePolicies {
    Write-StatusMessage "Applying Windows Defender disable policies..." -Level Info
    
    $policies = @(
        @{ Path = 'HKLM\SOFTWARE\Policies\Microsoft\Windows Defender'; Value = 'DisableAntiSpyware'; Data = 1 },
        @{ Path = 'HKLM\SOFTWARE\Policies\Microsoft\Windows Defender'; Value = 'DisableAntiVirus'; Data = 1 },
        @{ Path = 'HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection'; Value = 'DisableRealtimeMonitoring'; Data = 1 },
        @{ Path = 'HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection'; Value = 'DisableBehaviorMonitoring'; Data = 1 },
        @{ Path = 'HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection'; Value = 'DisableOnAccessProtection'; Data = 1 },
        @{ Path = 'HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection'; Value = 'DisableScanOnRealtimeEnable'; Data = 1 },
        @{ Path = 'HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Signature Updates'; Value = 'DisableUpdateOnStartupWithoutEngine'; Data = 1 },
        @{ Path = 'HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Spynet'; Value = 'DisableBlockAtFirstSeen'; Data = 1 }
    )
    
    $successCount = 0
    
    foreach ($policy in $policies) {
        try {
            # Ensure the registry path exists
            $null = & reg add "$($policy.Path)" /f 2>$null
            
            # Add the policy value
            & reg add "$($policy.Path)" /v "$($policy.Value)" /t REG_DWORD /d $policy.Data /f | Out-Null
            
            if ($LASTEXITCODE -eq 0) {
                Write-StatusMessage "Applied policy: $($policy.Value)" -Level Success
                $successCount++
            }
            else {
                Write-StatusMessage "Failed to apply policy: $($policy.Value)" -Level Error
            }
        }
        catch {
            Write-StatusMessage "Error applying policy $($policy.Value): $($_.Exception.Message)" -Level Error
        }
    }
    
    Write-StatusMessage "Applied $successCount policy entries" -Level Info
    return $successCount -gt 0
}

function Hide-DefenderUI {
    Write-StatusMessage "Hiding Windows Defender UI..." -Level Info
    
    try {
        # Hide Defender from Settings app
        $settingsVisibility = "hide:windowsdefender"
        & reg add 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer' /v SettingsPageVisibility /t REG_SZ /d $settingsVisibility /f | Out-Null
        
        if ($LASTEXITCODE -eq 0) {
            Write-StatusMessage "Windows Defender UI hidden from Settings" -Level Success
        }
        else {
            Write-StatusMessage "Failed to hide Defender UI" -Level Error
        }
        
        return $LASTEXITCODE -eq 0
    }
    catch {
        Write-StatusMessage "Failed to hide UI: $($_.Exception.Message)" -Level Warning
        return $false
    }
}

function Disable-RealtimeProtection {
    Write-StatusMessage "Disabling real-time protection..." -Level Info
    
    try {
        # Try using PowerShell Defender cmdlets first
        if (Get-Command Set-MpPreference -ErrorAction SilentlyContinue) {
            Set-MpPreference -DisableRealtimeMonitoring $true -ErrorAction Stop
            Write-StatusMessage "Real-time protection disabled via PowerShell" -Level Success
            return $true
        }
        else {
            Write-StatusMessage "PowerShell Defender cmdlets not available, using registry method" -Level Warning
        }
    }
    catch {
        Write-StatusMessage "PowerShell method failed, using registry method: $($_.Exception.Message)" -Level Warning
    }
    
    try {
        # Registry method as fallback
        & reg add 'HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection' /v DisableRealtimeMonitoring /t REG_DWORD /d 1 /f | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-StatusMessage "Real-time protection disabled via registry" -Level Success
            return $true
        }
    }
    catch {
        Write-StatusMessage "Could not disable real-time protection" -Level Error
        return $false
    }
    
    return $false
}

function Get-DefenderStatus {
    Write-StatusMessage "Checking Windows Defender status..." -Level Info
    
    try {
        if (Get-Command Get-MpComputerStatus -ErrorAction SilentlyContinue) {
            $status = Get-MpComputerStatus
            
            Write-Host "`n" + "="*60 -ForegroundColor Green
            Write-Host "Windows Defender Status" -ForegroundColor Green
            Write-Host "="*60 -ForegroundColor Green
            
            $statusItems = @(
                @{ Label = "Antimalware Enabled"; Value = $status.AntivirusEnabled },
                @{ Label = "Real-time Protection"; Value = $status.RealTimeProtectionEnabled },
                @{ Label = "Network Inspection"; Value = $status.NISEnabled },
                @{ Label = "Antispyware Enabled"; Value = $status.AntispywareEnabled },
                @{ Label = "Cloud Protection"; Value = $status.MAPSReporting -ne "Disabled" }
            )
            
            foreach ($item in $statusItems) {
                $color = if ($item.Value) { 'Green' } else { 'Red' }
                $symbol = if ($item.Value) { '✓' } else { '✗' }
                Write-Host "  $symbol $($item.Label): $($item.Value)" -ForegroundColor $color
            }
            
            if ($status.AntivirusEnabled) {
                Write-Host "`n  Last signature update: $($status.AntivirusSignatureLastUpdated)" -ForegroundColor White
                Write-Host "  Signature version: $($status.AntivirusSignatureVersion)" -ForegroundColor White
            }
            
            Write-Host "="*60 -ForegroundColor Green
            return $true
        }
        else {
            Write-StatusMessage "Cannot check Defender status - cmdlets not available" -Level Warning
            return $false
        }
    }
    catch {
        Write-StatusMessage "Error checking Defender status: $($_.Exception.Message)" -Level Error
        return $false
    }
}

function Invoke-EnableDefender {
    Write-Host "`n" + "="*60 -ForegroundColor Green
    Write-Host "Starting Windows Defender enablement..." -ForegroundColor Green
    Write-Host "="*60 -ForegroundColor Green
    
    # Step 1: Enable services
    $servicesResult = Enable-DefenderServices
    
    # Step 2: Remove disable policies
    $policiesResult = Remove-DefenderDisablePolicies
    
    # Step 3: Restore UI
    $uiResult = Restore-DefenderUI
    
    # Step 4: Enable real-time protection
    $realtimeResult = Enable-RealtimeProtection
    
    # Step 5: Update signatures
    Write-Host ""
    $signaturesResult = Update-DefenderSignatures
    
    # Step 6: Check final status
    Write-Host ""
    $statusResult = Get-DefenderStatus
    
    # Summary
    Write-Host "`n" + "="*60 -ForegroundColor Green
    Write-Host "Windows Defender Enablement Summary" -ForegroundColor Green
    Write-Host "="*60 -ForegroundColor Green
    
    $results = @(
        @{ Task = "Enable Services"; Result = $servicesResult },
        @{ Task = "Remove Policies"; Result = $policiesResult },
        @{ Task = "Restore UI"; Result = $uiResult },
        @{ Task = "Enable Real-time"; Result = $realtimeResult },
        @{ Task = "Update Signatures"; Result = $signaturesResult }
    )
    
    foreach ($result in $results) {
        $symbol = if ($result.Result) { '✓' } else { '✗' }
        $color = if ($result.Result) { 'Green' } else { 'Red' }
        Write-Host "  $symbol $($result.Task)" -ForegroundColor $color
    }
    
    Write-Host "`nWindows Defender enablement completed!" -ForegroundColor Green
    
    if ($servicesResult -and $policiesResult) {
        Write-Host "`nRecommendations:" -ForegroundColor Yellow
        Write-Host "  • Restart your computer for all changes to take effect" -ForegroundColor White
        Write-Host "  • Open Windows Security to verify all protections are active" -ForegroundColor White
        Write-Host "  • Run Windows Update to ensure you have the latest security updates" -ForegroundColor White
        
        if (-not $realtimeResult) {
            Write-Host "  • Manually enable real-time protection in Windows Security settings" -ForegroundColor White
        }
    }
    else {
        Write-StatusMessage "Some operations failed. Windows Defender may not be fully functional." -Level Warning
        Write-StatusMessage "You may need to manually configure settings in Windows Security." -Level Info
    }
}

function Invoke-DisableDefender {
    Write-Host "`n" + "="*60 -ForegroundColor Red
    Write-Host "Starting Windows Defender disablement..." -ForegroundColor Red
    Write-Host "="*60 -ForegroundColor Red
    
    # Step 1: Disable real-time protection first
    $realtimeResult = Disable-RealtimeProtection
    
    # Step 2: Apply disable policies
    $policiesResult = Apply-DefenderDisablePolicies
    
    # Step 3: Hide UI
    $uiResult = Hide-DefenderUI
    
    # Step 4: Disable services
    $servicesResult = Disable-DefenderServices
    
    # Step 5: Check final status
    Write-Host ""
    $statusResult = Get-DefenderStatus
    
    # Summary
    Write-Host "`n" + "="*60 -ForegroundColor Red
    Write-Host "Windows Defender Disablement Summary" -ForegroundColor Red
    Write-Host "="*60 -ForegroundColor Red
    
    $results = @(
        @{ Task = "Disable Real-time"; Result = $realtimeResult },
        @{ Task = "Apply Policies"; Result = $policiesResult },
        @{ Task = "Hide UI"; Result = $uiResult },
        @{ Task = "Disable Services"; Result = $servicesResult }
    )
    
    foreach ($result in $results) {
        $symbol = if ($result.Result) { '✓' } else { '✗' }
        $color = if ($result.Result) { 'Green' } else { 'Red' }
        Write-Host "  $symbol $($result.Task)" -ForegroundColor $color
    }
    
    Write-Host "`nWindows Defender disablement completed!" -ForegroundColor Red
    
    Write-Host "`nImportant Notes:" -ForegroundColor Yellow
    Write-Host "  • All Windows Defender files have been preserved" -ForegroundColor White
    Write-Host "  • You can re-enable Defender at any time using this script" -ForegroundColor White
    Write-Host "  • Consider using alternative security software" -ForegroundColor White
    Write-Host "  • Restart your computer for all changes to take effect" -ForegroundColor White
}

function Get-UserActionChoice {
    if ($Action) {
        return $Action
    }
    
    Write-Host "Please choose an action:" -ForegroundColor Yellow
    Write-Host "  1. Enable Windows Defender" -ForegroundColor Green
    Write-Host "  2. Disable Windows Defender" -ForegroundColor Red
    Write-Host "  3. Check Current Status" -ForegroundColor White
    Write-Host "  Q. Quit" -ForegroundColor Gray
    
    do {
        $choice = Read-Host "`nEnter your choice (1/2/3/Q)"
        switch ($choice.ToUpper()) {
            '1' { return 'Enable' }
            '2' { return 'Disable' }
            '3' { return 'Status' }
            'Q' { return 'Quit' }
            default { Write-Host "Invalid choice. Please enter 1, 2, 3, or Q." -ForegroundColor Red }
        }
    } while ($true)
}

function Main {
    try {
        # Check admin privileges
        if (-not (Test-AdministratorPrivileges)) {
            Write-StatusMessage "This script requires Administrator privileges" -Level Error
            Write-StatusMessage "Please right-click and 'Run as Administrator'" -Level Error
            Read-Host "Press Enter to exit..."
            exit 1
        }
        
        Write-StatusMessage "Administrator privileges confirmed" -Level Success
        
        # Get user action choice
        $userAction = Get-UserActionChoice
        
        if ($userAction -eq 'Quit') {
            Write-StatusMessage "Operation cancelled by user" -Level Info
            exit 0
        }
        
        if ($userAction -eq 'Status') {
            Clear-Host
            Write-Host "Windows Defender Status Check" -ForegroundColor Cyan
            Write-Host "=" * 40 -ForegroundColor Cyan
            Get-DefenderStatus
            return
        }
        
        # Show appropriate banner
        Show-DefenderBanner -Mode $userAction
        
        # Get user confirmation
        $actionText = if ($userAction -eq 'Enable') { 'enabling' } else { 'disabling' }
        $confirmation = Read-Host "`nDo you want to proceed with $actionText Windows Defender? (y/N)"
        if ($confirmation -ne 'y' -and $confirmation -ne 'Y') {
            Write-StatusMessage "Operation cancelled by user" -Level Info
            exit 0
        }
        
        # Execute the chosen action
        if ($userAction -eq 'Enable') {
            Invoke-EnableDefender
        }
        else {
            Invoke-DisableDefender
        }
        
    }
    catch {
        Write-StatusMessage "Fatal error: $($_.Exception.Message)" -Level Error
        exit 1
    }
    finally {
        Write-Host ""
        Read-Host "Press Enter to exit..."
    }
}

# Execute main function if not dot-sourced
if ($MyInvocation.InvocationName -eq $MyInvocation.MyCommand.Source) {
    Main
}