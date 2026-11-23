# This exercise registers a temporary test certificate only on a disposable hosted runner.
$ErrorActionPreference = 'Stop'
if ($env:GITHUB_ACTIONS -ne 'true' -or $env:RUNNER_ENVIRONMENT -ne 'github-hosted') {
    throw 'Run this installation test on a disposable GitHub-hosted Windows runner.'
}
$store = (Resolve-Path 'dist/store').Path
$package = (Get-ChildItem $store -Filter 'ArrowKeys.CI_*.msix').FullName
$cert = New-SelfSignedCertificate -Type CodeSigningCert -Subject 'CN=ArrowKeys.CI' -CertStoreLocation Cert:\CurrentUser\My
$public = Join-Path $env:RUNNER_TEMP 'ArrowKeys.CI.cer'
Export-Certificate -Cert $cert -FilePath $public | Out-Null
Import-Certificate -FilePath $public -CertStoreLocation Cert:\LocalMachine\TrustedPeople | Out-Null
$sdk = Join-Path ${env:ProgramFiles(x86)} 'Windows Kits\10\bin'
$sign = Get-ChildItem $sdk -Directory | Where-Object Name -match '^10\.' | Sort-Object { [version]$_.Name } -Descending |
    ForEach-Object { Join-Path $_.FullName 'x64\signtool.exe' } | Where-Object { Test-Path $_ } | Select-Object -First 1
& $sign sign /fd SHA256 /sha1 $cert.Thumbprint $package
if ($LASTEXITCODE) { throw 'Package signing failed' }
Add-AppxPackage -Path $package
$app = Get-AppxPackage -Name ArrowKeys.CI
if (!$app) { throw 'Package registration failed' }
try {
    Start-Process explorer.exe -ArgumentList ("shell:AppsFolder\{0}!ArrowKeys" -f $app.PackageFamilyName)
    for ($i = 0; $i -lt 60; $i++) {
        $proc = Get-Process ArrowKeys -ErrorAction SilentlyContinue | Where-Object MainWindowTitle -eq 'Arrow Keys'
        if ($proc) { break }
        Start-Sleep -Milliseconds 500
    }
    if (!$proc -or $proc.Path -ne (Join-Path $app.InstallLocation 'ArrowKeys.exe')) { throw 'Packaged guide did not open' }
    $seen = Join-Path $env:LOCALAPPDATA "Packages\$($app.PackageFamilyName)\LocalState\guide-seen"
    if (!(Test-Path $seen)) { throw 'First-launch marker missing' }
    Add-Type -AssemblyName System.Drawing
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class GuideCapture {
    [StructLayout(LayoutKind.Sequential)] public struct Rect { public int Left,Top,Right,Bottom; }
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hwnd, out Rect rect);
    [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr hwnd, IntPtr dc, uint flags);
    [DllImport("user32.dll")] public static extern IntPtr SetThreadDpiAwarenessContext(IntPtr context);
}
'@
    $oldDpi = [GuideCapture]::SetThreadDpiAwarenessContext([IntPtr](-4))
    $rect = New-Object GuideCapture+Rect
    try {
        if (![GuideCapture]::GetWindowRect($proc.MainWindowHandle, [ref]$rect)) { throw 'Cannot measure shortcut guide' }
        $bitmap = [Drawing.Bitmap]::new(($rect.Right-$rect.Left), ($rect.Bottom-$rect.Top))
        $graphics = [Drawing.Graphics]::FromImage($bitmap)
        $dc = $graphics.GetHdc()
        try {
            if (![GuideCapture]::PrintWindow($proc.MainWindowHandle,$dc,2)) { throw 'Cannot capture shortcut guide' }
        } finally { $graphics.ReleaseHdc($dc); $graphics.Dispose() }
        $bitmap.Save((Join-Path $store 'Shortcut-guide.png'), [Drawing.Imaging.ImageFormat]::Png)
        $bitmap.Dispose()
    } finally { [void][GuideCapture]::SetThreadDpiAwarenessContext($oldDpi) }
    $trace = Join-Path $env:RUNNER_TEMP 'cursor-msix.log'
    $probePath = Join-Path $env:RUNNER_TEMP 'ArrowKeys-cursor-probe.exe'
    $probe = Start-Process $probePath -ArgumentList ('msix "{0}"' -f $trace) -PassThru
    if (!$probe.WaitForExit(60000)) { $probe.Kill(); throw 'Packaged cursor test timed out' }
    Get-Content $trace
    if ($probe.ExitCode) { throw 'Packaged cursor test failed' }
} finally {
    Remove-AppxPackage -Package $app.PackageFullName
}
if (Get-AppxPackage -Name ArrowKeys.CI) { throw 'Store package survived uninstall' }
if (Get-Process ArrowKeys -ErrorAction SilentlyContinue) { throw 'Store runtime survived uninstall' }
if (Get-StartApps | Where-Object AppID -eq "$($app.PackageFamilyName)!ArrowKeys") { throw 'Store Start registration survived uninstall' }
$removed = Join-Path $env:RUNNER_TEMP 'cursor-removed-msix.log'
$probe = Start-Process $probePath -ArgumentList ('removed "{0}"' -f $removed) -PassThru
if (!$probe.WaitForExit(60000)) { $probe.Kill(); throw 'Post-removal cursor test timed out' }
Get-Content $removed
if ($probe.ExitCode) { throw 'Normal typing was not restored after MSIX removal' }
