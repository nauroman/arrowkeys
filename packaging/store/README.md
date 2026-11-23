# ArrowKeys in Microsoft Store

Build on Windows with the Windows SDK, PowerShell, Python and Pillow installed.
Use the four values assigned to this app under **Partner Center → Product identity**.

```powershell
.\packaging\build-store.ps1 -IdentityName '<Package/Identity/Name>' -Publisher '<Package/Identity/Publisher>' -PublisherDisplayName '<publisher display name>' -DisplayName '<reserved name>' -Version 1.1.1.0
```

The unsigned submission package and 300 × 300 listing logo are written to
`dist/store`. CI uses a separate identity and signs only its disposable test build.
The release job publishes the standalone Windows and macOS installers.

## Store description

Hold Caps Lock to move through text with the letter keys. Use I, J, K and L to move up, left, down and right. U and O take you to the start and end of a line. H and the semicolon key move one word at a time.

Open ArrowKeys and try the shortcuts in its built-in guide. Close the guide to keep navigating in your editor. Double-click the tray icon to bring the guide back, or choose Exit ArrowKeys to restore normal Caps Lock behavior. You can also enable ArrowKeys in Windows Settings → Apps → Startup.

The Windows edition works offline and includes the AutoHotkey runtime.

ArrowKeys is open source. Review the code at https://github.com/nauroman/arrowkeys. You can also download the standalone Windows and Mac installers and compare their SHA-256 checksums at https://github.com/nauroman/arrowkeys/releases/latest.

## Certification notes

Run ArrowKeys from Start. In the guide's text box, hold Caps Lock and tap J, L, H or O. Release Caps Lock and type normally. Hide the guide and repeat in Notepad. The tray menu can reopen the guide or exit the app.

ArrowKeys requires runFullTrust to register a desktop keyboard hook and send the eight navigation commands to the focused desktop app. It runs at the signed-in user's normal privilege level. It does not save keystrokes, collect account data or use the network.

Product support: https://github.com/nauroman/arrowkeys/issues

Product website: https://github.com/nauroman/arrowkeys

Privacy policy: https://github.com/nauroman/arrowkeys/blob/main/PRIVACY.md
