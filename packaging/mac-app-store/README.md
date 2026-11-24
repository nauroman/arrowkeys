# ArrowKeys for the Mac App Store

The development build uses the same eight physical key positions as the GitHub edition. It has its own bundle identifier, `com.nauroman.ArrowKeys.Store`. Quit the GitHub edition before starting a test. **Open at Login** is checked at first setup. Choose **Enable Navigation** and allow cursor control for **ArrowKeys Store** when macOS prompts. Switch back to your editor. ArrowKeys reopens once if the running process still sees the old permission. **Set Up Cursor Control… → Restart ArrowKeys** also applies a permission you have already granted.

## Build on macOS

```sh
bash packaging/build-mac-store.sh dist/mac-app-store
bash tests/macos-store/run.sh dist/mac-app-store
```

Both ZIP files contain universal binaries for macOS 15.2 or newer. The development app is ad hoc signed unless you supply `MAC_APP_SIGN_IDENTITY`. The distributed app needs App Store signing and Apple review.

## Test a physical Mac

Extract **ArrowKeys-MacBook-Check.zip** and open **Check on MacBook.command**. The check creates its own application copy and test documents. TextEdit and the code editor use saved digit markers to compare each cursor position with the ordinary arrow command. Safari compares the actual selection in a local text area. The kit looks for Xcode, Visual Studio Code, Cursor and BBEdit in order, then uses the built-in Script Editor. Set `ARROWKEYS_TEST_EDITOR` to select another installed editor.

Follow the prompts to move the test copy to Trash and toggle Caps Lock twice in TextEdit. The results folder contains the per-key measurements, per-device before/after snapshots and the final typing check. The separate CI job tests shortcut delivery and bundle removal before permission is granted. Only the physical check exercises the entire keyboard path. [Candidate builds](https://github.com/nauroman/arrowkeys/actions/workflows/mac-app-store.yml)

## Create the upload package

Set `MAC_APP_SIGN_IDENTITY`, `MAC_INSTALLER_SIGN_IDENTITY` and `MAC_APP_STORE_PROFILE` to the Apple Distribution identity, Mac Installer Distribution identity and matching provisioning profile. Set `MAC_STORE_BUILD_NUMBER` to the build number for App Store Connect. Run the build on a Mac with those certificates and their private keys available for signing.

```sh
bash packaging/build-mac-store.sh dist/mac-app-store --distribution
```

The output is **ArrowKeys-Mac-App-Store.pkg** for App Store Connect. The store package contains the sandboxed application with no installer scripts.
