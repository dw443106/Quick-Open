//
//  SettingsView.swift
//  Quick Open
//
//  Created by 杜伟 on 2026/5/20.
//

import SwiftUI
import ServiceManagement
import CoreServices

private let kLaunchAtLoginKey = "LaunchAtLogin"

/// 设置窗口视图
struct SettingsView: View {
    @State private var launchAtLogin: Bool = {
        // 读取保存的开机启动设置
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        } else {
            return UserDefaults.standard.bool(forKey: kLaunchAtLoginKey)
        }
    }()
    
    var body: some View {
        VStack(spacing: 20) {
            // 标题
            HStack {
                Image(systemName: "gearshape.fill")
                    .foregroundColor(.accentColor)
                Text("设置")
                    .font(.system(size: 18, weight: .semibold))
                Spacer()
            }
            .padding(.bottom, 8)
            
            Divider()
            
            // 开机启动
            HStack {
                Image(systemName: "power")
                    .foregroundColor(.secondary)
                    .font(.system(size: 14))
                VStack(alignment: .leading, spacing: 2) {
                    Text("开机自动启动")
                        .font(.system(size: 14))
                    Text("登录 Mac 后自动启动 Quick Open")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Toggle("", isOn: $launchAtLogin)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .onChange(of: launchAtLogin) {
                        toggleLaunchAtLogin(enabled: launchAtLogin)
                    }
            }
            .padding(.vertical, 4)
            
            Spacer()
            
            // 底部信息
            Text("Quick Open v1.0")
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.6))
        }
        .padding(24)
        .frame(width: 360, height: 220)
    }
    
    /// 切换开机启动
    private func toggleLaunchAtLogin(enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("开机启动设置失败: \(error)")
                // 回滚
                launchAtLogin = !enabled
            }
        } else {
            // macOS 12 及以下：使用 LSSharedFileList
            UserDefaults.standard.set(enabled, forKey: kLaunchAtLoginKey)
            toggleLegacyLaunchAtLogin(enabled: enabled)
        }
    }
    
    /// macOS 12 及以下的开机启动实现
    private func toggleLegacyLaunchAtLogin(enabled: Bool) {
        guard let bundleURL = Bundle.main.bundleURL as NSURL? else { return }
        
        if let loginItemsRef = LSSharedFileListCreate(nil, kLSSharedFileListSessionLoginItems.takeRetainedValue(), nil)?.takeRetainedValue() {
            let loginItems = loginItemsRef as LSSharedFileList
            
            if enabled {
                // 添加登录项
                LSSharedFileListInsertItemURL(
                    loginItems,
                    kLSSharedFileListItemLast.takeRetainedValue(),
                    nil,
                    nil,
                    bundleURL,
                    nil,
                    nil
                )
            } else {
                // 移除登录项
                let itemsSnapshot = LSSharedFileListCopySnapshot(loginItems, nil)?.takeRetainedValue() as? [LSSharedFileListItem]
                for item in itemsSnapshot ?? [] {
                    if let itemURL = LSSharedFileListItemCopyResolvedURL(item, 0, nil)?.takeRetainedValue() as URL? {
                        if itemURL == bundleURL as URL {
                            LSSharedFileListItemRemove(loginItems, item)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - 设置窗口控制器

class SettingsWindowController: NSWindowController {
    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 220),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "设置"
        window.contentView = NSHostingView(rootView: SettingsView())
        window.center()
        window.isMovableByWindowBackground = true
        
        self.init(window: window)
    }
}
