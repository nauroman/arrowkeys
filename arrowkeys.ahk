#Requires AutoHotkey v2.0
#SingleInstance Force

; The uninstaller starts this same script with /restart to retire its running copy.
if A_Args.Length && A_Args[1] = "--stop"
    ExitApp

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
