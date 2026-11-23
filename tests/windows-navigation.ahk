#Requires AutoHotkey v2.0
#SingleInstance Off
; This probe sends keys only to its own focused multi-line Win32 Edit control.
SetTitleMatchMode 2
SendMode "Event"
SendLevel 10
SetKeyDelay 25, 25
window := Gui(, "ArrowKeys installation test")
edit := window.AddEdit("w480 r5 -Wrap", "alpha bravo charlie`r`nsecond line here`r`nthird line")
window.Show()
WinActivate window
if !WinWaitActive(window, , 5)
    ExitApp 2
edit.Focus()

position() {
    global edit
    start := Buffer(4, 0)
    finish := Buffer(4, 0)
    SendMessage(0xB0, start.Ptr, finish.Ptr, edit.Hwnd)
    return NumGet(start, 0, "UInt")
}

move(keys, start := 27) {
    global edit, window
    if !WinActive(window) || ControlGetFocus(window) != edit.Hwnd
        throw Error("Test edit lost focus")
    SendMessage(0xB1, start, start, edit.Hwnd)
    SendEvent keys
    Sleep 100
    return position()
}

try {
    if A_Args[1] = "removed" {
        SetCapsLockState "Off"
        before := edit.Value
        move("{CapsLock}j{CapsLock}")
        if !InStr(edit.Value, "J", true) || edit.Value == before || GetKeyState("CapsLock", "T")
            throw Error("Ordinary Caps Lock typing did not return after uninstall")
    } else {
        cases := Map("j", "{Left}", "k", "{Down}", "l", "{Right}", "i", "{Up}",
            "u", "{Home}", "o", "{End}", "h", "^{Left}", ";", "^{Right}")
        for key, reference in cases {
            expected := move(reference)
            if expected == 27
                throw Error("Reference key did not move: " reference)
            for modifier in ["CapsLock", "LAlt", "RAlt"] {
                before := edit.Value
                actual := move("{" modifier " down}" key "{" modifier " up}")
                if actual != expected || edit.Value != before
                    throw Error(modifier "+" key " moved to " actual ", expected " expected)
            }
        }
        if GetKeyState("CapsLock", "T")
            throw Error("Caps Lock toggle is on")
        if move("j") != 28
            throw Error("Ordinary typing failed after releasing the modifier")
    }
} catch as err {
    FileAppend err.Message "`n", "*"
    ExitApp 1
}
FileAppend "Cursor and typing checks passed: " A_Args[1] "`n", "*"
ExitApp 0
