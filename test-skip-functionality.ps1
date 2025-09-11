#requires -Version 5.1

<#
.SYNOPSIS
    Test script for the interactive skip functionality
.DESCRIPTION
    Simulates the WinSxS process behavior to test the Wait-ForProcessWithSkip function
#>

# Import the SystemOptimizer module to access Wait-ForProcessWithSkip
. "$PSScriptRoot\Modules\SystemOptimizer.ps1"

# Mock Write-Log function for testing
function Write-Log {
    param($Message, $Level = 'Info')
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        'Success' { 'Green' }
        'Warning' { 'Yellow' }
        'Error' { 'Red' }
        default { 'White' }
    }
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

Write-Host "=== Testing Interactive Skip Functionality ===" -ForegroundColor Cyan
Write-Host "This test simulates a long-running DISM process" -ForegroundColor Cyan
Write-Host "Press 'S' to test the skip functionality, or wait for timeout" -ForegroundColor Cyan
Write-Host ""

# Create a mock long-running process (sleep for 60 seconds)
if ($IsWindows -or $PSVersionTable.PSVersion.Major -le 5) {
    # Windows - use timeout command
    $testProcess = Start-Process -FilePath "timeout" -ArgumentList "60" -PassThru -WindowStyle Hidden
} else {
    # Linux/Mac - use sleep command
    $testProcess = Start-Process -FilePath "sleep" -ArgumentList "60" -PassThru
}

Write-Log "Started test process with PID: $($testProcess.Id)" -Level Info
Write-Log "Testing Wait-ForProcessWithSkip with 30-second timeout..." -Level Info

# Test the Wait-ForProcessWithSkip function
$skipped = Wait-ForProcessWithSkip -Process $testProcess -TimeoutSeconds 30 -TaskName "test operation"

if ($skipped) {
    Write-Log "SUCCESS: User skip functionality works correctly!" -Level Success
} else {
    Write-Log "Process completed or timed out without user skip" -Level Info
}

# Clean up
if (-not $testProcess.HasExited) {
    $testProcess.Kill()
    Write-Log "Cleaned up test process" -Level Info
}

Write-Host ""
Write-Host "=== Test Complete ===" -ForegroundColor Cyan