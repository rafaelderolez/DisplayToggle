import AppKit
import Carbon
import ServiceManagement

// MARK: - Private SkyLight API (what BetterDisplay / Lunar use under the hood)

typealias CGSConfigureDisplayEnabledFn = @convention(c) (CGDisplayConfigRef, CGDirectDisplayID, Bool) -> CGError

let cgsConfigureDisplayEnabled: CGSConfigureDisplayEnabledFn? = {
    guard let handle = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_NOW),
          let sym = dlsym(handle, "CGSConfigureDisplayEnabled") else { return nil }
    return unsafeBitCast(sym, to: CGSConfigureDisplayEnabledFn.self)
}()

@discardableResult
func setDisplay(_ id: CGDirectDisplayID, enabled: Bool) -> Bool {
    guard let fn = cgsConfigureDisplayEnabled else { return false }
    var config: CGDisplayConfigRef?
    guard CGBeginDisplayConfiguration(&config) == .success, let cfg = config else { return false }
    if fn(cfg, id, enabled) != .success {
        CGCancelDisplayConfiguration(cfg)
        return false
    }
    return CGCompleteDisplayConfiguration(cfg, .permanently) == .success
}

// MARK: - Display enumeration

struct DisplayInfo {
    let id: CGDirectDisplayID
    let name: String
    let active: Bool
    /// False when the display is not attached at all (cable out, or macOS dropped it after we disabled it).
    let online: Bool
    let resolution: String?
}

func idSet(_ getter: (UInt32, UnsafeMutablePointer<CGDirectDisplayID>?, UnsafeMutablePointer<UInt32>?) -> CGError) -> Set<CGDirectDisplayID> {
    var count: UInt32 = 0
    var ids = [CGDirectDisplayID](repeating: 0, count: 16)
    guard getter(16, &ids, &count) == .success else { return [] }
    return Set(ids.prefix(Int(count)))
}

func screenName(for id: CGDirectDisplayID) -> String? {
    for screen in NSScreen.screens {
        if let n = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID, n == id {
            return screen.localizedName
        }
    }
    return nil
}

func resolutionText(for id: CGDirectDisplayID) -> String? {
    guard let mode = CGDisplayCopyDisplayMode(id) else { return nil }
    return "\(mode.pixelWidth) × \(mode.pixelHeight)"
}

// MARK: - App

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let menu = NSMenu()
    private let defaults = UserDefaults.standard

    /// Display IDs we've disabled ourselves (persisted so we can re-enable after a relaunch).
    private var disabled: Set<CGDirectDisplayID> {
        get { Set((defaults.array(forKey: "disabled") as? [UInt32]) ?? []) }
        set { defaults.set(Array(newValue), forKey: "disabled") }
    }
    /// Cached names, since a disabled display no longer has an NSScreen.
    private var names: [UInt32: String] {
        get { (defaults.dictionary(forKey: "names") as? [String: String])?.reduce(into: [:]) { $0[UInt32($1.key) ?? 0] = $1.value } ?? [:] }
        set { defaults.set(Dictionary(uniqueKeysWithValues: newValue.map { (String($0.key), $0.value) }), forKey: "names") }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "display", accessibilityDescription: "Display Toggle")
        statusItem.menu = menu
        menu.delegate = self
        menu.autoenablesItems = false
        registerHotKey()
        updateIcon()

        if cgsConfigureDisplayEnabled == nil {
            let alert = NSAlert()
            alert.messageText = "SkyLight API unavailable"
            alert.informativeText = "Couldn't load CGSConfigureDisplayEnabled. This macOS version may have removed it."
            alert.runModal()
        }
    }

    // MARK: Displays

    private func externalDisplays() -> [DisplayInfo] {
        let online = idSet(CGGetOnlineDisplayList)
        let active = idSet(CGGetActiveDisplayList)
        var cache = names
        var result: [DisplayInfo] = []

        for id in online where CGDisplayIsBuiltin(id) == 0 {
            if let n = screenName(for: id) { cache[id] = n }
            let isActive = active.contains(id)
            result.append(DisplayInfo(id: id,
                                      name: cache[id] ?? "Display \(id)",
                                      active: isActive,
                                      online: true,
                                      resolution: isActive ? resolutionText(for: id) : nil))
        }
        // Displays we disabled that no longer show up at all: still offer them for reconnect.
        for id in disabled where !online.contains(id) {
            result.append(DisplayInfo(id: id, name: cache[id] ?? "Display \(id)", active: false, online: false, resolution: nil))
        }
        names = cache
        return result.sorted { $0.name < $1.name }
    }

    private func toggle(_ d: DisplayInfo) {
        let wantEnabled = !d.active
        guard setDisplay(d.id, enabled: wantEnabled) else { NSSound.beep(); return }
        var set = disabled
        if wantEnabled { set.remove(d.id) } else { set.insert(d.id) }
        disabled = set
        updateIcon()
    }

    @objc private func toggleClicked(_ sender: NSMenuItem) {
        guard let d = sender.representedObject as? DisplayInfo else { return }
        toggle(d)
    }

    /// Hotkey action: if any external is active, disconnect all externals; otherwise reconnect everything we disabled.
    @objc func toggleAll() {
        let displays = externalDisplays()
        if displays.contains(where: { $0.active }) {
            displays.filter { $0.active }.forEach { toggle($0) }
        } else {
            displays.filter { !$0.active }.forEach { toggle($0) }
        }
    }

    @objc private func reconnectAll() {
        externalDisplays().filter { !$0.active }.forEach { toggle($0) }
    }

    private func updateIcon() {
        let anyOff = externalDisplays().contains { !$0.active }
        statusItem.button?.image = NSImage(systemSymbolName: anyOff ? "display.trianglebadge.exclamationmark" : "display",
                                           accessibilityDescription: "Display Toggle")
    }

    // MARK: Launch at login

    private var launchesAtLogin: Bool {
        if #available(macOS 13, *) { return SMAppService.mainApp.status == .enabled }
        return false
    }

    @objc private func toggleLaunchAtLogin() {
        guard #available(macOS 13, *) else { return }
        do {
            if launchesAtLogin { try SMAppService.mainApp.unregister() } else { try SMAppService.mainApp.register() }
        } catch { NSSound.beep() }
    }

    // MARK: Global hotkey  ⌃⌥⌘D  (no Accessibility permission needed)

    private func registerHotKey() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, userData -> OSStatus in
            let me = Unmanaged<AppDelegate>.fromOpaque(userData!).takeUnretainedValue()
            me.toggleAll()
            return noErr
        }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), nil)

        var hotKeyRef: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: OSType(0x4453_5447), id: 1) // "DSTG"
        RegisterEventHotKey(UInt32(kVK_ANSI_D), UInt32(controlKey | optionKey | cmdKey),
                            hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
    }
}

