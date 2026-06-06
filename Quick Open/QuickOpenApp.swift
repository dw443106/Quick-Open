//
//  QuickOpenApp.swift
//  Quick Open
//
//  Created by mimi on 2026-05-19.
//

import SwiftUI
import Combine

private let kSavedConfigsKey = "SavedRiceWindowConfigs"

class RiceWindowStore: ObservableObject {
    @Published var controllers: [RiceWindowController] = []
}

@main
struct QuickOpenApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    
    var windowStore = RiceWindowStore()
    
    private var managerController: WindowManagerController?
    private var settingsController: SettingsWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupStatusBar()
        
        let savedConfigs = loadSavedConfigs()
        if savedConfigs.isEmpty {
            let defaultConfig = RiceWindowConfig(
                title: "常用工具",
                x: 200, y: 300,
                width: 240, height: 200,
                colorHex: "#1E272E",
                titleColorHex: "#FFFFFF",
                opacity: 0.85,
                appPaths: []
            )
            createNewRiceWindow(with: defaultConfig)
        } else {
            for config in savedConfigs {
                createNewRiceWindow(with: config)
            }
        }
    }
    
    // MARK: - 配置持久化
    
    private func saveCurrentConfigs() {
        let configs = windowStore.controllers.map { $0.config }
        if let data = try? JSONEncoder().encode(configs) {
            UserDefaults.standard.set(data, forKey: kSavedConfigsKey)
            UserDefaults.standard.synchronize()
        }
    }
    
    private func scheduleSaveCurrentConfigs() {
        saveCurrentConfigs()
    }
    
    private func loadSavedConfigs() -> [RiceWindowConfig] {
        guard let data = UserDefaults.standard.data(forKey: kSavedConfigsKey),
              let configs = try? JSONDecoder().decode([RiceWindowConfig].self, from: data) else {
            return []
        }
        return configs
    }

    func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "uiwindow.split.2x1", accessibilityDescription: "Quick Open")
        }

        let menu = NSMenu()
        let newWindowItem = NSMenuItem(title: "➕ 新建窗口", action: #selector(menuCreateNewWindow), keyEquivalent: "n")
        newWindowItem.target = self
        menu.addItem(newWindowItem)
        
        let manageItem = NSMenuItem(title: "📋 管理所有窗口", action: #selector(menuOpenManager), keyEquivalent: "m")
        manageItem.target = self
        menu.addItem(manageItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let settingsItem = NSMenuItem(title: "⚙️ 设置", action: #selector(menuOpenSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        let quitItem = NSMenuItem(title: "退出", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        statusItem?.menu = menu
    }

    @objc func menuCreateNewWindow() {
        let newConfig = RiceWindowConfig(
            title: "新建窗口",
            x: 400, y: 400,
            width: 240, height: 200,
            colorHex: "#3498DB",
            titleColorHex: "#FFFFFF",
            opacity: 0.9,
            appPaths: []
        )
        createNewRiceWindow(with: newConfig)
    }
    
    @objc func menuOpenManager() {
        if let existing = managerController {
            existing.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let controller = WindowManagerController(
            windowStore: windowStore,
            onRemoveController: { [weak self] removedController in
                guard let self = self else { return }
                self.windowStore.controllers.removeAll { $0 === removedController }
                self.scheduleSaveCurrentConfigs()
            }
        )
        controller.window?.delegate = self
        controller.showWindow(nil)
        managerController = controller
    }
    
    @objc func menuOpenSettings() {
        if let existing = settingsController {
            existing.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let controller = SettingsWindowController()
        controller.window?.delegate = self
        controller.showWindow(nil)
        settingsController = controller
    }
    
    func createNewRiceWindow(with config: RiceWindowConfig) {
        let controller = RiceWindowController(config: config)
        controller.onConfigChanged = { [weak self] in
            self?.scheduleSaveCurrentConfigs()
        }
        controller.showWindow(nil)
        windowStore.controllers.append(controller)
        scheduleSaveCurrentConfigs()
    }

    @objc func quitApp() {
        saveCurrentConfigs()
        NSApplication.shared.terminate(nil)
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        saveCurrentConfigs()
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        if notification.object as? NSWindow === managerController?.window {
            managerController = nil
        }
        if notification.object as? NSWindow === settingsController?.window {
            settingsController = nil
        }
    }
}
