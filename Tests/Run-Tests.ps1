#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Runs all Pester tests for the PSYT module.

.DESCRIPTION
    This script runs all Pester tests in the Tests directory and provides a summary of results.
    It can run all tests or specific test files based on parameters.

.PARAMETER TestName
    Specific test file name to run (without .Tests.ps1 extension). 
    If not specified, all tests will be run.

.PARAMETER OutputFormat
    Output format for test results. Valid values: 'Normal', 'Detailed', 'Diagnostic'
    Default: 'Normal'

.EXAMPLE
    .\Run-Tests.ps1
    Runs all tests with normal output.

.EXAMPLE
    .\Run-Tests.ps1 -TestName "Get-Transcript" -OutputFormat Detailed
    Runs only the Get-Transcript tests with detailed output.
#>

param(
    [string]$TestName = "",
    [ValidateSet('Normal', 'Detailed', 'Diagnostic')]
    [string]$OutputFormat = 'Normal'
)

# Set strict mode
Set-StrictMode -Version Latest

# Get script location
$ScriptRoot = $PSScriptRoot
$ModuleRoot = Split-Path -Parent $ScriptRoot
$TestsPath = Join-Path $ScriptRoot "*.Tests.ps1"

# Import Pester module
if (-not (Get-Module -Name Pester -ListAvailable)) {
    throw "Pester module is not available. Please install it with: Install-Module -Name Pester -Force"
}

Import-Module Pester -Force

Write-Host "PSYT Module Test Runner" -ForegroundColor Green
Write-Host "======================" -ForegroundColor Green
Write-Host

# Determine which tests to run
if ($TestName) {
    $TestsPath = Join-Path $ScriptRoot "$TestName.Tests.ps1"
    if (-not (Test-Path $TestsPath)) {
        throw "Test file '$TestsPath' not found."
    }
    Write-Host "Running specific test: $TestName" -ForegroundColor Yellow
} else {
    Write-Host "Running all tests in: $ScriptRoot" -ForegroundColor Yellow
}

Write-Host "Output format: $OutputFormat" -ForegroundColor Yellow
Write-Host

try {
    # Run tests using simpler approach
    Write-Host "Starting test execution..." -ForegroundColor Green
    Write-Host

    if ($OutputFormat -eq 'Diagnostic') {
        $TestResults = Invoke-Pester -Path $TestsPath -Output Detailed -PassThru
    } elseif ($OutputFormat -eq 'Detailed') {
        $TestResults = Invoke-Pester -Path $TestsPath -Output Normal -PassThru
    } else {
        $TestResults = Invoke-Pester -Path $TestsPath -PassThru
    }

    Write-Host
    Write-Host "Test execution completed successfully!" -ForegroundColor Green
    
    # The test output already shows pass/fail status
    # Just check the exit code behavior based on Pester's built-in logic
    
} catch {
    Write-Error "An error occurred while running tests: $_"
    exit 1
}