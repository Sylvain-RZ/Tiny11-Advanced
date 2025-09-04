#requires -Version 5.1

<#
.SYNOPSIS
    AppX Package Management for Tiny11 Advanced
    
.DESCRIPTION
    Handles removal of bloatware AppX packages and modern applications
#>

function Remove-BloatwarePackages {
    <#
    .SYNOPSIS
        Removes bloatware AppX packages from the mounted Windows image
        
    .PARAMETER MountPath
        Path to the mounted Windows image
    #>
    param(
        [Parameter(Mandatory)]
        [string]$MountPath
    )
    
    Write-Log "Starting AppX package removal process..." -Level Info
    
    try {
        # Get all provisioned AppX packages
        $allPackages = & dism /English /Image:$MountPath /Get-ProvisionedAppxPackages | 
            ForEach-Object {
                if ($_ -match 'PackageName : (.*)') {
                    $matches[1]
                }
            }
        
        Write-Log "Found $($allPackages.Count) total AppX packages" -Level Info
        
        # Get packages to remove
        $packagesToRemove = Get-BloatwarePackageList | Where-Object {
            $packagePrefix = $_
            $allPackages | Where-Object { $_ -like "$packagePrefix*" }
        }
        
        if ($packagesToRemove.Count -eq 0) {
            Write-Log "No bloatware packages found to remove" -Level Warning
            return $true
        }
        
        Write-Log "Found $($packagesToRemove.Count) bloatware packages to remove" -Level Info
        
        # Remove each package
        foreach ($package in $packagesToRemove) {
            try {
                Write-Log "Removing package: $package" -Level Info
                & dism /English /Image:$MountPath /Remove-ProvisionedAppxPackage /PackageName:$package | Out-Null
                
                if ($LASTEXITCODE -eq 0) {
                    Write-Log "Successfully removed: $package" -Level Success
                }
                else {
                    Write-Log "Failed to remove: $package (Exit code: $LASTEXITCODE)" -Level Warning
                }
            }
            catch {
                Write-Log "Error removing package $package`: $($_.Exception.Message)" -Level Error
            }
        }
        
        Write-Log "AppX package removal completed" -Level Success
        return $true
    }
    catch {
        Write-Log "AppX package removal failed: $($_.Exception.Message)" -Level Error
        return $false
    }
}

function Get-BloatwarePackageList {
    <#
    .SYNOPSIS
        Returns the list of bloatware package prefixes to remove
    #>
    
    return @(
        # UWP/AppX Applications
        'Clipchamp.Clipchamp',
        'Microsoft.SecHealthUI',
        'Microsoft.Windows.PeopleExperienceHost',
        'Microsoft.Windows.PinningConfirmationDialog',
        'Windows.CBSPreview',
        'Microsoft.BingNews',
        'Microsoft.BingWeather',
        'Microsoft.GamingApp',
        'Microsoft.GetHelp',
        'Microsoft.Getstarted',
        'Microsoft.MicrosoftOfficeHub',
        'Microsoft.MicrosoftSolitaireCollection',
        'Microsoft.People',
        'Microsoft.PowerAutomateDesktop',
        'Microsoft.Todos',
        'Microsoft.WindowsAlarms',
        'Microsoft.WindowsCommunicationsApps',
        'Microsoft.WindowsFeedbackHub',
        'Microsoft.WindowsMaps',
        'Microsoft.WindowsSoundRecorder',
        'Microsoft.Xbox.TCUI',
        'Microsoft.XboxGamingOverlay',
        'Microsoft.XboxGameOverlay',
        'Microsoft.XboxSpeechToTextOverlay',
        'Microsoft.YourPhone',
        'Microsoft.ZuneMusic',
        'Microsoft.ZuneVideo',
        'MicrosoftCorporationII.MicrosoftFamily',
        'MicrosoftCorporationII.QuickAssist',
        'MicrosoftTeams',
        'Microsoft.549981C3F5F10',  # Cortana
        
        # Modern Applications (Windows 11 23H2/24H2)
        'Microsoft.Windows.DevHome',
        'Microsoft.OutlookForWindows',
        'Microsoft.ScreenSketch',
        'Microsoft.WindowsNotepad',
        'Microsoft.Paint',
        'Microsoft.WindowsCamera',
        'Microsoft.WindowsPhotos',
        'Microsoft.WindowsCalculator'
    )
}

