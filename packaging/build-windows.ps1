param([Parameter(Mandatory)][string]$OutputDirectory)
$ErrorActionPreference = 'Stop'
$dist = [IO.Directory]::CreateDirectory($OutputDirectory).FullName
$stage = (New-Item -ItemType Directory -Path (Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid()))).FullName
try {
    $archive = Join-Path $stage 'AutoHotkey.zip'
    Invoke-WebRequest 'https://github.com/AutoHotkey/AutoHotkey/releases/download/v2.0.32/AutoHotkey_2.0.32.zip' -OutFile $archive
    if ((Get-FileHash $archive).Hash -ne '384a4c125e8d7b5b77ddbd5a593ec761d3e9e96e97a95931cf56e9a077fda114') {
        throw 'The AutoHotkey archive failed SHA-256 verification.'
    }
    Expand-Archive -LiteralPath $archive -DestinationPath $stage
    $iscc = Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 6\ISCC.exe'
    & $iscc "/DDist=$dist" "/DRuntime=$stage" "$PSScriptRoot\windows.iss"
    if ($LASTEXITCODE -ne 0) { throw "Inno Setup exited with $LASTEXITCODE" }
} finally {
    if ([IO.Path]::GetDirectoryName($stage) -eq [IO.Path]::GetTempPath().TrimEnd('\')) {
        Remove-Item -LiteralPath $stage -Recurse -Force
    }
}