// MARK: - Menu building blocks

private extension NSImage {
    /// A symbol tinted with one colour, so a row reads as "on" or "off" at a glance.
    static func symbol(_ name: String, color: NSColor, pointSize: CGFloat = 13, weight: NSFont.Weight = .regular) -> NSImage? {
        var config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: weight)
        config = config.applying(NSImage.SymbolConfiguration(paletteColors: [color]))
        return NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(config)
    }
}

private extension NSMenu {
    /// A grey group title. Uses the native section header on macOS 14 and later.
    func addSectionHeader(_ title: String) {
        if #available(macOS 14, *) {
            addItem(NSMenuItem.sectionHeader(title: title))
            return
        }
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.attributedTitle = NSAttributedString(string: title, attributes: [
            .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize, weight: .semibold),
            .foregroundColor: NSColor.secondaryLabelColor,
        ])
        item.isEnabled = false
        addItem(item)
    }
}

private extension NSMenuItem {
    /// Grey second line under the title. Silently skipped before macOS 14.4.
    func setSubtitle(_ text: String) {
        if #available(macOS 14.4, *) { subtitle = text }
    }
}

// MARK: - Menu (rebuilt each time it opens so it reflects current state)

extension AppDelegate: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        menu.autoenablesItems = false
        menu.minimumWidth = 260
        let displays = externalDisplays()
        let anyActive = displays.contains { $0.active }
        let anyInactive = displays.contains { !$0.active }

        // 1. One row per external display. Each row is a switch: click to turn that display on or off.
        menu.addSectionHeader("External Displays")

        if displays.isEmpty {
            let none = NSMenuItem(title: "None connected", action: nil, keyEquivalent: "")
            none.image = .symbol("display", color: .tertiaryLabelColor)
            none.isEnabled = false
            menu.addItem(none)
        }
        for d in displays {
            let item = NSMenuItem(title: d.name, action: #selector(toggleClicked(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = d
            item.isEnabled = true
            item.image = .symbol(d.active ? "checkmark.circle.fill" : "circle",
                                 color: d.active ? .systemGreen : .tertiaryLabelColor,
                                 weight: d.active ? .semibold : .regular)
            if d.active {
                item.setSubtitle([d.resolution, "On · Click to turn off"].compactMap { $0 }.joined(separator: " · "))
                item.toolTip = "Turn off \(d.name)"
            } else {
                item.setSubtitle(d.online ? "Off · Click to turn on" : "Off (unplugged) · Click to turn on")
                item.toolTip = "Turn on \(d.name)"
            }
            menu.addItem(item)
        }

        // 2. Actions on every external display at once.
        menu.addItem(.separator())
        menu.addSectionHeader("All Displays")

        let all = NSMenuItem(title: anyActive ? "Turn All Off" : "Turn All On",
                             action: #selector(toggleAll), keyEquivalent: "d")
        all.keyEquivalentModifierMask = [.control, .option, .command]
        all.target = self
        all.isEnabled = !displays.isEmpty
        all.image = .symbol("power", color: .labelColor)
        all.setSubtitle(anyActive ? "Disconnect every external display" : "Reconnect every external display")
        menu.addItem(all)

        let rc = NSMenuItem(title: "Turn On Any That Are Off", action: #selector(reconnectAll), keyEquivalent: "")
        rc.target = self
        rc.isEnabled = anyInactive
        rc.image = .symbol("arrow.clockwise", color: .labelColor)
        menu.addItem(rc)

        // 3. App settings.
        menu.addItem(.separator())

        let login = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        login.target = self
        login.isEnabled = true
        login.image = .symbol("arrow.right.to.line", color: .labelColor)
        login.state = launchesAtLogin ? .on : .off
        menu.addItem(login)

        let quit = NSMenuItem(title: "Quit DisplayToggle", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.isEnabled = true
        menu.addItem(quit)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory) // menubar only, no Dock icon
app.run()
