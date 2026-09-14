<img src="assets/AppIcon.png" alt="DisplayToggle app icon" width="112">

# DisplayToggle

A tiny macOS menu bar app for turning external displays off and back on without unplugging them.

Click a display in the menu, or press **⌃⌥⌘D** (Control–Option–Command–D) to toggle all external displays. Useful when you want to switch back to your MacBook screen while leaving your monitor connected.

- Toggle external displays individually or all at once.
- Remember disabled displays across app restarts and offer to reconnect them.
- See display names, status, and resolution in a native menu.
- Optionally launch at login.
- No Dock icon, accounts, analytics, network requests, or third-party dependencies.

## Requirements

macOS **13 Ventura or later**, on Apple Silicon or Intel. Native section headers require macOS 14; menu subtitles require macOS 14.4.

DisplayToggle uses the private `CGSConfigureDisplayEnabled` API in Apple's SkyLight framework. Compatibility can change with macOS updates, and reconnecting a display depends on the Mac, monitor, and dock. macOS 13 is the build target; it is not a claim that every OS and hardware combination has been tested.

**Keep another display available when turning one off.** The app leaves built-in displays alone, but does not currently prevent turning off your last active external display. On a desktop Mac or a MacBook with the lid closed, that can leave you without a visible screen. Open the laptop lid or reconnect the monitor cable if needed.

## Install

### Homebrew

```sh
brew install --cask rafaelderolez/tap/displaytoggle
```

This installs the signed, notarized app from the [personal tap](https://github.com/rafaelderolez/homebrew-tap). No Xcode or Command Line Tools are needed. Open DisplayToggle from Applications and look for the display icon in the menu bar.

To update later:

```sh
brew update
brew upgrade --cask rafaelderolez/tap/displaytoggle
```

### Direct download

Download `DisplayToggle-<version>.zip` from [GitHub Releases](https://github.com/rafaelderolez/DisplayToggle/releases/latest), unzip it, and drag `DisplayToggle.app` into Applications. The signed, notarized app supports both Apple Silicon and Intel.

### Build from source

No Homebrew or full Xcode project is needed. Install Apple's Command Line Tools once:

```sh
xcode-select --install
```

After installation finishes:

```sh
git clone https://github.com/rafaelderolez/DisplayToggle.git
cd DisplayToggle
./build.sh
```

This compiles for your Mac, ad-hoc signs the app, installs it in `/Applications`, and launches it. Look for the display icon in the menu bar. Re-running the script replaces and restarts your installed copy.

You can also download the source ZIP from GitHub, extract it, and double-click **Build DisplayToggle.command**. The Command Line Tools must already be installed.

If `/Applications` is not writable, install for your user:

```sh
DEST="$HOME/Applications" ./build.sh
```

#### Other build options

```sh
./build.sh --build-only                # Build into build/; no install or launch
./build.sh --build-only --universal    # One app for Apple Silicon and Intel
./build.sh --no-launch                 # Install without launching
./build.sh --local                     # Install and launch beside the source
./build.sh --help
```

Builds explicitly target macOS 13. A recent Command Line Tools installation with a macOS 14.4+ SDK is required to compile the newer menu APIs. The version comes from [`VERSION`](VERSION).

## Use

| Control | Action |
| --- | --- |
| A display's name | Turn that external display off or on |
| **Turn All Off / Turn All On** | Turn active external displays off; if none are active, attempt to reconnect listed displays |
| **⌃⌥⌘D** | The same action, from anywhere on your Mac |
| **Turn On Any That Are Off** | Attempt to reconnect every inactive display in the menu |
| **Launch at Login** | Toggle automatic startup for the installed app |

The global shortcut uses Carbon's hotkey API and does not require Accessibility permission. If another app registers the same shortcut, it may not work; the shortcut is currently fixed.

## Troubleshooting

**A display will not come back.** Try **Turn On Any That Are Off**, then reconnect its cable or dock. Disabled displays are remembered by their display IDs, which can change after reconnecting hardware or rebooting. A remembered display may appear as “Off (unplugged)” when macOS no longer reports it, even if the cable is still connected.

**The app beeps.** A display change or login-item request failed. Confirm the monitor is connected, and check the login-item settings in System Settings if you were changing automatic startup.

**“SkyLight API unavailable.”** Your macOS version does not expose the private API the app needs. Please [open an issue](https://github.com/rafaelderolez/DisplayToggle/issues) with your macOS version and Mac model.

**There is no Dock icon.** This is intentional; use the menu bar display icon. Quit from that menu.

**Removing the app.** Turn displays back on, turn off **Launch at Login**, quit DisplayToggle, and move the app to the Trash. Preferences remain in `dev.derolez.DisplayToggle`; optionally remove them after quitting with `defaults delete dev.derolez.DisplayToggle`.

## Development

The app lives in [`main.swift`](main.swift): native AppKit menus, CoreGraphics display enumeration, a dynamically loaded SkyLight function, Carbon hotkeys, and ServiceManagement login items. There is no package manager or generated Xcode project.

The app icon is in `assets/AppIcon.png` and its compiled macOS resource is `assets/AppIcon.icns`. After changing the PNG, run `./scripts/build-icon.sh` before building. The menu bar continues to use native SF Symbols.

See [CONTRIBUTING.md](CONTRIBUTING.md) for checks and the hardware smoke test, and [docs/RELEASING.md](docs/RELEASING.md) for signing, notarization, release archives, and Homebrew distribution.

## License

[MIT](LICENSE) © Rafael Derolez.
