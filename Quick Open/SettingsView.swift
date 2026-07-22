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
    @State private var adaptiveIconsEnabled = QuickOpenWindowBehaviorSettings.adaptiveIconsEnabled
    @State private var windowSnappingEnabled = QuickOpenWindowBehaviorSettings.windowSnappingEnabled
    @State private var edgeAutoHideEnabled = QuickOpenWindowBehaviorSettings.edgeAutoHideEnabled
    @State private var autoHideDelay = QuickOpenWindowBehaviorSettings.autoHideDelay
    @State private var autoHideVisibleStrip = Double(QuickOpenWindowBehaviorSettings.autoHideVisibleStrip)
    @State private var autoHideLeftEdge = QuickOpenWindowBehaviorSettings.isAutoHideEdgeEnabled(.left)
    @State private var autoHideRightEdge = QuickOpenWindowBehaviorSettings.isAutoHideEdgeEnabled(.right)
    @State private var autoHideTopEdge = QuickOpenWindowBehaviorSettings.isAutoHideEdgeEnabled(.top)
    @State private var autoHideBottomEdge = QuickOpenWindowBehaviorSettings.isAutoHideEdgeEnabled(.bottom)
    @State private var animalTriggerEnabled = QuickOpenWindowBehaviorSettings.animalTriggerEnabled
    @State private var animalTriggerStyle = QuickOpenWindowBehaviorSettings.animalTriggerStyle
    @State private var animalTriggerSize = Double(QuickOpenWindowBehaviorSettings.animalTriggerSize)
    
    var body: some View {
        VStack(spacing: 16) {
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
            
            ScrollView {
                VStack(spacing: 18) {
                    launchSettings
                    windowBehaviorSettings
                }
                .padding(.vertical, 2)
            }
            
            // 底部信息
            Text("Quick Open v1.0")
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.6))
        }
        .padding(24)
        .frame(width: 460, height: edgeAutoHideEnabled ? 620 : 380)
    }
    
    private var launchSettings: some View {
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
    }
    
    private var windowBehaviorSettings: some View {
        VStack(spacing: 14) {
            settingsToggleRow(
                icon: "square.grid.3x3.fill",
                title: "图标自适应窗口大小",
                subtitle: "缩放窗口时自动调整快捷方式图标、文字和间距",
                isOn: $adaptiveIconsEnabled,
                key: QuickOpenWindowBehaviorSettings.adaptiveIconsKey
            )
            
            settingsToggleRow(
                icon: "rectangle.2.swap",
                title: "窗口自动吸附对齐",
                subtitle: "拖到屏幕边缘或靠近其他窗口时自动贴齐",
                isOn: $windowSnappingEnabled,
                key: QuickOpenWindowBehaviorSettings.windowSnappingKey
            )
            
            settingsToggleRow(
                icon: "sidebar.left",
                title: "贴边自动隐藏",
                subtitle: "窗口贴到屏幕边缘后自动缩成窄条，鼠标划过显示",
                isOn: $edgeAutoHideEnabled,
                key: QuickOpenWindowBehaviorSettings.edgeAutoHideKey
            )
            
            if edgeAutoHideEnabled {
                edgeAutoHideDetailSettings
            }
        }
    }
    
    private var edgeAutoHideDetailSettings: some View {
        VStack(spacing: 12) {
            HStack {
                Text("隐藏延迟")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 72, alignment: .leading)
                Slider(value: $autoHideDelay, in: 0.2...2.0)
                    .onChange(of: autoHideDelay) {
                        UserDefaults.standard.set(autoHideDelay, forKey: QuickOpenWindowBehaviorSettings.autoHideDelayKey)
                        QuickOpenWindowBehaviorSettings.notifyChanged()
                    }
                Text(String(format: "%.1fs", autoHideDelay))
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
                    .frame(width: 42, alignment: .trailing)
            }
            
            HStack {
                Text("露出宽度")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 72, alignment: .leading)
                Slider(value: $autoHideVisibleStrip, in: 4...18, step: 1)
                    .onChange(of: autoHideVisibleStrip) {
                        UserDefaults.standard.set(autoHideVisibleStrip, forKey: QuickOpenWindowBehaviorSettings.autoHideVisibleStripKey)
                        QuickOpenWindowBehaviorSettings.notifyChanged()
                    }
                Text("\(Int(autoHideVisibleStrip))px")
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
                    .frame(width: 42, alignment: .trailing)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("启用边缘")
                    .font(.caption)
                    .foregroundColor(.secondary)
                HStack(spacing: 10) {
                    compactToggle("左", isOn: $autoHideLeftEdge, key: QuickOpenWindowBehaviorSettings.autoHideLeftEdgeKey)
                    compactToggle("右", isOn: $autoHideRightEdge, key: QuickOpenWindowBehaviorSettings.autoHideRightEdgeKey)
                    compactToggle("上", isOn: $autoHideTopEdge, key: QuickOpenWindowBehaviorSettings.autoHideTopEdgeKey)
                    compactToggle("下", isOn: $autoHideBottomEdge, key: QuickOpenWindowBehaviorSettings.autoHideBottomEdgeKey)
                }
            }
            
            Divider()
            
            settingsToggleRow(
                icon: "pawprint.fill",
                title: "小动物触发器",
                subtitle: "窗口隐藏后在可见边中间显示小动物，划过即可展开",
                isOn: $animalTriggerEnabled,
                key: QuickOpenWindowBehaviorSettings.animalTriggerEnabledKey
            )
            
            if animalTriggerEnabled {
                HStack {
                    Text("样式")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 72, alignment: .leading)
                    Picker("", selection: $animalTriggerStyle) {
                        ForEach(QuickOpenPetOption.all) { option in
                            Text(option.title).tag(option.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: animalTriggerStyle) {
                        let normalizedStyle = QuickOpenPetOption.normalizedStyle(animalTriggerStyle)
                        animalTriggerStyle = normalizedStyle
                        UserDefaults.standard.set(normalizedStyle, forKey: QuickOpenWindowBehaviorSettings.animalTriggerStyleKey)
                        QuickOpenWindowBehaviorSettings.notifyChanged()
                    }
                }
                
                HStack {
                    Text("大小")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 72, alignment: .leading)
                    Slider(value: $animalTriggerSize, in: 96...180, step: 1)
                        .onChange(of: animalTriggerSize) {
                            UserDefaults.standard.set(animalTriggerSize, forKey: QuickOpenWindowBehaviorSettings.animalTriggerSizeKey)
                            QuickOpenWindowBehaviorSettings.notifyChanged()
                        }
                    Text("\(Int(animalTriggerSize))px")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.secondary)
                        .frame(width: 42, alignment: .trailing)
                }
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .cornerRadius(10)
    }
    private func settingsToggleRow(
        icon: String,
        title: String,
        subtitle: String,
        isOn: Binding<Bool>,
        key: String
    ) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .font(.system(size: 14))
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14))
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Toggle("", isOn: isOn)
                .toggleStyle(.switch)
                .controlSize(.small)
                .onChange(of: isOn.wrappedValue) {
                    UserDefaults.standard.set(isOn.wrappedValue, forKey: key)
                    QuickOpenWindowBehaviorSettings.notifyChanged()
                }
        }
    }
    
    private func compactToggle(_ title: String, isOn: Binding<Bool>, key: String) -> some View {
        Toggle(title, isOn: isOn)
            .toggleStyle(.checkbox)
            .controlSize(.small)
            .onChange(of: isOn.wrappedValue) {
                UserDefaults.standard.set(isOn.wrappedValue, forKey: key)
                QuickOpenWindowBehaviorSettings.notifyChanged()
            }
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
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 620),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
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
