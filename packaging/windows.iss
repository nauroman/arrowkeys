[Setup]
AppId=nauroman.ArrowKeys
AppName=ArrowKeys
AppVersion=1.0.1
AppPublisher=Roman Naumov
AppPublisherURL=https://github.com/nauroman/arrowkeys
DefaultDirName={localappdata}\Programs\ArrowKeys
PrivilegesRequired=lowest
DisableDirPage=yes
DisableProgramGroupPage=yes
DisableWelcomePage=yes
UninstallDisplayIcon={app}\ArrowKeys.exe
Compression=lzma2
SolidCompression=yes
OutputDir={#Dist}
OutputBaseFilename=ArrowKeys-Windows-Setup
CloseApplications=yes
RestartApplications=no

[Files]
Source: "{#Runtime}\AutoHotkey32.exe"; DestDir: "{app}"; DestName: "ArrowKeys.exe"; Flags: ignoreversion
Source: "{#Runtime}\license.txt"; DestDir: "{app}"; DestName: "AutoHotkey-license.txt"; Flags: ignoreversion
Source: "..\arrowkeys.ahk"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\LICENSE"; DestDir: "{app}"; Flags: ignoreversion
Source: "AutoHotkey-source.url"; DestDir: "{app}"; Flags: ignoreversion

[Tasks]
Name: startup; Description: "Start ArrowKeys when I sign in"; Flags: checkedonce

[Icons]
Name: "{userprograms}\ArrowKeys"; Filename: "{app}\ArrowKeys.exe"; Parameters: """{app}\arrowkeys.ahk"""
Name: "{userstartup}\ArrowKeys"; Filename: "{app}\ArrowKeys.exe"; Parameters: """{app}\arrowkeys.ahk"""; Tasks: startup

[Run]
Filename: "{app}\ArrowKeys.exe"; Parameters: """{app}\arrowkeys.ahk"""; Flags: nowait

[UninstallRun]
Filename: "{app}\ArrowKeys.exe"; Parameters: "/restart ""{app}\arrowkeys.ahk"" --stop"; Flags: runhidden waituntilterminated skipifdoesntexist; RunOnceId: "StopArrowKeys"
