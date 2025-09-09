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
        # Get all provisioned AppX packages with improved parsing
        Write-Log "Retrieving provisioned AppX packages..." -Level Info
        $dismOutput = & dism /English /Image:$MountPath /Get-ProvisionedAppxPackages 2>&1
        
        # Parse DISM output more reliably
        $allPackages = @()
        foreach ($line in $dismOutput) {
            if ($line -match '^PackageName\s*:\s*(.+)$') {
                $packageName = $matches[1].Trim()
                if (-not [string]::IsNullOrEmpty($packageName)) {
                    $allPackages += $packageName
                }
            }
        }
        
        Write-Log "Found $($allPackages.Count) total AppX packages" -Level Info
        
        if ($allPackages.Count -eq 0) {
            Write-Log "No AppX packages found in the image" -Level Warning
            return $true
        }
        
        # Get bloatware package prefixes
        $bloatwarePrefixes = Get-BloatwarePackageList
        $packagesToRemove = @()
        
        # Find packages that match bloatware patterns
        foreach ($prefix in $bloatwarePrefixes) {
            $matchingPackages = $allPackages | Where-Object { $_ -like "$prefix*" }
            if ($matchingPackages) {
                $packagesToRemove += $matchingPackages
            }
        }
        
        # Remove duplicates
        $packagesToRemove = $packagesToRemove | Sort-Object -Unique
        
        if ($packagesToRemove.Count -eq 0) {
            Write-Log "No bloatware packages found to remove" -Level Info
            return $true
        }
        
        Write-Log "Found $($packagesToRemove.Count) bloatware packages to remove" -Level Info
        
        # Remove each package
        $successCount = 0
        $failCount = 0
        
        foreach ($package in $packagesToRemove) {
            try {
                Write-Log "Removing package: $package" -Level Info
                $dismResult = & dism /English /Image:$MountPath /Remove-ProvisionedAppxPackage /PackageName:$package 2>&1
                
                if ($LASTEXITCODE -eq 0) {
                    Write-Log "Successfully removed: $package" -Level Success
                    $successCount++
                }
                else {
                    Write-Log "Failed to remove: $package (Exit code: $LASTEXITCODE)" -Level Warning
                    Write-Log "DISM output: $($dismResult -join ' ')" -Level Warning
                    $failCount++
                }
            }
            catch {
                Write-Log "Error removing package $package`: $($_.Exception.Message)" -Level Error
                $failCount++
            }
        }
        
        # If DISM removal didn't work completely, try direct file removal
        if ($failCount -gt 0 -or $packagesToRemove.Count -eq 0) {
            Write-Log "Attempting direct AppX package directory removal..." -Level Info
            Remove-AppXDirectories -MountPath $MountPath
        }
        
        Write-Log "AppX package removal completed - Success: $successCount, Failed: $failCount" -Level Success
        return ($successCount -gt 0 -or $packagesToRemove.Count -eq 0)
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
        
        Write-Log "Retrieving installed packages..." -Level Info
        $dismOutput = & dism /English /Image:$MountPath /Get-Packages 2>&1
        
        # Parse package information more reliably
        $allPackages = @()
        $currentPackage = @{}
        
        foreach ($line in $dismOutput) {
            if ($line -match '^Package Identity\s*:\s*(.+)$') {
                if ($currentPackage.Identity) {
                    $allPackages += [PSCustomObject]$currentPackage
                }
                $currentPackage = @{ Identity = $matches[1].Trim() }
            }
            elseif ($line -match '^State\s*:\s*(.+)$') {
                $currentPackage.State = $matches[1].Trim()
            }
            elseif ($line -match '^Release Type\s*:\s*(.+)$') {
                $currentPackage.ReleaseType = $matches[1].Trim()
            }
        }
        
        # Add the last package
        if ($currentPackage.Identity) {
            $allPackages += [PSCustomObject]$currentPackage
        }
        
        Write-Log "Found $($allPackages.Count) total system packages" -Level Info
        
        $successCount = 0
        $failCount = 0
        
        foreach ($packagePattern in $packagePatterns) {
            # Find packages matching the pattern
            $matchingPackages = $allPackages | Where-Object { $_.Identity -like "$packagePattern*" -and $_.State -eq "Installed" }
            
            foreach ($package in $matchingPackages) {
                try {
                    Write-Log "Removing system package: $($package.Identity)" -Level Info
                    $dismResult = & dism /English /Image:$MountPath /Remove-Package /PackageName:$($package.Identity) 2>&1
                    
                    if ($LASTEXITCODE -eq 0) {
                        Write-Log "Successfully removed: $($package.Identity)" -Level Success
                        $successCount++
                    }
                    else {
                        Write-Log "Failed to remove: $($package.Identity) (Exit code: $LASTEXITCODE)" -Level Warning
                        Write-Log "DISM output: $($dismResult -join ' ')" -Level Warning
                        $failCount++
                    }
                }
                catch {
                    Write-Log "Error removing package $($package.Identity)`: $($_.Exception.Message)" -Level Error
                    $failCount++
                }
            }
        }
        
        Write-Log "System package removal completed - Success: $successCount, Failed: $failCount" -Level Success
        return ($successCount -gt 0 -or $packagePatterns.Count -eq 0)
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
        # Internet Explorer (legacy browser)
        "Microsoft-Windows-InternetExplorer-Optional-Package",
        
        # WordPad (replaced by modern apps)
        "Microsoft-Windows-WordPad-FoD-Package",
        
        # Math Input Panel (legacy touch input)
        "Microsoft-Windows-TabletPCMath-Package",
        
        # Steps Recorder (rarely used diagnostic tool)
        "Microsoft-Windows-StepsRecorder-Package",
        
        # Windows Media Player (legacy, replaced by Media Player app)
        "Microsoft-Windows-MediaPlayer-Package",
        
        # Extended wallpaper content (reduces image size)
        "Microsoft-Windows-Wallpaper-Content-Extended-FoD-Package",
        
        # LA57 kernel feature (not needed for most hardware)
        "Microsoft-Windows-Kernel-LA57-FoD-Package",
        
        # Language-specific features (optional for base functionality)
        "Microsoft-Windows-LanguageFeatures-Handwriting-$LanguageCode-Package",
        "Microsoft-Windows-LanguageFeatures-OCR-$LanguageCode-Package",
        "Microsoft-Windows-LanguageFeatures-Speech-$LanguageCode-Package", 
        "Microsoft-Windows-LanguageFeatures-TextToSpeech-$LanguageCode-Package",
        
        # Hello Face features (biometric authentication - optional)
        "Microsoft-Windows-Hello-Face-Package",
        
        # Windows PowerShell ISE (legacy, replaced by VS Code/modern editors)
        "Microsoft-Windows-PowerShell-ISE-FOD-Package",
        
        # Print Management Console (enterprise feature)
        "Microsoft-Windows-Printing-PrintToPDFServices-Package",
        
        # XPS features (legacy document format)  
        "Microsoft-Windows-Printing-XPSServices-Package"
        
        # Note: Windows Defender is handled separately in SecurityManager.ps1
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

