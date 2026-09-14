<img src="assets/AppIcon.png" alt="DisplayToggle app icon" width="112">

# DisplayToggle

Turn external monitors off and back on from the macOS menu bar, without unplugging them.

Click a monitor in the menu to toggle it, or press **⌃⌥⌘D** (Control–Option–Command–D) to toggle them all. It leaves your built-in display alone. Launch at login is optional.

Requires macOS 13 or later. Supports Apple Silicon and Intel.

## Why I built this

I share a monitor between my MacBook and Windows PC. Sometimes I'm using the PC and open the laptop next to it. Even though the monitor is showing the Windows input, macOS still sees it as connected and puts windows on a screen I can't see.

DisplayToggle lets me disconnect the monitor from macOS and use just the laptop screen, then turn it back on when I switch the monitor to the Mac.

## Install

```sh
brew install --cask rafaelderolez/tap/displaytoggle
```

Or [download the app](https://github.com/rafaelderolez/DisplayToggle/releases/latest), unzip it, and move it to Applications. Downloads are signed and notarized.

## Build from source

Requires recent Apple Command Line Tools (`xcode-select --install`).

```sh
git clone https://github.com/rafaelderolez/DisplayToggle.git
cd DisplayToggle
./build.sh
```

This builds, installs, and opens the app. Use `./build.sh --build-only` to compile without installing, or `--help` for other options.

## Compatibility

DisplayToggle uses a private macOS API, so OS updates may break it. Keep another screen visible: the app can turn off your last active external display. If a monitor won't come back, reconnect its cable or open your laptop lid.

[Contributing](CONTRIBUTING.md) · [MIT license](LICENSE)
