import AppKit
import SwiftUI

public struct FolicoDesktopApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var menuBarController = FolicoMenuBarController()

    public init() {}

    public var body: some Scene {
        WindowGroup("Folico", id: "main") {
            RootView()
                .environmentObject(appState)
                .installFolicoMenuBar(appState: appState, controller: menuBarController)
                .frame(minWidth: 980, minHeight: 680)
        }
        .windowStyle(.titleBar)

        Settings {
            SettingsView()
                .environmentObject(appState)
                .installFolicoMenuBar(appState: appState, controller: menuBarController)
                .frame(width: 560)
        }
    }
}

private extension View {
    func installFolicoMenuBar(appState: AppState, controller: FolicoMenuBarController) -> some View {
        onAppear {
            controller.update(isVisible: appState.config.settings.showMenuBarIcon, appState: appState)
        }
        .onReceive(appState.$config) { config in
            controller.update(isVisible: config.settings.showMenuBarIcon, appState: appState)
        }
    }
}

@MainActor
private final class FolicoMenuBarController: ObservableObject {
    private weak var appState: AppState?
    private var statusItem: NSStatusItem?

    func update(isVisible: Bool, appState: AppState) {
        self.appState = appState
        if isVisible {
            installStatusItem()
            rebuildMenu()
        } else {
            removeStatusItem()
        }
    }

    private func installStatusItem() {
        guard statusItem == nil else { return }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "folder.fill", accessibilityDescription: "Folico")
        item.button?.image?.isTemplate = true
        statusItem = item
    }

    private func removeStatusItem() {
        guard let statusItem else { return }
        NSStatusBar.system.removeStatusItem(statusItem)
        self.statusItem = nil
    }

    private func rebuildMenu() {
        guard let appState, let statusItem else { return }

        let menu = NSMenu()
        menu.addItem(menuItem("Open Folico", action: #selector(openFolico)))
        menu.addItem(menuItem("Add Folder", action: #selector(addFolder)))

        let scanItem = menuItem(appState.isScanning ? "Scanning" : "Scan Now", action: #selector(scanNow))
        scanItem.isEnabled = !appState.config.watchedFolders.isEmpty && !appState.isScanning
        menu.addItem(scanItem)

        menu.addItem(.separator())

        let autoWatchItem = menuItem("Auto Watch Folders", action: #selector(toggleAutoWatch))
        autoWatchItem.state = appState.config.settings.autoWatchFolders ? .on : .off
        menu.addItem(autoWatchItem)

        menu.addItem(menuItem("Hide Menu Bar Icon", action: #selector(hideMenuBarIcon)))
        menu.addItem(.separator())
        menu.addItem(menuItem("Quit Folico", action: #selector(quitFolico)))
        statusItem.menu = menu
    }

    private func menuItem(_ title: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    @objc private func openFolico() {
        NSApp.windows.first { $0.canBecomeMain }?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func addFolder() {
        openFolico()
        appState?.chooseWatchedFolder()
        rebuildMenu()
    }

    @objc private func scanNow() {
        openFolico()
        appState?.scanNow()
        rebuildMenu()
    }

    @objc private func toggleAutoWatch() {
        guard let appState else { return }
        appState.setAutoWatchFolders(!appState.config.settings.autoWatchFolders)
        rebuildMenu()
    }

    @objc private func hideMenuBarIcon() {
        appState?.setShowMenuBarIcon(false)
        removeStatusItem()
    }

    @objc private func quitFolico() {
        NSApp.terminate(nil)
    }
}
