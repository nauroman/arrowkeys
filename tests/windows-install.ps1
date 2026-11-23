param([Parameter(Mandatory)][string]$Setup)
$ErrorActionPreference = 'Stop'
$dir = Join-Path $env:LOCALAPPDATA 'Programs\ArrowKeys'
$started = Start-Process $Setup -ArgumentList '/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART' -PassThru
if (!$started.WaitForExit(60000) -or $started.ExitCode -ne 0) { throw 'Installation failed' }
$runtime = Join-Path $dir 'ArrowKeys.exe'
$script = Join-Path $dir 'arrowkeys.ahk'
$shortcut = Join-Path ([Environment]::GetFolderPath('Startup')) 'ArrowKeys.lnk'
if (!(Test-Path $shortcut) -or (Get-FileHash $script).Hash -ne (Get-FileHash "$PSScriptRoot/../arrowkeys.ahk").Hash) { throw 'Installed files or sign-in shortcut missing' }
$process = Get-Process ArrowKeys | Where-Object Path -eq $runtime
if (!$process) { throw 'ArrowKeys did not start' }
$process | Stop-Process
$uninstall = Start-Process "$dir\unins000.exe" -ArgumentList '/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART' -Wait -PassThru
if ($uninstall.ExitCode -ne 0 -or (Test-Path $shortcut) -or (Test-Path $script)) { throw 'Uninstall failed' }
