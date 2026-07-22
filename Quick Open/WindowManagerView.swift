//
//  WindowManagerView.swift
//  Quick Open
//
//  Created by 杜伟 on 2026/5/19.
//

import SwiftUI
import AppKit

/// 窗口管理视图：列出所有窗口，支持编辑名称、颜色、透明度，以及删除窗口
struct WindowManagerView: View {
    @ObservedObject var windowStore: RiceWindowStore
    let onClose: () -> Void
    let onCreateShortcutWindow: () -> Void
    let onCreateAIDashboardWindow: () -> Void
    let onRemoveController: (RiceWindowController) -> Void
    
    private var controllers: [RiceWindowController] {
        windowStore.controllers
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Image(systemName: "square.grid.2x2.fill")
                    .foregroundColor(.accentColor)
                Text("窗口管理")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Text("共 \(controllers.count) 个窗口")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Button {
                    onCreateShortcutWindow()
                } label: {
                    Label("快捷窗口", systemImage: "plus.square")
                }
                .controlSize(.small)
                
                Button {
                    onCreateAIDashboardWindow()
                } label: {
                    Label("AI 仪表盘", systemImage: "sparkles")
                }
                .controlSize(.small)
                
                Button("关闭") {
                    onClose()
                }
                .keyboardShortcut(.escape)
                .controlSize(.small)
            }
            .padding()
            
            Divider()
            
            if controllers.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "square.dashed")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary.opacity(0.4))
                    Text("暂无窗口")
                        .foregroundColor(.secondary)
                    Text("点击上方按钮创建快捷窗口或 AI 仪表盘")
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.6))
                    Spacer()
                }
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(Array(controllers.enumerated()), id: \.element.config.id) { _, controller in
                            WindowConfigRow(
                                controller: controller,
                                onDelete: {
                                    onRemoveController(controller)
                                }
                            )
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(width: 520, height: 460)
        .background(
            // 使用毛玻璃背景 — 这里的 VisualEffectView 在普通窗口级别使用，不会引发布格崩溃
            WindowManagerVisualEffectView(material: .sidebar, blendingMode: .withinWindow)
        )
    }
}

// MARK: - 单个窗口配置行
struct WindowConfigRow: View {
    @ObservedObject var controller: RiceWindowController
    let onDelete: () -> Void
    
    @State private var isExpanded: Bool = false
    @State private var pickerColor: Color = .clear
    @State private var titleColorPicker: Color = .clear
    
    // 用本地状态编辑，提交时才写入 controller
    @State private var editTitle: String = ""
    @State private var editOpacity: Double = 0.85
    @State private var selectedAnimalTriggerStyle: String = "default"
    
