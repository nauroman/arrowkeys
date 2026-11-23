[CmdletBinding()]
param(
    [string]$Icon = (Join-Path $PSScriptRoot '..\assets\ArrowKeys.png'),
    [Parameter(Mandatory)][string]$IdentityName,
    [Parameter(Mandatory)][string]$Publisher,
    [Parameter(Mandatory)][string]$PublisherDisplayName,
    [Parameter(Mandatory)][version]$Version,
    [string]$DisplayName = 'Arrow Keys'
)

$ErrorActionPreference = 'Stop'
if ($Version.Revision -ne 0) { throw 'Supply a four-part Store version ending in .0.' }
$root = Split-Path $PSScriptRoot -Parent
$source = Join-Path $PSScriptRoot 'store'
$work = [IO.Directory]::CreateDirectory((Join-Path $root '.store-build')).FullName
$output = [IO.Directory]::CreateDirectory((Join-Path $root 'dist\store')).FullName
$stage = [IO.Directory]::CreateDirectory((Join-Path $work ([guid]::NewGuid()))).FullName
$assets = Join-Path $stage 'Assets'

function Get-VerifiedTool([string]$Url, [string]$Sha256) {
    $archive = Join-Path $work "$Sha256.zip"
    if (!(Test-Path -LiteralPath $archive) -or (Get-FileHash -LiteralPath $archive).Hash -ne $Sha256) {
        Invoke-WebRequest -UseBasicParsing -Uri $Url -OutFile $archive
    }
    if ((Get-FileHash -LiteralPath $archive).Hash -ne $Sha256) { throw "Checksum mismatch for $Url" }
    $dir = Join-Path $work $Sha256
    Expand-Archive -LiteralPath $archive -DestinationPath $dir -Force
    return $dir
}

$ahk = Get-VerifiedTool 'https://github.com/AutoHotkey/AutoHotkey/releases/download/v2.0.32/AutoHotkey_2.0.32.zip' '384a4c125e8d7b5b77ddbd5a593ec761d3e9e96e97a95931cf56e9a077fda114'
$compiler = Get-VerifiedTool 'https://github.com/AutoHotkey/Ahk2Exe/releases/download/Ahk2Exe1.1.37.02a2/Ahk2Exe1.1.37.02a2.zip' 'c29b8c3a5124850d79fc9e66e2ca79677c377d7f31631ad3022ba159c5d9e3be'
& python (Join-Path $source 'export-icons.py') (Resolve-Path -LiteralPath $Icon).Path $assets $output
if ($LASTEXITCODE) { throw 'Icon export failed. Install Python and Pillow.' }

$runtime = Join-Path $ahk 'AutoHotkey32.exe'
$script = Join-Path $source 'ArrowKeys.ahk'
$executable = Join-Path $stage 'ArrowKeys.exe'
& $runtime /ErrorStdOut /validate $script | Out-Host
if ($LASTEXITCODE) { throw 'AutoHotkey source validation failed.' }
$compileArgs = '/in "{0}" /out "{1}" /base "{2}" /icon "{3}" /compress 0 /silent verbose' -f $script,$executable,$runtime,(Join-Path $output 'ArrowKeys.ico')
$compiled = Start-Process (Join-Path $compiler 'Ahk2Exe.exe') -ArgumentList $compileArgs -Wait -PassThru -WindowStyle Hidden
if ($compiled.ExitCode -or !(Test-Path -LiteralPath $executable)) { throw 'ArrowKeys compilation failed.' }
Copy-Item -LiteralPath (Join-Path $root 'keyboard.png'),(Join-Path $root 'LICENSE'),(Join-Path $root 'PRIVACY.md'),(Join-Path $PSScriptRoot 'AutoHotkey-source.url') -Destination $stage
Copy-Item -LiteralPath (Join-Path $ahk 'license.txt') -Destination (Join-Path $stage 'AutoHotkey-license.txt')

[xml]$xml = Get-Content -LiteralPath (Join-Path $source 'AppxManifest.xml') -Raw
$xml.Package.Identity.Name = $IdentityName
$xml.Package.Identity.Publisher = $Publisher
$xml.Package.Identity.Version = $Version.ToString()
$xml.Package.Properties.DisplayName = $DisplayName
$xml.Package.Properties.PublisherDisplayName = $PublisherDisplayName
$app = $xml.Package.Applications.Application
$app.VisualElements.DisplayName = $DisplayName
$app.Extensions.Extension.StartupTask.DisplayName = $DisplayName
$xml.Save((Join-Path $stage 'AppxManifest.xml'))
$sdkRoot = Join-Path ${env:ProgramFiles(x86)} 'Windows Kits\10\bin'
$makeAppx = Get-ChildItem -LiteralPath $sdkRoot -Directory | Where-Object { $_.Name -match '^10\.0\.\d+\.\d+$' } |
    Sort-Object { [version]$_.Name } -Descending | ForEach-Object { Join-Path $_.FullName 'x64\makeappx.exe' } |
    Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (!$makeAppx) { throw 'Install the Windows 10 or 11 SDK with MakeAppx.' }
$makePri = Join-Path (Split-Path $makeAppx) 'makepri.exe'
$config = Join-Path $work 'store-priconfig.xml'
& $makePri createconfig /cf $config /dq en-US /o
if ($LASTEXITCODE) { throw 'Resource index configuration failed.' }
# Every display scale ships in the same MSIX.
[xml]$indexConfig = Get-Content -LiteralPath $config -Raw
[void]$indexConfig.DocumentElement.RemoveChild($indexConfig.resources.packaging)
$indexConfig.Save($config)
& $makePri new /pr $stage /cf $config /of (Join-Path $stage 'resources.pri') /o
if ($LASTEXITCODE) { throw 'Indexing the Windows icon sizes failed.' }
$package = Join-Path $output ("{0}_{1}_x86.msix" -f $IdentityName,$Version)
& $makeAppx pack /d $stage /p $package /o
if ($LASTEXITCODE) { throw 'MSIX packaging failed.' }
Get-FileHash -Algorithm SHA256 -LiteralPath $package
