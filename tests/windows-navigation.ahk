#Requires AutoHotkey v2.0
#SingleInstance Off
; This probe sends keys only to its own focused multi-line Win32 Edit control.
SetTitleMatchMode 2
SendMode "Event"
SendLevel 10
SetKeyDelay 25, 25
window := Gui(, "ArrowKeys installation test")
textBox := window.AddEdit("w480 r5 -Wrap", "alpha bravo charlie`r`nsecond line here`r`nthird line")
window.Show()
WinActivate window
if !WinWaitActive(window, , 5)
    ExitApp 2
textBox.Focus()

position() {
    global textBox
    start := Buffer(4, 0)
    finish := Buffer(4, 0)
    SendMessage(0xB0, start.Ptr, finish.Ptr, textBox.Hwnd)
    return NumGet(start, 0, "UInt")
}

move(keys, start := 27) {
    global textBox, window
    if !WinActive(window) || ControlGetFocus(window) != textBox.Hwnd
        throw Error("Test textBox lost focus")
    SendMessage(0xB1, start, start, textBox.Hwnd)
    SendEvent keys
    Sleep 100
    return position()
}

try {
    if A_Args[1] = "removed" {
        SetCapsLockState "Off"
        before := textBox.Value
        move("{CapsLock}j{CapsLock}")
        if !InStr(textBox.Value, "J", true) || textBox.Value == before || GetKeyState("CapsLock", "T")
            throw Error("Ordinary Caps Lock typing did not return after uninstall")
    } else {
        cases := Map("j", "{Left}", "k", "{Down}", "l", "{Right}", "i", "{Up}",
            "u", "{Home}", "o", "{End}", "h", "^{Left}", ";", "^{Right}")
        for key, reference in cases {
            expected := move(reference)
            if expected == 27
                throw Error("Reference key did not move: " reference)
            for modifier in ["CapsLock", "LAlt", "RAlt"] {
                before := textBox.Value
                actual := move("{" modifier " down}" key "{" modifier " up}")
                if actual != expected || textBox.Value != before
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
