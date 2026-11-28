# Start the standalone script and the Store edition one after the other, as happens when someone
# has both or a Store update leaves the old version running. The copy started last must close the
# other one: with two copies, holding Caps Lock moved the cursor once and then typed letters.
# Needs the signed CI package and the cursor probe from windows-store.ps1 and windows-install.ps1.
param([Parameter(Mandatory)][string]$Setup)
$ErrorActionPreference = 'Stop'
if ($env:GITHUB_ACTIONS -ne 'true' -or $env:RUNNER_ENVIRONMENT -ne 'github-hosted') {
    throw 'Run this installation test on a disposable GitHub-hosted Windows runner.'
}
$probePath = Join-Path $env:RUNNER_TEMP 'ArrowKeys-cursor-probe.exe'
$package = (Get-ChildItem (Resolve-Path 'dist/store') -Filter 'ArrowKeys.CI_*.msix').FullName
$dir = Join-Path $env:LOCALAPPDATA 'Programs\ArrowKeys'
$runtime = Join-Path $dir 'ArrowKeys.exe'

function Test-OnlyCopy([string]$Path, [string]$Mode) {
    for ($i = 0; $i -lt 40; $i++) {
        $copies = @(Get-Process ArrowKeys -ErrorAction SilentlyContinue | ForEach-Object Path)
        if ($copies.Count -eq 1 -and $copies[0] -eq $Path) { break }
        Start-Sleep -Milliseconds 250
    }
    Write-Host "Running copies ($Mode): $($copies -join ', ')"
    if ($copies.Count -ne 1 -or $copies[0] -ne $Path) { throw "The copy started last did not close the other one ($Mode)" }
    $trace = Join-Path $env:RUNNER_TEMP "cursor-$Mode.log"
    $probe = Start-Process $probePath -ArgumentList ('{0} "{1}"' -f $Mode,$trace) -PassThru
    $finished = $probe.WaitForExit(60000)
    if (Test-Path $trace) { Get-Content $trace }
    if (!$finished) { $probe.Kill(); throw "Cursor test timeout ($Mode)" }
    if ($probe.ExitCode) { throw "Cursor test failed ($Mode)" }
}

$started = Start-Process $Setup -ArgumentList '/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART' -PassThru
if (!$started.WaitForExit(60000) -or $started.ExitCode -ne 0) { throw 'Installation failed' }
if (!(Get-Process ArrowKeys | Where-Object Path -eq $runtime)) { throw 'The standalone edition did not start' }
Add-AppxPackage -Path $package
$app = Get-AppxPackage -Name ArrowKeys.CI
try {
    Start-Process explorer.exe -ArgumentList ("shell:AppsFolder\{0}!ArrowKeys" -f $app.PackageFamilyName)
    Test-OnlyCopy (Join-Path $app.InstallLocation 'ArrowKeys.exe') 'store-started-last'
    Start-Process $runtime -ArgumentList ('"{0}"' -f (Join-Path $dir 'arrowkeys.ahk'))
    Test-OnlyCopy $runtime 'standalone-started-last'
} finally {
    Remove-AppxPackage -Package $app.PackageFullName
    $uninstall = Start-Process "$dir\unins000.exe" -ArgumentList '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART' -PassThru
    if (!$uninstall.WaitForExit(60000) -or $uninstall.ExitCode -ne 0) { throw 'Standalone uninstall failed' }
}
if (Get-Process ArrowKeys -ErrorAction SilentlyContinue) { throw 'A copy survived removing both editions' }
Write-Host 'Whichever edition started last closed the other, and held Caps Lock kept moving the cursor.'