function Remove-SystemPackages {
    <#
    .SYNOPSIS
        Removes system packages from the mounted Windows image
        
    .PARAMETER MountPath
        Path to the mounted Windows image
        
    .PARAMETER LanguageCode
        Language code for language-specific packages
    #>
    param(
        [Parameter(Mandatory)]
        [string]$MountPath,
        
        [Parameter(Mandatory)]
        [string]$LanguageCode
    )
    
    Write-Log "Starting system package removal process..." -Level Info
    
    try {
        # Get system packages to remove
        $packagePatterns = Get-SystemPackagePatterns -LanguageCode $LanguageCode
        
        # Get all installed packages
        $allPackages = & dism /Image:$MountPath /Get-Packages /Format:Table
        $allPackages = $allPackages -split "`n" | Select-Object -Skip 1
        
        foreach ($packagePattern in $packagePatterns) {
            # Filter packages matching the pattern
            $packagesToRemove = $allPackages | Where-Object { $_ -like "$packagePattern*" }
            
            foreach ($package in $packagesToRemove) {
                try {
                    # Extract package identity
                    $packageIdentity = ($package -split "\s+")[0]
                    
                    if ($packageIdentity) {
                        Write-Log "Removing system package: $packageIdentity" -Level Info
                        & dism /Image:$MountPath /Remove-Package /PackageName:$packageIdentity | Out-Null
                        
                        if ($LASTEXITCODE -eq 0) {
                            Write-Log "Successfully removed: $packageIdentity" -Level Success
                        }
                        else {
                            Write-Log "Failed to remove: $packageIdentity (Exit code: $LASTEXITCODE)" -Level Warning
                        }
                    }
                }
                catch {
                    Write-Log "Error removing package $packageIdentity`: $($_.Exception.Message)" -Level Error
                }
            }
        }
        
        Write-Log "System package removal completed" -Level Success
        return $true
    }
    catch {
        Write-Log "System package removal failed: $($_.Exception.Message)" -Level Error
        return $false
    }
}

function Get-SystemPackagePatterns {
    <#
    .SYNOPSIS
        Returns system package patterns to remove
        
    .PARAMETER LanguageCode
        Language code for language-specific packages
    #>
    param(
        [Parameter(Mandatory)]
        [string]$LanguageCode
    )
    
    return @(
        # System packages
        "Microsoft-Windows-InternetExplorer-Optional-Package~31bf3856ad364e35",
        "Microsoft-Windows-Kernel-LA57-FoD-Package~31bf3856ad364e35~amd64",
        "Microsoft-Windows-LanguageFeatures-Handwriting-$LanguageCode-Package~31bf3856ad364e35",
        "Microsoft-Windows-LanguageFeatures-OCR-$LanguageCode-Package~31bf3856ad364e35",
        "Microsoft-Windows-LanguageFeatures-Speech-$LanguageCode-Package~31bf3856ad364e35",
        "Microsoft-Windows-LanguageFeatures-TextToSpeech-$LanguageCode-Package~31bf3856ad364e35",
        "Microsoft-Windows-MediaPlayer-Package~31bf3856ad364e35",
        "Microsoft-Windows-Wallpaper-Content-Extended-FoD-Package~31bf3856ad364e35",
        "Microsoft-Windows-WordPad-FoD-Package~",
        "Microsoft-Windows-TabletPCMath-Package~",
        "Microsoft-Windows-StepsRecorder-Package~"
        # Note: Windows-Defender-Client-Package is handled separately as it's disabled, not removed
    )
}

# NOTE: Remove-EdgeBrowser and Remove-OneDrive functions have been moved
# to SystemOptimizer.ps1 for better organization (system optimizations vs package management)