    let presetColors = [
        "#FF5E57", "#FF6B6B", "#FFA502", "#FFDA79",
        "#2ED573", "#2ECC71", "#1ABC9C", "#00D2D3",
        "#3498DB", "#3742FA", "#A29BFE", "#8854D0",
        "#1E272E", "#2C3E50", "#636E72", "#DFE6E9"
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // 概览行
            HStack(spacing: 12) {
                // 颜色预览小圆点
                Circle()
                    .fill(Color(hex: controller.config.colorHex))
                    .frame(width: 12, height: 12)
                
                // 窗口名称
                if isExpanded {
                    TextField("窗口名称", text: $editTitle)
                        .textFieldStyle(.roundedBorder)
                        .controlSize(.small)
                        .frame(width: 140)
                        .onSubmit {
                            commitTitle()
                        }
                } else {
                    Text(controller.config.title)
                        .font(.system(size: 13, weight: .medium))
                        .frame(width: 140, alignment: .leading)
                        .lineLimit(1)
                }
                
                // 透明度
                Text("透明度 \(Int(controller.config.opacity * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 80)
                
                // App 数量
                Text(controller.config.windowKind == RiceWindowKind.aiDashboard ? "AI 仪表盘" : "\(controller.config.appPaths.count) 个应用")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // 展开/折叠按钮
                Button(action: {
                    withAnimation { isExpanded.toggle() }
                }) {
                    Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help(isExpanded ? "收起" : "展开编辑")
                
                // 删除窗口按钮
                Button(action: confirmDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red.opacity(0.7))
                }
                .buttonStyle(.plain)
                .help("删除此窗口")
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            
            // 展开后的详细编辑面板
            if isExpanded {
                VStack(spacing: 10) {
                    Divider()
                    
                    // 透明度滑块
                    HStack(spacing: 10) {
                        Image(systemName: "circle.fill").font(.system(size: 8))
                        Slider(value: $editOpacity, in: 0.1...1.0)
                            .controlSize(.small)
                            .onChange(of: editOpacity) {
                                commitOpacity(editOpacity)
                            }
                        Image(systemName: "circle.fill").font(.system(size: 16))
                        Text("\(Int(editOpacity * 100))%")
                            .font(.caption).monospacedDigit()
                            .frame(width: 32)
                    }
                    
                    // 颜色选择
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text("主题色")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            ColorPicker("自定义", selection: $pickerColor)
                                .labelsHidden()
                                .controlSize(.small)
                                .onChange(of: pickerColor) {
                                    let color: Color = _pickerColor.wrappedValue
                                    if let cgColor = color.cgColor,
                                       let nsColor = NSColor(cgColor: cgColor)?.usingColorSpace(.sRGB) {
                                        let r = Int(nsColor.redComponent * 255)
                                        let g = Int(nsColor.greenComponent * 255)
                                        let b = Int(nsColor.blueComponent * 255)
                                        let hex = String(format: "#%02X%02X%02X", r, g, b)
                                        commitColor(hex)
                                    }
                                }
                        }
                        
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 22, maximum: 22), spacing: 6)], spacing: 6) {
                            ForEach(presetColors, id: \.self) { hex in
                                Circle()
                                    .fill(Color(hex: hex))
                                    .frame(width: 22, height: 22)
                                    .overlay(
                                        Circle()
                                            .stroke(controller.config.colorHex == hex ? Color.primary : Color.clear, lineWidth: 2)
                                    )
                                    .onTapGesture {
                                        commitColor(hex)
                                    }
                            }
                        }
                    }
                    
                    // 标题字体颜色
                    Divider()
                    HStack(spacing: 8) {
                        Image(systemName: "textformat.size").foregroundColor(.secondary).font(.system(size: 10))
                        Text("字体颜色").font(.caption).foregroundColor(.secondary)
                        Spacer()
                        ColorPicker("字体颜色", selection: $titleColorPicker)
                            .labelsHidden()
                            .controlSize(.small)
                            .onChange(of: titleColorPicker) {
                                let color: Color = _titleColorPicker.wrappedValue
                                if let cgColor = color.cgColor,
                                   let nsColor = NSColor(cgColor: cgColor)?.usingColorSpace(.sRGB) {
                                    let r = Int(nsColor.redComponent * 255)
                                    let g = Int(nsColor.greenComponent * 255)
                                    let b = Int(nsColor.blueComponent * 255)
                                    let hex = String(format: "#%02X%02X%02X", r, g, b)
                                    controller.updateTitleColor(hex: hex)
                                }
                            }
                    }
                    
                    // 背景图片
                    Divider()
                    HStack(spacing: 8) {
                        Image(systemName: "photo.fill").foregroundColor(.secondary).font(.system(size: 10))
                        Text("背景图片").font(.caption).foregroundColor(.secondary)
                        Spacer()
                        if controller.config.backgroundImagePath != nil {
                            Text("已设置").font(.caption).foregroundColor(.secondary)
                            Button("清除") {
                                controller.clearBackgroundImage()
                            }
                            .controlSize(.small)
                        }
                        Button("选择图片") {
                            controller.pickBackgroundImage()
                        }
                        .controlSize(.small)
                    }
                    
                    // 贴边隐藏小宠物
                    Divider()
                    HStack(spacing: 8) {
                        Image(systemName: "pawprint.fill").foregroundColor(.secondary).font(.system(size: 10))
                        Text("隐藏宠物").font(.caption).foregroundColor(.secondary)
                        Spacer()
                        Image(QuickOpenPetOption.assetName(for: effectiveAnimalTriggerStyle))
                            .resizable()
                            .scaledToFit()
                            .frame(width: 34, height: 34)
                        Picker("", selection: $selectedAnimalTriggerStyle) {
                            Text("跟随全局").tag("default")
                            ForEach(QuickOpenPetOption.all) { option in
                                Text(option.title).tag(option.id)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 120)
                        .onChange(of: selectedAnimalTriggerStyle) {
                            commitAnimalTriggerStyle()
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
                .transition(.opacity)
            }
            } // VStack end (outer)
            .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(hex: controller.config.colorHex).opacity(0.06))
            )
            .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            )
            .onAppear {
                syncFromController()
            }
        }
    
    // MARK: - Helpers
    
    private func syncFromController() {
        editTitle = controller.config.title
        editOpacity = controller.config.opacity
        pickerColor = Color(hex: controller.config.colorHex)
        titleColorPicker = Color(hex: controller.config.titleColorHex)
        selectedAnimalTriggerStyle = controller.config.animalTriggerStyle ?? "default"
    }
    
    private func commitTitle() {
        controller.updateTitle(editTitle)
    }
    
    private func commitOpacity(_ value: Double) {
        controller.updateOpacity(value)
    }
    
    private func commitColor(_ hex: String) {
        pickerColor = Color(hex: hex)
        controller.updateColor(hex: hex)
    }
    
    private var effectiveAnimalTriggerStyle: String {
        selectedAnimalTriggerStyle == "default"
        ? QuickOpenWindowBehaviorSettings.animalTriggerStyle
        : selectedAnimalTriggerStyle
    }
    
    private func commitAnimalTriggerStyle() {
        if selectedAnimalTriggerStyle == "default" {
            controller.updateAnimalTriggerStyle(nil)
        } else {
            controller.updateAnimalTriggerStyle(selectedAnimalTriggerStyle)
        }
    }
    
    private func confirmDelete() {
        let alert = NSAlert()
        alert.messageText = "删除窗口「\(controller.config.title)」？"
        alert.informativeText = "窗口内的快捷方式不会受到影响。"
        alert.addButton(withTitle: "删除")
        alert.addButton(withTitle: "取消")
        if alert.runModal() == .alertFirstButtonReturn {
            controller.window?.close()
            onDelete()
        }
    }
}

// MARK: - 窗口管理器的 NSWindowController
class WindowManagerController: NSWindowController {
    
    init(
        windowStore: RiceWindowStore,
        onCreateShortcutWindow: @escaping () -> Void,
        onCreateAIDashboardWindow: @escaping () -> Void,
        onRemoveController: @escaping (RiceWindowController) -> Void
    ) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 460),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "窗口管理"
        window.center()
        window.isMovableByWindowBackground = true
        
        let rootView = WindowManagerView(
            windowStore: windowStore,
            onClose: { window.close() },
            onCreateShortcutWindow: onCreateShortcutWindow,
            onCreateAIDashboardWindow: onCreateAIDashboardWindow,
            onRemoveController: onRemoveController
        )
        window.contentView = NSHostingView(rootView: rootView)
        
        super.init(window: window)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - 毛玻璃视图桥接（仅用于管理窗口，在普通 NSWindow 中使用安全）
struct WindowManagerVisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.isEmphasized = true
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
