#Requires AutoHotkey v2.0
#SingleInstance Force

; The uninstaller starts this same script with /restart to retire its running copy.
if A_Args.Length && A_Args[1] = "--stop"
    ExitApp

; The Store executable embeds its icon. The standalone installer supplies it alongside the script.
if !A_IsCompiled && FileExist(A_ScriptDir "\ArrowKeys.ico")
    TraySetIcon A_ScriptDir "\ArrowKeys.ico"
else if !A_IsCompiled && FileExist(A_ScriptDir "\assets\ArrowKeys.ico")
    TraySetIcon A_ScriptDir "\assets\ArrowKeys.ico"

; The standalone script keeps AutoHotkey's standard tray items and adds About before Exit.
; The Store edition replaces the whole tray menu, including its own About item, so skip it there.
if !A_IsCompiled
    A_TrayMenu.Insert("E&xit", "About ArrowKeys", (*) => Run("https://nauroman.github.io/arrowkeys/"))

; Only one copy may run. The Store and standalone editions, or an older version a Store update
; left running, live in different folders, so #SingleInstance misses them. With two copies,
; holding Caps Lock moves the cursor once and then types letters. The copy started last stays.
CloseOtherCopies()

CloseOtherCopies() {
    hidden := DetectHiddenWindows(true)
    for window in WinGetList("ahk_class AutoHotkey") {
        try {
            if window = A_ScriptHwnd || !(WinGetTitle(window) ~= "i)\\arrowkeys\.(ahk|exe)( - AutoHotkey.*)?$")
                continue
            copy := WinGetPID(window)
            WinClose(window)
            ProcessWaitClose(copy, 3)
        }
    }
    DetectHiddenWindows(hidden)
}

; Caps is an Alt modifier here; never leave the Caps Lock toggle enabled.
SetCapsLockState "AlwaysOff"
; Another AHK process can bypass AlwaysOff with its own synthetic toggle.
; Repair that state without releasing Caps/Alt or changing any hotkeys.
SetTimer KeepCapsLockOff, 250

KeepCapsLockOff() {
    if GetKeyState("CapsLock", "T")
        SetCapsLockState "AlwaysOff"
}

CapsLock::Alt

!j::Send("{Left}")
!l::Send("{Right}")
!i::Send("{Up}")
!k::Send("{Down}")
!u::Send("{Home}")
!o::Send("{End}")
!h::Send("^{Left}")
!`;::Send("^{Right}")
