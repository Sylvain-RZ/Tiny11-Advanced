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
        
        [Parameter(Mandatory = $false)]
        [string]$LanguageCode = "en-US"
    )
    
    Write-Log "Starting system package removal process..." -Level Info
    
    # Validate LanguageCode parameter
    if ([string]::IsNullOrEmpty($LanguageCode)) {
        $LanguageCode = "en-US"
        Write-Log "Language code was empty, defaulting to en-US" -Level Warning
    }
    
    Write-Log "Using language code: $LanguageCode" -Level Info
    
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

function Remove-AdditionalLanguagePacks {
    <#
    .SYNOPSIS
        Removes additional language packs from the image while preserving the primary language
    .DESCRIPTION
        This function removes language packs that are not the system's primary language,
        reducing image size while maintaining the ability to install language packs post-deployment.
        The primary system language is always preserved.
    .PARAMETER MountPath
        Path to the mounted Windows image
    .PARAMETER PrimaryLanguage
        Primary language code to preserve (e.g., "en-US", "fr-FR")
    #>
    param(
        [Parameter(Mandatory)]
        [string]$MountPath,
        
        [Parameter(Mandatory)]
        [string]$PrimaryLanguage
    )
    
    Write-Log "Starting removal of additional language packs (preserving $PrimaryLanguage)..." -Level Info
    
    try {
        # Get all installed language packs
        $langPacks = & dism /Image:$MountPath /Get-Packages | Where-Object { $_ -match "Language Pack" }
        
        if (-not $langPacks) {
            Write-Log "No additional language packs found to remove" -Level Info
            return $true
        }
        
        $removedCount = 0
        foreach ($pack in $langPacks) {
            # Extract package name
            if ($pack -match "Package Identity : (.+)") {
                $packageName = $Matches[1].Trim()
                
                # Skip if it's the primary language pack
                if ($packageName -match $PrimaryLanguage) {
                    Write-Log "Preserving primary language pack: $packageName" -Level Info
                    continue
                }
                
                # Remove non-primary language pack
                Write-Log "Removing language pack: $packageName" -Level Info
                & dism /Image:$MountPath /Remove-Package /PackageName:$packageName /Quiet
                
                if ($LASTEXITCODE -eq 0) {
                    $removedCount++
                    Write-Log "Successfully removed: $packageName" -Level Success
                } else {
                    Write-Log "Failed to remove: $packageName" -Level Warning
                }
            }
        }
        
        Write-Log "Removed $removedCount additional language packs" -Level Success
        Write-Log "Primary language ($PrimaryLanguage) and installation capability preserved" -Level Info
        return $true
    }
    catch {
        Write-Log "Error during language pack removal: $($_.Exception.Message)" -Level Error
        return $false
    }
}

# NOTE: Remove-EdgeBrowser and Remove-OneDrive functions have been moved
# to SystemOptimizer.ps1 for better organization (system optimizations vs package management)