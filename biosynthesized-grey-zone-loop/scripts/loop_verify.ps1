# =============================================================================
# Loop Infrastructure v0 — Deterministic Headless Verification Runner
# Runs required test suite with Godot Console binary and collects Gate results.
# =============================================================================
param (
    [string]$TargetTest = "",
    [string]$ExpectedStartMarker = "",
    [string]$ExpectedPassMarker = "",
    [switch]$SkipImport,
    [switch]$NoStateWrite
)

$ErrorActionPreference = "Stop"
$ProjectDir = $PSScriptRoot | Split-Path -Parent
$PolicyFile = Join-Path $ProjectDir "loop\policy.json"
$StateFile = Join-Path $ProjectDir "loop\state.json"
$AttemptsFile = Join-Path $ProjectDir "loop\attempts.jsonl"
$LogDir = if ($env:GATE_LOG_DIR) { $env:GATE_LOG_DIR } else { Join-Path ([IO.Path]::GetTempPath()) "aether-fountain-gates" }

if (-not (Test-Path $PolicyFile)) {
    Write-Error "FATAL: policy.json not found at $PolicyFile"
    exit 1
}

$policy = Get-Content $PolicyFile -Raw | ConvertFrom-Json
$godotExe = $env:GODOT_EXE

if (-not $godotExe -or -not (Test-Path $godotExe)) {
    $godotExe = $null
    foreach ($cand in $policy.engine_binary_candidates) {
        if (Test-Path $cand) {
            $godotExe = $cand
            break
        }
    }
}

if (-not $godotExe) {
    Write-Error "FATAL: No valid Godot console executable found (checked GODOT_EXE and policy candidates)."
    exit 1
}

$gateContracts = @{
    "scripts/test_terminal_flow_gate.gd" = @("[TERMINAL GATE]", "TERMINAL GATE RESULTS: 7 / 7 PASSED")
    "scripts/test_vfx_gate.gd" = @("[VFX GATE]", "VFX GATE RESULTS: 7 / 7 PASSED")
    "scripts/test_exploration_gate.gd" = @("[EXP GATE]", "EXP GATE RESULTS: 7 / 7 PASSED")
    "scripts/test_deployment_loop.gd" = @("[VERIFICATION SUITE]", "TOTAL PASSED: 7/7 | TOTAL FAILED: 0/7")
    "scripts/test_deterministic_combat_gate.gd" = @("[COMBAT RNG GATE]", "COMBAT RNG GATE RESULTS: 3 / 3 PASSED")
    "scripts/test_ledger_integrity_gate.gd" = @("[LEDGER INTEGRITY GATE]", "LEDGER INTEGRITY GATE RESULTS: 4 / 4 PASSED")
    "scripts/test_expedition_decision_gate.gd" = @("[EXP DECISION GATE]", "EXPEDITION DECISION GATE RESULTS: 5 / 5 PASSED")
    "scripts/test_npc_dialogue_gate.gd" = @("[NPC DIALOGUE GATE]", "NPC DIALOGUE GATE RESULTS: 3 / 3 PASSED")
    "scripts/test_dialogue_presentation_gate.gd" = @("[PRESENTATION GATE]", "PRESENTATION GATE RESULTS: 3 / 3 PASSED")
    "tests/test_bio_data_v0.gd" = @("[BIO-DATA-v0]", "BIO-DATA-v0 RESULT | 5/5 PASS | 0 FAIL")
}

function Invoke-GodotProcess {
    param ([string]$Arguments)

    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = $godotExe
    $startInfo.Arguments = $Arguments
    $startInfo.WorkingDirectory = $ProjectDir
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true

    $proc = [System.Diagnostics.Process]::Start($startInfo)
    $stdOutTask = $proc.StandardOutput.ReadToEndAsync()
    $stdErrTask = $proc.StandardError.ReadToEndAsync()
    $proc.WaitForExit()
    return @{
        ExitCode = $proc.ExitCode
        Output = "$($stdOutTask.Result)`n$($stdErrTask.Result)"
    }
}

function Test-FatalDiagnostics {
    param ([string]$Output)
    return $Output -match "(?im)^\s*(SCRIPT ERROR:|.*Parse Error:|ERROR: Failed to load script|FATAL:|\[FAIL\]|FAIL:)"
}

New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

if (-not $SkipImport) {
    Write-Host "Importing Godot project and registering scripts..."
    $importResult = Invoke-GodotProcess "--headless --editor --path `"$ProjectDir`" --quit"
    $importLog = Join-Path $LogDir "godot-import.log"
    $importResult.Output | Set-Content -Path $importLog -Encoding UTF8
    if ($importResult.ExitCode -ne 0 -or (Test-FatalDiagnostics $importResult.Output)) {
        Write-Host "  [FAIL] Godot project import/script parse failed. Raw log: $importLog" -ForegroundColor Red
        exit 1
    }
    Write-Host "  [PASS] Godot project import/script parse completed" -ForegroundColor Green
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

    $normalizedTest = $testRel.Replace("\", "/")
    $contract = $gateContracts[$normalizedTest]
    $startMarker = if ($ExpectedStartMarker) { $ExpectedStartMarker } elseif ($contract) { $contract[0] } else { "" }
    $passMarker = if ($ExpectedPassMarker) { $ExpectedPassMarker } elseif ($contract) { $contract[1] } else { "" }
    if (-not $startMarker -or -not $passMarker) {
        Write-Host "  [FAIL] No explicit marker contract for $testRel" -ForegroundColor Red
        $failed += $testRel
        continue
    }

    $result = Invoke-GodotProcess "--headless --path `"$ProjectDir`" --script `"$testRel`""
    $exitCode = $result.ExitCode
    $output = $result.Output
    $safeName = ($normalizedTest -replace "[^A-Za-z0-9._-]", "_")
    $rawLog = Join-Path $LogDir "$safeName.log"
    $output | Set-Content -Path $rawLog -Encoding UTF8

    # Log raw output snippet
    $outputLines = $output -split "`r?`n"
    $summaryLines = $outputLines | Select-String -Pattern "PASS:|FAIL:|TERMINAL GATE RESULTS:|VFX GATE RESULTS:|FATAL:"

    $started = $output.Contains($startMarker)
    $completed = $output.Contains($passMarker)
    $fatalDiagnostics = Test-FatalDiagnostics $output

    if ($exitCode -eq 0 -and $started -and $completed -and -not $fatalDiagnostics) {
        Write-Host "  [PASS] $testRel (exit=0, start marker and final PASS marker verified)" -ForegroundColor Green
        $passed += $testRel
    } else {
        Write-Host "  [FAIL] $testRel (exit=$exitCode, started=$started, completed=$completed, fatal=$fatalDiagnostics)" -ForegroundColor Red
        Write-Host "         Raw log: $rawLog" -ForegroundColor Red
        $failed += $testRel
    }

    foreach ($line in $summaryLines) {
        Write-Host "    $line"
    }
}

$overallResult = if ($failed.Count -eq 0) { "PASS" } else { "FAIL" }

if (-not $NoStateWrite) {
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
}

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " LOOP RESULT: $overallResult ($($passed.Count) passed, $($failed.Count) failed)" -ForegroundColor $(if ($overallResult -eq "PASS") { "Green" } else { "Red" })
Write-Host " Raw logs: $LogDir"
Write-Host "============================================================"

if ($overallResult -eq "PASS") {
    exit 0
} else {
    exit 1
}
