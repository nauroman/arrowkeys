# ArrowKeys for the Mac App Store

The development build uses the same eight physical key positions as the GitHub edition. It has its own bundle identifier, `com.nauroman.ArrowKeys.Store`. Quit the GitHub edition before starting a test. **Open at Login** is checked at first setup. Choose **Enable Navigation** (or **Save** when updating the login setting). If cursor control needs approval, ArrowKeys opens **System Settings**. Allow **ArrowKeys Store** there, then switch back to your editor. ArrowKeys reopens if macOS still reports the previous permission. Check for **Navigation active** in the four-arrow menu.

While access is pending, the setup window can reopen the permission settings, show the running copy in Finder, or restart it. Choose **Later** to dismiss the guide. **Set Up Cursor Control…** in the menu brings it back.

## Build on macOS

```sh
bash packaging/build-mac-store.sh dist/mac-app-store
bash tests/macos-store/run.sh dist/mac-app-store
```

Both ZIP files contain universal binaries for macOS 15.2 or newer. A development build uses **Apple Development** by default. Set `MAC_APP_SIGN_IDENTITY` to select the Apple signing identity for your team. Use the same signing identity and bundle identifier for subsequent development installs so macOS can recognize the permission you granted. App Store distribution uses its own signing workflow below.

GitHub Actions builds the disposable test ZIP with `--ad-hoc`. macOS ties its permission to that particular build. For repeated testing on a personal Mac, install the Apple-signed development build. Moving from an ad hoc copy to a signed one may require granting access once more. [How macOS identifies updates](https://developer.apple.com/documentation/technotes/tn3127-inside-code-signing-requirements/)

## Test a physical Mac

Extract **ArrowKeys-MacBook-Check.zip** and open **Check on MacBook.command**. The check creates its own application copy and test documents. TextEdit and the code editor use saved digit markers to compare each cursor position with the ordinary arrow command. Safari compares the actual selection in a local text area. The kit looks for Xcode, Visual Studio Code, Cursor and BBEdit in order, then uses the built-in Script Editor. Set `ARROWKEYS_TEST_EDITOR` to select another installed editor.

Follow the prompts to move the test copy to Trash and toggle Caps Lock twice in TextEdit. The results folder contains the per-key measurements, per-device before/after snapshots and the final typing check. The separate CI job tests shortcut delivery and bundle removal before permission is granted. Only the physical check exercises the entire keyboard path. [Candidate builds](https://github.com/nauroman/arrowkeys/actions/workflows/mac-app-store.yml)

## Create the upload package

Set `MAC_APP_SIGN_IDENTITY`, `MAC_INSTALLER_SIGN_IDENTITY` and `MAC_APP_STORE_PROFILE` to the Apple Distribution identity, Mac Installer Distribution identity and matching provisioning profile. Set `MAC_STORE_BUILD_NUMBER` to the build number for App Store Connect. Run the build on a Mac with those certificates and their private keys available for signing.

```sh
bash packaging/build-mac-store.sh dist/mac-app-store --distribution
```

The output is **ArrowKeys-Mac-App-Store.pkg** for App Store Connect. The store package contains the sandboxed application with no installer scripts.
