# Run the standalone script and the Store edition at the same time, as happens when someone
# installs both or an update leaves the old copy running. Needs the signed CI package and the
# cursor probe from windows-store.ps1 and windows-install.ps1.
param([Parameter(Mandatory)][string]$Setup)
$ErrorActionPreference = 'Stop'
if ($env:GITHUB_ACTIONS -ne 'true' -or $env:RUNNER_ENVIRONMENT -ne 'github-hosted') {
    throw 'Run this installation test on a disposable GitHub-hosted Windows runner.'
}
$probePath = Join-Path $env:RUNNER_TEMP 'ArrowKeys-cursor-probe.exe'
$package = (Get-ChildItem (Resolve-Path 'dist/store') -Filter 'ArrowKeys.CI_*.msix').FullName
$dir = Join-Path $env:LOCALAPPDATA 'Programs\ArrowKeys'
$runtime = Join-Path $dir 'ArrowKeys.exe'

function Test-Cursor([string]$Mode) {
    $copies = @(Get-Process ArrowKeys -ErrorAction SilentlyContinue | ForEach-Object Path)
    Write-Host "Running copies: $($copies -join ', ')"
    if ($copies.Count -lt 2) { throw "Expected both editions to run ($Mode)" }
    $trace = Join-Path $env:RUNNER_TEMP "cursor-$Mode.log"
    $probe = Start-Process $probePath -ArgumentList ('{0} "{1}"' -f $Mode,$trace) -PassThru
    $finished = $probe.WaitForExit(90000)
    if (Test-Path $trace) { Get-Content $trace }
    if (!$finished) { $probe.Kill(); throw "Cursor test timeout ($Mode)" }
    if ($probe.ExitCode) { throw "Cursor test failed ($Mode)" }
}

$started = Start-Process $Setup -ArgumentList '/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART' -PassThru
if (!$started.WaitForExit(60000) -or $started.ExitCode -ne 0) { throw 'Installation failed' }
Add-AppxPackage -Path $package
$app = Get-AppxPackage -Name ArrowKeys.CI
$failed = @()
try {
    Start-Process explorer.exe -ArgumentList ("shell:AppsFolder\{0}!ArrowKeys" -f $app.PackageFamilyName)
    $storeExe = Join-Path $app.InstallLocation 'ArrowKeys.exe'
    for ($i = 0; $i -lt 60; $i++) {
        if (Get-Process ArrowKeys -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $storeExe -and $_.MainWindowTitle -eq 'Arrow Keys' }) { break }
        Start-Sleep -Milliseconds 500
    }
    Start-Sleep -Seconds 2
    try { Test-Cursor 'both-store-started-last' } catch { $failed += $_.Exception.Message }

    # Restart the standalone copy so its keyboard hook is the newest one.
    Start-Process $runtime -ArgumentList ('"{0}"' -f (Join-Path $dir 'arrowkeys.ahk'))
    Start-Sleep -Seconds 3
    try { Test-Cursor 'both-standalone-started-last' } catch { $failed += $_.Exception.Message }
} finally {
    Remove-AppxPackage -Package $app.PackageFullName
    $uninstall = Start-Process "$dir\unins000.exe" -ArgumentList '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART' -PassThru
    [void]$uninstall.WaitForExit(60000)
}
if ($failed) { throw ($failed -join '; ') }
Write-Host 'Both editions together moved the cursor correctly in either start order.'
