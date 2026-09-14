# Contributing

Small fixes and focused improvements are welcome. For a larger change, open an issue first so we can agree on the scope. Include your macOS version, Mac model and chip, monitor, and connection type when reporting display problems. Remove serial numbers or personal information from screenshots and logs.

## Build checks

On a Mac with current Apple Command Line Tools:

```sh
for script in build.sh scripts/*.sh 'Build DisplayToggle.command'; do
  bash -n "$script"
done
./build.sh --build-only --universal
codesign --verify --strict build/DisplayToggle.app
xcrun lipo build/DisplayToggle.app/Contents/MacOS/DisplayToggle -verify_arch arm64 x86_64
git diff --check
```

GitHub Actions runs these build/package checks. It cannot prove that the private display API works with physical monitors.

## Hardware smoke test

Keep a working built-in display or second screen visible throughout testing. Do not turn off the only visible display.

1. Open the built app with `open build/DisplayToggle.app`. Quit another running copy first so the shortcut is not registered twice.
2. Confirm the app appears in the menu bar and external display names and resolutions are correct.
3. Turn one external display off and on. Check that the built-in display stays on.
4. Test **⌃⌥⌘D**, **Turn All Off / Turn All On**, and **Turn On Any That Are Off**.
5. Disable an external display, quit and relaunch the app, and try reconnecting it from the remembered entry.
6. Unplug and reconnect a monitor or dock, then reopen the menu and verify its state.
7. Install a copy in Applications before testing **Launch at Login**; toggle it, check System Settings, and restore your preferred setting.
8. Restore your displays before quitting.

Report which macOS versions, architectures, and hardware you actually tested in a pull request. A successful compile for Intel or macOS 13 is not a runtime test on those systems.
