[Setup]
AppId=nauroman.ArrowKeys
AppName=ArrowKeys
AppVersion=1.1.1
AppPublisher=Roman Naumov
AppPublisherURL=https://github.com/nauroman/arrowkeys
AppUpdatesURL=https://github.com/nauroman/arrowkeys/releases
DefaultDirName={localappdata}\Programs\ArrowKeys
PrivilegesRequired=lowest
DisableDirPage=yes
DisableProgramGroupPage=yes
DisableWelcomePage=no
SetupIconFile=..\assets\ArrowKeys.ico
UninstallDisplayIcon={app}\ArrowKeys.ico
Compression=lzma2
SolidCompression=yes
OutputDir={#Dist}
OutputBaseFilename=ArrowKeys-Windows-Setup
CloseApplications=yes
RestartApplications=no

[Files]
Source: "..\assets\ArrowKeys.ico"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#Runtime}\AutoHotkey32.exe"; DestDir: "{app}"; DestName: "ArrowKeys.exe"; Flags: ignoreversion
Source: "{#Runtime}\license.txt"; DestDir: "{app}"; DestName: "AutoHotkey-license.txt"; Flags: ignoreversion
Source: "..\arrowkeys.ahk"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\LICENSE"; DestDir: "{app}"; Flags: ignoreversion
Source: "AutoHotkey-source.url"; DestDir: "{app}"; Flags: ignoreversion

[Tasks]
Name: startup; Description: "Start ArrowKeys when I sign in"; Flags: checkedonce

[Icons]
Name: "{userprograms}\ArrowKeys"; Filename: "{app}\ArrowKeys.exe"; Parameters: """{app}\arrowkeys.ahk"""; IconFilename: "{app}\ArrowKeys.ico"
Name: "{userstartup}\ArrowKeys"; Filename: "{app}\ArrowKeys.exe"; Parameters: """{app}\arrowkeys.ahk"""; IconFilename: "{app}\ArrowKeys.ico"; Tasks: startup

[Run]
Filename: "{app}\ArrowKeys.exe"; Parameters: """{app}\arrowkeys.ahk"""; Flags: nowait

[UninstallRun]
Filename: "{app}\ArrowKeys.exe"; Parameters: "/restart ""{app}\arrowkeys.ahk"" --stop"; Flags: runhidden waituntilterminated skipifdoesntexist; RunOnceId: "StopArrowKeys"

[Code]
procedure OpenProjectLink(Sender: TObject; const Link: string; LinkType: TSysLinkType);
var
  ErrorCode: Integer;
begin
  if LinkType = sltURL then
    ShellExecAsOriginalUser('open', Link, '', '', SW_SHOWNORMAL, ewNoWait, ErrorCode);
end;

procedure InitializeWizard;
var
  Info: TNewLinkLabel;
begin
  Info := TNewLinkLabel.Create(WizardForm);
  Info.Parent := WizardForm.WelcomeLabel2.Parent;
  Info.AutoSize := False;
  Info.SetBounds(WizardForm.WelcomeLabel2.Left, WizardForm.WelcomeLabel2.Top,
                 WizardForm.WelcomeLabel2.Width, WizardForm.WelcomeLabel2.Height);
  WizardForm.WelcomeLabel2.Visible := False;
  Info.Caption := 'ArrowKeys lets you move through text with Caps Lock and the letter keys.' + #13#10#13#10 +
    'You can <a href="https://github.com/nauroman/arrowkeys">review the source code on GitHub</a> or ' +
    '<a href="https://github.com/nauroman/arrowkeys/releases">download the installers and SHA-256 checksums</a> to verify your copy.';
  Info.AdjustHeight;
  Info.OnLinkClick := @OpenProjectLink;
end;
