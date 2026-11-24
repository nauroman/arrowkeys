# <img src="assets/ArrowKeys.png" width="48" alt=""> ArrowKeys

**Move through text without reaching for the arrow keys.** Hold **Caps Lock** and use **J K L I** to move left, down, right and up. Jump by word or go to the start and end of a line with the nearby keys.

ArrowKeys runs as a native menu bar app on Mac and uses [AutoHotkey v2](https://www.autohotkey.com/) on Windows. Both editions work offline.

[![Installer builds, tests and ClamAV scan](https://github.com/nauroman/arrowkeys/actions/workflows/build.yml/badge.svg?branch=main)](https://github.com/nauroman/arrowkeys/actions/workflows/build.yml)

## Install

| Platform | Download | What to do |
| --- | --- | --- |
| Windows | [ArrowKeys-Windows-Setup.exe](https://github.com/nauroman/arrowkeys/releases/download/windows-v1.1.1/ArrowKeys-Windows-Setup.exe) | Run the installer. It includes AutoHotkey, starts ArrowKeys for your account and creates a sign-in shortcut by default. |
| macOS 13 or newer | [ArrowKeys-macOS.pkg](https://github.com/nauroman/arrowkeys/releases/latest/download/ArrowKeys-macOS.pkg) | Double-click the package and choose **Continue → Install**. ArrowKeys starts in the menu bar. Allow **Accessibility** when prompted. |

Find the scan log and SHA-256 checksums on the [release page for your platform](https://github.com/nauroman/arrowkeys/releases). You can also [verify the build provenance](#verify-a-download).

Open a text editor and hold **Caps Lock**. **J/K/L/I** move left/down/right/up, **U/O** go to the beginning/end of a line, and **H/;** move by word. Release Caps Lock to resume typing.

![Keyboard layout highlighting Caps Lock and the J, K, L, I navigation keys](keyboard.png)

### On a Mac

The native installer is about **1.1 MB** and supports Apple silicon and Intel. The older **43.4 MB** package from v1.0.1 bundled Karabiner-Elements.

**If the installer says “Not Opened”**, click **Done**. The package is unsigned and has no Apple notarization. After verifying your GitHub download, open **System Settings → Privacy & Security**, scroll to **Security**, and click **Open Anyway** for **ArrowKeys-macOS.pkg**. [Verify your download](#verify-a-download) · [Apple’s instructions](https://support.apple.com/en-us/102445)

The installer opens ArrowKeys for the signed-in user. If the installed version needs permission, it shows a setup guide. Choose **Open Accessibility Settings** and turn on **ArrowKeys** to let it move the cursor in other apps. You can reopen the guide from **Set Up Accessibility…** in the four-arrow menu while access is missing. Once the menu shows **Navigation active**, try **Caps Lock + J** in TextEdit to move the cursor one character left. ArrowKeys configures Caps Lock on each keyboard, including keyboards connected later. If nobody was signed in during installation, open **Applications → ArrowKeys** after signing in.

If Accessibility is already on and shortcuts still type symbols after an update, choose **Quit ArrowKeys** and reopen it from **Applications**. If the menu still asks for access, quit again, remove the ArrowKeys entry with **−** in **System Settings → Privacy & Security → Accessibility**, then use **+** to add the installed **Applications → ArrowKeys**. Turn it on and reopen the app. If the menu says **Keyboard connection unavailable — retrying**, macOS has granted Accessibility and ArrowKeys is retrying the keyboard connection automatically.

**Open at Login** is on by default. ArrowKeys registers itself on first launch and starts automatically at subsequent sign-ins. To turn it off, uncheck **Open at Login** in the four-arrow menu. If the menu shows **Approval Required**, select that item to open the macOS Login Items settings.

Caps Lock acts as **Option**, and either physical Option key also activates the shortcuts. **U/O** send **Command + Left/Right** and **H/;** send **Option + Left/Right**. The rule uses physical key positions, including the U.S. semicolon position immediately to the right of L. Holding a third modifier such as Shift leaves that chord to the app. A mapped Option chord takes precedence over typing its usual special character.

ArrowKeys processes eight physical key positions through a macOS event tap. Input-source shortcuts such as an existing Option + Shift binding pass through. Switching from the Karabiner edition? Remove its ArrowKeys rule in **Complex Modifications** to avoid two handlers processing the same shortcut. You can keep Karabiner for other rules.

To uninstall, move **ArrowKeys.app** from Applications to Trash. If Finder asks you to close the app first, select **Quit ArrowKeys** in its menu and try again. Both quitting and moving the running app to Trash restore the previous Caps Lock assignment on each keyboard it changed. With the default Mac settings, Caps Lock toggles uppercase again.

If you manually assigned Caps Lock to Option for an older version, choose **Caps Lock** for that key in **System Settings → Keyboard → Keyboard Shortcuts… → Modifier Keys**.

### Mac App Store candidate

The separate **ArrowKeys Store.app** build targets macOS 15.2 and later. It registers the eight shortcuts with macOS. Quit the GitHub edition before opening the candidate. **Open at Login** is checked at first launch and can be changed in the menu. Choose **Enable Navigation**. If permission is needed, ArrowKeys opens **System Settings** and shows which app to allow. Turn on **ArrowKeys Store** and return to your editor. ArrowKeys reopens if needed. Its four-arrow menu shows **Navigation active** when the shortcuts are ready.

The candidate is available as a development build. The MacBook check compares physical Caps Lock chords with ordinary arrows in TextEdit, Safari and a code editor. It also checks uppercase typing after moving the test copy to Trash. [Build and test the candidate](packaging/mac-app-store/README.md)

### Verify a download

The [release workflow](.github/workflows/build.yml) builds the installers from the tagged source, checks installation on Windows and macOS, and scans the release downloads with ClamAV. Each release links to its scan log and includes **SHA256SUMS.txt**. A clean scan means that the scanner found no known threats in those files at the time of the scan.

You can verify the exact downloaded bytes against GitHub's signed build record with the [GitHub CLI](https://cli.github.com/). Run the command for your download:

```shell
gh attestation verify ArrowKeys-Windows-Setup.exe --repo nauroman/arrowkeys
gh attestation verify ArrowKeys-macOS.pkg --repo nauroman/arrowkeys
```

The Windows installer also has no publisher signature. You can inspect the keyboard handlers and read how each edition processes input. [Windows hotkeys](arrowkeys.ahk) · [macOS handler](macos/ArrowKeys.m) · [Privacy](PRIVACY.md)

### Windows setup from source

1. Install [AutoHotkey v2](https://www.autohotkey.com/).
2. Choose **Code → Download ZIP** in this repository and extract it to a permanent folder.
3. Double-click [`arrowkeys.ahk`](arrowkeys.ahk). An AutoHotkey icon appears in the system tray.
4. Open a text editor, type a line, then hold **Caps Lock** and tap **J** to move left. Release Caps Lock and type normally.

**Requirements:** Windows and **AutoHotkey v2.0 or a later v2 release**, as specified by `#Requires AutoHotkey v2.0`. AutoHotkey v1 is incompatible. The current script was tested with **AutoHotkey v2.0.18**.

## Windows key reference

Hold **Caps Lock** while pressing a key below. Holding a navigation key repeats its action.

| Shortcut | Sends | Use it to… |
| --- | --- | --- |
| Caps Lock + **J** | Left arrow | Move one character left |
| Caps Lock + **K** | Down arrow | Move down |
| Caps Lock + **L** | Right arrow | Move one character right |
| Caps Lock + **I** | Up arrow | Move up |
| Caps Lock + **U** | Home | Go to the start of a line |
| Caps Lock + **O** | End | Go to the end of a line |
| Caps Lock + **H** | Ctrl + Left arrow | Jump to the previous word |
| Caps Lock + **;** | Ctrl + Right arrow | Jump to the next word |

For example, when correcting a sentence, hold Caps Lock and tap **H** to move back a word, release Caps Lock to edit, then use **O** with Caps Lock to return to the end of the line. In code, **U** and **O** help reach the start or end of a line without moving to the navigation cluster. The receiving app determines the exact behavior of Home, End and word movement.

### Caps Lock acts as Alt

The script uses `CapsLock::Alt`: Caps Lock becomes an **Alt modifier**, including for other Alt shortcuts in your app. A single Caps Lock press sends an **Alt press and release**, which can activate an application's menu. It does **not** toggle uppercase typing.

The navigation shortcuts are defined as **Alt + key**, so the physical Alt key also triggers them. Plain J, K, L, I and the other letters continue to work normally when Caps Lock and Alt are released.

Extra Ctrl or Shift modifiers change which hotkey matches; additional selection shortcuts are not defined. Letter and punctuation bindings depend on the keyboard layout. For example, on a Russian layout, `;` may require **Shift + 4**.

## Windows sign-in for a source install

1. Create a shortcut to `arrowkeys.ahk` in its permanent folder.
2. Press **Win + R**, enter `shell:startup`, and press **Enter**.
3. Put the **shortcut** in the Startup folder.

Windows will launch it when you sign in. Keep the script in place so the shortcut continues to work; using a shortcut also means you only have one copy to update.

## Reload or stop

For an installer-based Windows setup, uninstall **ArrowKeys** in **Settings → Apps → Installed apps**. When switching from a manual setup, exit your previous script and remove its old Startup shortcut.

- **After editing:** right-click the AutoHotkey tray icon and choose **Reload Script**. Launching the same script again also replaces its earlier instance through `#SingleInstance Force`.
- **Stop and restore the usual key behavior:** right-click the tray icon and choose **Exit**. Caps Lock can then be used as its normal toggle again.
- **Stop automatic startup:** remove its shortcut from the Startup folder, then exit the running script.

Use **Exit** when you want the Caps Lock safeguard to stop too; suspending hotkeys alone does not stop the timer.

## Caps Lock safeguard and limits

Since Caps Lock is used as Alt, its uppercase toggle is kept **off** while this script runs. `SetCapsLockState "AlwaysOff"` applies at startup. A small check every **250 ms** also switches it off if another script or a synthetic keyboard event enables it despite that setting. The check only changes the Caps Lock toggle; it does not release held modifiers or change the navigation bindings.

The correction normally runs on the next timer tick. A busy or suspended process can delay it, and other keyboard hooks or remapping tools can still interfere. This is a recovery measure for an unintended toggle, not a guarantee against every possible input fault.

The update was checked with synthetic input across **44 before/after navigation scenarios** and **three forced-toggle scenarios**, including repeat, modifier combinations, release order and focus changes. These checks do not establish the source of every rare fault or test physical hardware failures.

Some apps, games and elevated windows handle simulated input differently. Use the script in your usual apps to check compatibility. It sends ordinary navigation keys and does not change keyboard drivers or registry mappings.

## Contributing

Suggestions and fixes are welcome. For a keyboard issue, include your AutoHotkey version, keyboard layout, affected app, other remapping tools, and the order in which you press and release the keys. Avoid including private text or clipboard contents.

## License

[MIT](LICENSE).
