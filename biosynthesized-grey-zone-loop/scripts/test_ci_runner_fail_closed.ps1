$ErrorActionPreference = "Stop"

$projectDir = $PSScriptRoot | Split-Path -Parent
$runner = Join-Path $PSScriptRoot "loop_verify.ps1"
$fixtureSource = Join-Path $projectDir "tests\fixtures\ci_invalid_parse.gd.txt"
$fixtureTarget = Join-Path $projectDir "tests\ci_invalid_parse.gd"

Copy-Item -LiteralPath $fixtureSource -Destination $fixtureTarget
try {
    & powershell.exe -ExecutionPolicy Bypass -File $runner `
        -TargetTest "tests/ci_invalid_parse.gd" `
        -ExpectedStartMarker "CI-NEGATIVE-START" `
        -ExpectedPassMarker "CI-NEGATIVE-PASS" `
        -SkipImport `
        -NoStateWrite
    if ($LASTEXITCODE -eq 0) {
        Write-Error "CI-05 FAIL: intentionally invalid GDScript was reported as PASS"
        exit 1
    }
    Write-Host "CI-05 PASS: intentionally invalid GDScript forced runner failure"
} finally {
    Remove-Item -LiteralPath $fixtureTarget -Force -ErrorAction SilentlyContinue
}
