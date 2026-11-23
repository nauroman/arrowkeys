param([Parameter(Mandatory)][string]$Setup)
$ErrorActionPreference = 'Stop'
$dir = Join-Path $env:LOCALAPPDATA 'Programs\ArrowKeys'
$runtime = Join-Path $dir 'ArrowKeys.exe'
$script = Join-Path $dir 'arrowkeys.ahk'
$startup = Join-Path ([Environment]::GetFolderPath('Startup')) 'ArrowKeys.lnk'
$probeHost = Join-Path $env:RUNNER_TEMP 'ArrowKeys-cursor-probe.exe'
$compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
& $compiler /nologo /target:winexe "/out:$probeHost" "$PSScriptRoot\WindowsCursor.cs"
if ($LASTEXITCODE -ne 0) { throw 'Cannot build the Win32 input probe' }

function Test-Cursor([string]$Mode) {
    $trace = Join-Path $env:RUNNER_TEMP "cursor-$Mode.log"
    $arguments = "$Mode `"$trace`""
    $probe = Start-Process $probeHost -ArgumentList $arguments -PassThru
    $finished = $probe.WaitForExit(60000)
    if (Test-Path $trace) { Get-Content $trace }
    if (!$finished) { $probe.Kill(); throw "Cursor test timeout ($Mode)" }
    if ($probe.ExitCode -ne 0) { throw "Cursor test failed ($Mode), exit $($probe.ExitCode)" }
}
for ($cycle = 1; $cycle -le 2; $cycle++) {
    Write-Host "Installing ArrowKeys (cycle $cycle)"
    $started = Start-Process $Setup -ArgumentList '/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART' -PassThru
    if (!$started.WaitForExit(60000) -or $started.ExitCode -ne 0) { throw 'Installation failed' }
    if (!(Test-Path $startup) -or (Get-FileHash $script).Hash -ne (Get-FileHash "$PSScriptRoot/../arrowkeys.ahk").Hash) { throw 'Installed files or sign-in shortcut missing' }
    $icon = Join-Path $dir 'ArrowKeys.ico'
    $link = (New-Object -ComObject WScript.Shell).CreateShortcut($startup)
    if (($link.IconLocation -split ',')[0] -ne $icon -or
        (Get-FileHash $icon).Hash -ne (Get-FileHash "$PSScriptRoot/../assets/ArrowKeys.ico").Hash) { throw 'Installed shortcut icon mismatch' }
    if (!(Get-Process ArrowKeys | Where-Object Path -eq $runtime)) { throw 'ArrowKeys did not start' }
    Test-Cursor "installed-$cycle"
    Write-Host "Uninstalling the running remapper (cycle $cycle)"
    $log = Join-Path $env:RUNNER_TEMP "uninstall-$cycle.log"
    $uninstall = Start-Process "$dir\unins000.exe" -ArgumentList "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /LOG=`"$log`"" -PassThru
    if (!$uninstall.WaitForExit(60000)) { Get-Content $log -Tail 12; throw 'Uninstaller timeout' }
    if ($uninstall.ExitCode -ne 0 -or (Test-Path $startup) -or (Test-Path $runtime) -or (Test-Path $script)) { throw 'Uninstall failed' }
    if (Get-Process ArrowKeys -ErrorAction SilentlyContinue) { throw 'The remapper survived uninstall' }
    Test-Cursor removed
}
