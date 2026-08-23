# =============================================================================
# Loop Infrastructure v0 — Deterministic Headless Verification Runner
# Runs required test suite with Godot Console binary and collects Gate results.
# =============================================================================
param (
    [string]$TargetTest = ""
)

$ErrorActionPreference = "Stop"
$ProjectDir = $PSScriptRoot | Split-Path -Parent
$PolicyFile = Join-Path $ProjectDir "loop\policy.json"
$StateFile = Join-Path $ProjectDir "loop\state.json"
$AttemptsFile = Join-Path $ProjectDir "loop\attempts.jsonl"

if (-not (Test-Path $PolicyFile)) {
    Write-Error "FATAL: policy.json not found at $PolicyFile"
    exit 1
}

$policy = Get-Content $PolicyFile -Raw | ConvertFrom-Json
$godotExe = $null

foreach ($cand in $policy.engine_binary_candidates) {
    if (Test-Path $cand) {
        $godotExe = $cand
        break
    }
}

if (-not $godotExe) {
    Write-Error "FATAL: No valid Godot console executable found in candidate list."
    exit 1
}

$testsToRun = @()
if ($TargetTest -ne "") {
    $testsToRun += $TargetTest
} else {
    $testsToRun = $policy.required_test_suite
}

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " [LOOP RUNNER] Godot Headless Verification" -ForegroundColor Cyan
Write-Host " Engine:  $godotExe"
Write-Host " Tests:   $($testsToRun.Count) script(s)"
Write-Host "============================================================"

$passed = @()
$failed = @()
$timestamp = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")

foreach ($testRel in $testsToRun) {
    $testPath = Join-Path $ProjectDir $testRel
    if (-not (Test-Path $testPath)) {
        Write-Host "  [MISSING] $testRel" -ForegroundColor Red
        $failed += $testRel
        continue
    }

    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = $godotExe
    $startInfo.Arguments = "--headless -s $testRel"
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true

    $proc = [System.Diagnostics.Process]::Start($startInfo)
    $stdOutTask = $proc.StandardOutput.ReadToEndAsync()
    $stdErrTask = $proc.StandardError.ReadToEndAsync()
    $proc.WaitForExit()
    $stdOut = $stdOutTask.Result
    $stdErr = $stdErrTask.Result
    $exitCode = $proc.ExitCode
    $output = "$stdOut`n$stdErr"

    # Log raw output snippet
    $outputLines = $output -split "`r?`n"
    $summaryLines = $outputLines | Select-String -Pattern "PASS:|FAIL:|TERMINAL GATE RESULTS:|VFX GATE RESULTS:|FATAL:"

    if ($exitCode -eq 0) {
        Write-Host "  [PASS] $testRel (ExitCode: 0)" -ForegroundColor Green
        $passed += $testRel
    } else {
        Write-Host "  [FAIL] $testRel (ExitCode: $exitCode)" -ForegroundColor Red
        $failed += $testRel
    }

    foreach ($line in $summaryLines) {
        Write-Host "    $line"
    }
}

$overallResult = if ($failed.Count -eq 0) { "PASS" } else { "FAIL" }

# Update loop/state.json
$currentState = if (Test-Path $StateFile) { Get-Content $StateFile -Raw | ConvertFrom-Json } else { @{} }
$currentState.last_run_timestamp = $timestamp
$currentState.last_gate_result = $overallResult
$currentState.passed_gates = $passed
$currentState.failed_gates = $failed
$currentState.status = if ($overallResult -eq "PASS") { "READY_FOR_HUMAN_REVIEW" } else { "FAIL" }
$currentState.canonical_promotion_ready = ($overallResult -eq "PASS")

$currentState | ConvertTo-Json -Depth 5 | Set-Content $StateFile -Encoding UTF8

# Append to attempts.jsonl
$attemptRecord = @{
    "timestamp" = $timestamp
    "result" = $overallResult
    "passed_count" = $passed.Count
    "failed_count" = $failed.Count
    "failed_list" = $failed
} | ConvertTo-Json -Compress

Add-Content -Path $AttemptsFile -Value $attemptRecord -Encoding UTF8

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " LOOP RESULT: $overallResult ($($passed.Count) passed, $($failed.Count) failed)" -ForegroundColor $(if ($overallResult -eq "PASS") { "Green" } else { "Red" })
Write-Host " State written to: $StateFile"
Write-Host "============================================================"

if ($overallResult -eq "PASS") {
    exit 0
} else {
    exit 1
}
