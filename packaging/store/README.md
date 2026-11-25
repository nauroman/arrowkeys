# Arrow Keys in Microsoft Store

Build on Windows with the Windows SDK, PowerShell, Python and Pillow installed.
Use the four values assigned to this app under **Partner Center → Product identity**.

```powershell
.\packaging\build-store.ps1 -IdentityName '<Package/Identity/Name>' -Publisher '<Package/Identity/Publisher>' -PublisherDisplayName '<publisher display name>' -DisplayName 'Arrow Keys' -Version 1.1.2.0
```

The unsigned submission package and 300 × 300 listing logo are written to
`dist/store`. Without a Windows PC, run the **Build the Microsoft Store package** workflow on GitHub
with the same four values; it uploads `dist/store` as the `store-submission` artifact. CI uses a separate identity and signs only its disposable test build.
Tag a Windows-only release as `windows-vX.Y.Z` to publish the verified standalone Windows installer on GitHub.

## Store description

Hold Caps Lock to move through text with the letter keys. Use I, J, K and L to move up, left, down and right. U and O take you to the start and end of a line. H and the semicolon key move one word at a time.

Open Arrow Keys once after installing it. Windows will then start it automatically whenever you sign in. You can turn this off in Settings → Apps → Startup.

Try the shortcuts in the built-in guide, then hide it to keep navigating in your editor. Double-click the tray icon to bring the guide back, or choose Exit Arrow Keys to restore normal Caps Lock behavior for the rest of the session.

The Windows edition works offline and includes the AutoHotkey runtime.

Arrow Keys is open source. Review the code at https://github.com/nauroman/arrowkeys. You can also download the standalone Windows installer and verify its SHA-256 checksum at https://github.com/nauroman/arrowkeys/releases.

## Certification notes

Run Arrow Keys from Start. In the guide's text box, hold Caps Lock and tap J, L, H or O. Release Caps Lock and type normally. Hide the guide and repeat in Notepad. The tray menu can reopen the guide or exit the app.

Arrow Keys requires runFullTrust to register a desktop keyboard hook and send the eight navigation commands to the focused desktop app. It runs at the signed-in user's normal privilege level. It does not save keystrokes, collect account data or use the network.

Product support: https://github.com/nauroman/arrowkeys/issues

Product website: https://nauroman.github.io/arrowkeys/

Privacy policy: https://github.com/nauroman/arrowkeys/blob/main/PRIVACY.md