function Remove-AppXDirectories {
    <#
    .SYNOPSIS
        Directly removes AppX package directories when DISM removal fails
        
    .PARAMETER MountPath
        Path to the mounted Windows image
    #>
    param(
        [Parameter(Mandatory)]
        [string]$MountPath
    )
    
    Write-Log "Starting direct AppX directory removal..." -Level Info
    
    try {
        $windowsAppsPath = "$MountPath\Program Files\WindowsApps"
        
        if (-not (Test-Path $windowsAppsPath)) {
            Write-Log "WindowsApps directory not found, skipping direct removal" -Level Warning
            return $true
        }
        
        # Get all directories in WindowsApps
        $allAppDirs = Get-ChildItem -Path $windowsAppsPath -Directory -ErrorAction SilentlyContinue
        
        if (-not $allAppDirs) {
            Write-Log "No app directories found in WindowsApps" -Level Info
            return $true
        }
        
        # Get bloatware patterns
        $bloatwarePatterns = Get-BloatwarePackageList
        $removedCount = 0
        $failedCount = 0
        
        foreach ($appDir in $allAppDirs) {
            $shouldRemove = $false
            
            # Check if this directory matches any bloatware pattern
            foreach ($pattern in $bloatwarePatterns) {
                if ($appDir.Name -like "$pattern*") {
                    $shouldRemove = $true
                    break
                }
            }
            
            if ($shouldRemove) {
                try {
                    Write-Log "Removing AppX directory: $($appDir.Name)" -Level Info
                    
                    # Take ownership and set permissions
                    & takeown /f $appDir.FullName /r /d y 2>&1 | Out-Null
                    & icacls $appDir.FullName /grant "Administrators:(F)" /T /C 2>&1 | Out-Null
                    
                    # Remove the directory
                    Remove-Item -Path $appDir.FullName -Recurse -Force -ErrorAction SilentlyContinue
                    
                    # Verify removal
                    if (-not (Test-Path $appDir.FullName)) {
                        Write-Log "Successfully removed AppX directory: $($appDir.Name)" -Level Success
                        $removedCount++
                    }
                    else {
                        Write-Log "Failed to remove AppX directory: $($appDir.Name)" -Level Warning
                        $failedCount++
                    }
                }
                catch {
                    Write-Log "Error removing AppX directory $($appDir.Name): $($_.Exception.Message)" -Level Warning
                    $failedCount++
                }
            }
        }
        
        Write-Log "Direct AppX directory removal completed - Removed: $removedCount, Failed: $failedCount" -Level Success
        return $true
    }
    catch {
        Write-Log "Direct AppX directory removal failed: $($_.Exception.Message)" -Level Error
        return $false
    }
}

# NOTE: Remove-EdgeBrowser and Remove-OneDrive functions have been moved
# to SystemOptimizer.ps1 for better organization (system optimizations vs package management)