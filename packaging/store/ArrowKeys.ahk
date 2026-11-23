#Requires AutoHotkey v2.0
KeyHistory 0
;@Ahk2Exe-SetName Arrow Keys
;@Ahk2Exe-SetDescription Arrow Keys keyboard navigation
ListLines false

if A_Args.Length && A_Args[1] = "--stop"
    ExitApp

A_IconTip := "Arrow Keys"
A_TrayMenu.Delete()
A_TrayMenu.Add("Shortcut guide", ShowGuide)
A_TrayMenu.Default := "Shortcut guide"
A_TrayMenu.Add("Exit Arrow Keys", (*) => ExitApp())

; Windows supplies the same per-package LocalState on upgrades.
familyLength := 0
statePath := ""
if DllCall("GetCurrentPackageFamilyName", "uint*", &familyLength, "ptr", 0) = 122 {
    family := Buffer(familyLength * 2)
    if DllCall("GetCurrentPackageFamilyName", "uint*", &familyLength, "ptr", family) = 0
        statePath := EnvGet("LOCALAPPDATA") "\Packages\" StrGet(family, "UTF-16") "\LocalState"
}
if !statePath || !FileExist(statePath "\guide-seen") {
    ShowGuide()
    if statePath {
        DirCreate statePath
        FileAppend "", statePath "\guide-seen"
    }
}

ShowGuide(*) {
    static window := 0
    if !window {
        window := Gui(, "Arrow Keys")
        window.BackColor := "FAF9F6"
        window.MarginX := 24
        window.MarginY := 10
        window.SetFont("s21 Bold c202020", "Segoe UI")
        window.AddText("w560", "Hold Caps Lock to move")
        window.SetFont("s11 Norm c303030")
        window.AddText("w560", "Release Caps Lock to type normally. Alt also works with these keys.")
        window.AddPicture("w560 h-1", A_ScriptDir "\keyboard.png")
        window.SetFont("s11 Bold")
        window.AddText("w560", "Move the cursor")
        window.SetFont("s11 Norm")
        window.AddText("w560", "I   Up                 J   Left                 K   Down                 L   Right")
        window.AddText("w560", "U   Line start       O   Line end       H   Previous word       Semicolon   Next word")
        window.SetFont("s11 Bold")
        window.AddText("w560", "Try it here")
        window.SetFont("s11 Norm")
        sample := window.AddEdit("w560 r2", "Hold Caps Lock and tap H to move back one word.")
        window.AddText("w560", "To stop remapping, choose Exit Arrow Keys from the system tray.")
        window.AddLink("w560", 'On GitHub you can <a href="https://github.com/nauroman/arrowkeys">review the source</a> or <a href="https://github.com/nauroman/arrowkeys/releases">download installers and SHA-256 checksums</a>.')
        window.AddButton("xm w130 Default", "Hide guide").OnEvent("Click", (*) => window.Hide())
        window.OnEvent("Close", (*) => window.Hide())
        window.OnEvent("Escape", (*) => window.Hide())
        window.Show()
        sample.Focus()
        SendMessage(0xB1, -1, -1, sample.Hwnd)
        return
    }
    window.Show()
}

; The Store and standalone versions share all keyboard mappings.
#Include ..\..\arrowkeys.ahk
