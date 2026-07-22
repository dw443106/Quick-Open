//
//  RiceWindowView.swift
//  Quick Open
//
//  Created by 杜伟 on 2026/5/19.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct RiceWindowView: View {
    @ObservedObject var controller: RiceWindowController
    
    @State private var isEditing = false
    @State private var adaptiveIconsEnabled = QuickOpenWindowBehaviorSettings.adaptiveIconsEnabled
    @State private var selectedAnimalTriggerStyle = "default"
    
    let presetColors = [
        "#FF5E57", "#FF6B6B", "#FFA502", "#FFDA79",
        "#2ED573", "#2ECC71", "#1ABC9C", "#00D2D3",
        "#3498DB", "#3742FA", "#A29BFE", "#8854D0",
        "#1E272E", "#2C3E50", "#636E72", "#DFE6E9"
    ]
    
    private var config: RiceWindowConfig {
        controller.config
    }
    
    private var titleBinding: Binding<String> {
        Binding(
            get: { controller.config.title },
            set: { controller.updateTitle($0) }
        )
    }
    
    private var opacityBinding: Binding<Double> {
        Binding(
            get: { controller.config.opacity },
            set: { controller.updateOpacity($0) }
        )
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部工具栏 — 标题居中，齿轮在右
            ZStack {
                // 标题居中
                if isEditing {
                    TextField("窗口名称", text: titleBinding, onCommit: {
                        isEditing = false
                    })
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 40)
                } else {
                    Text(config.title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color(hex: config.titleColorHex))
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                
                // 齿轮按钮靠右
                HStack {
                    Spacer()
                    Button(action: { isEditing.toggle() }) {
                        Image(systemName: isEditing ? "checkmark.circle.fill" : "gearshape.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 16))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            
            // 编辑面板
            if isEditing {
                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        Image(systemName: "circle.fill").font(.system(size: 10)).foregroundColor(.secondary)
                        Slider(value: opacityBinding, in: 0.1...1.0).controlSize(.small)
                        Image(systemName: "circle.fill").font(.system(size: 16)).foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: "paintpalette.fill").font(.system(size: 10)).foregroundColor(.secondary)
                            Text("主题色").font(.caption).foregroundColor(.secondary)
                            Spacer()
                            Text("管理页面可选更多颜色").font(.caption2).foregroundColor(.secondary.opacity(0.6))
                        }
                        
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 20, maximum: 20), spacing: 6)], spacing: 6) {
                            ForEach(presetColors, id: \.self) { hex in
                                Circle()
                                    .fill(Color(hex: hex))
                                    .frame(width: 20, height: 20)
                                    .overlay(Circle().stroke(config.colorHex == hex ? Color.white : Color.clear, lineWidth: 2))
                                    .onTapGesture {
                                        controller.updateColor(hex: hex)
                                    }
                            }
                        }
                    }
                    
                    Divider().opacity(0.35)
                    
                    HStack(spacing: 8) {
                        Image(systemName: "pawprint.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Text("隐藏宠物")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Image(QuickOpenPetOption.assetName(for: effectiveAnimalTriggerStyle))
                            .resizable()
                            .scaledToFit()
                            .frame(width: 32, height: 32)
                        Picker("", selection: $selectedAnimalTriggerStyle) {
                            Text("跟随全局").tag("default")
                            ForEach(QuickOpenPetOption.all) { option in
                                Text(option.title).tag(option.id)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 110)
                        .onChange(of: selectedAnimalTriggerStyle) {
                            commitAnimalTriggerStyle()
                        }
                    }
                }
                .padding(12)
                .background(.ultraThinMaterial)
                .cornerRadius(12)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .transition(.move(edge: .top).combined(with: .opacity))
                
                // 背景图片按钮
                HStack {
                    Image(systemName: "photo.fill").font(.system(size: 10)).foregroundColor(.secondary)
                    Text("背景图片").font(.caption).foregroundColor(.secondary)
                    Spacer()
                    Button("选择图片") {
                        controller.pickBackgroundImage()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    
                    if config.backgroundImagePath != nil {
                        Button("清除") {
                            controller.clearBackgroundImage()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 6)
            }
            
            Divider().opacity(0.3)
            
            // 图标网格
            GeometryReader { geometry in
                let layout = AdaptiveIconGridLayout.make(
                    availableSize: geometry.size,
                    itemCount: config.appPaths.count,
                    adaptive: adaptiveIconsEnabled
                )
                
                ScrollView {
                    LazyVGrid(columns: layout.columns, spacing: layout.spacing) {
                        ForEach(config.appPaths, id: \.self) { path in
                            AppIconItem(
                                path: path,
                                itemWidth: layout.itemWidth,
                                iconSize: layout.iconSize,
                                fontSize: layout.fontSize
                            ) {
                                let url = URL(fileURLWithPath: path)
                                let resolvedURL = (try? URL(resolvingAliasFileAt: url)) ?? url
                                NSWorkspace.shared.open(resolvedURL)
                            }
                            .contextMenu {
                                Button("移出窗口") {
                                    controller.removeApp(path: path)
                                }
                            }
                        }
                    }
                    .padding(layout.padding)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                handleDrop(providers: providers)
                return true
            }
        }
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.15), lineWidth: 1))
        .onAppear {
            selectedAnimalTriggerStyle = controller.config.animalTriggerStyle ?? "default"
        }
        .onReceive(NotificationCenter.default.publisher(for: QuickOpenWindowBehaviorSettings.changedNotification)) { _ in
            adaptiveIconsEnabled = QuickOpenWindowBehaviorSettings.adaptiveIconsEnabled
        }
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
    
    private func handleDrop(providers: [NSItemProvider]) {
        for provider in providers {
            provider.loadObject(ofClass: URL.self) { url, error in
                if let url = url, url.pathExtension == "app" || url.path.contains(".app") {
                    DispatchQueue.main.async {
                        controller.addApp(path: url.path)
                    }
                }
            }
        }
    }
}

private struct AdaptiveIconGridLayout {
    let columns: [GridItem]
    let itemWidth: CGFloat
    let iconSize: CGFloat
    let fontSize: CGFloat
    let spacing: CGFloat
    let padding: CGFloat
    
    static func make(availableSize: CGSize, itemCount: Int, adaptive: Bool) -> AdaptiveIconGridLayout {
        guard adaptive else {
            return fixed(availableWidth: availableSize.width)
        }
        
        let padding: CGFloat = availableSize.width < 170 ? 6 : 8
        let spacing: CGFloat = availableSize.width < 170 ? 5 : 6
        let usableWidth = max(availableSize.width - padding * 2, 44)
        let usableHeight = max(availableSize.height - padding * 2, 44)
        
        let minimumItemWidth: CGFloat = 44
        let maximumColumns = max(1, Int((usableWidth + spacing) / (minimumItemWidth + spacing)))
        let cappedColumns = max(1, min(maximumColumns, max(itemCount, 1)))
        var bestColumns = 1
        var bestItemWidth = usableWidth
        var bestIconSize: CGFloat = 26
        var bestFontSize: CGFloat = 9
        var bestScore: CGFloat = -1
        
        for columns in 1...cappedColumns {
            let rows = max(1, Int(ceil(Double(max(itemCount, 1)) / Double(columns))))
            let itemWidth = floor((usableWidth - CGFloat(columns - 1) * spacing) / CGFloat(columns))
            let rowHeight = floor((usableHeight - CGFloat(rows - 1) * spacing) / CGFloat(rows))
            let heightConstrainedIcon = max(24, (rowHeight - 18) * 0.86)
            let widthConstrainedIcon = itemWidth * 0.72
            let iconSize = min(58, max(24, floor(min(widthConstrainedIcon, heightConstrainedIcon))))
            let fontSize = min(12, max(9, floor(min(itemWidth * 0.16, max(rowHeight * 0.16, 9)))))
            let fitBonus: CGFloat = rowHeight >= iconSize + fontSize + 6 ? 20 : 0
            let score = iconSize * 10 + fitBonus - CGFloat(rows) * 0.2
            
            if score > bestScore {
                bestScore = score
                bestColumns = columns
                bestItemWidth = itemWidth
                bestIconSize = iconSize
                bestFontSize = fontSize
            }
        }
        
        return AdaptiveIconGridLayout(
            columns: Array(repeating: GridItem(.fixed(bestItemWidth), spacing: spacing), count: bestColumns),
            itemWidth: bestItemWidth,
            iconSize: bestIconSize,
            fontSize: bestFontSize,
            spacing: spacing,
            padding: padding
        )
    }
    
    private static func fixed(availableWidth: CGFloat) -> AdaptiveIconGridLayout {
        let spacing: CGFloat = 6
        let padding: CGFloat = 8
        let usableWidth = max(availableWidth - padding * 2, 80)
        let columnsCount = max(1, Int((usableWidth + spacing) / (80 + spacing)))
        return AdaptiveIconGridLayout(
            columns: Array(repeating: GridItem(.fixed(80), spacing: spacing), count: columnsCount),
            itemWidth: 80,
            iconSize: 56,
            fontSize: 12,
            spacing: spacing,
            padding: padding
        )
    }
}

// 单个App图标组件
struct AppIconItem: View {
    let path: String
    let itemWidth: CGFloat
    let iconSize: CGFloat
    let fontSize: CGFloat
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                    .resizable()
                    .frame(width: iconSize, height: iconSize)
                
                Text(URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent)
                    .font(.system(size: fontSize))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundColor(.primary)
                    .frame(width: itemWidth)
            }
            .frame(width: itemWidth)
        }
        .buttonStyle(.plain)
    }
}

// 辅助扩展
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 1)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}
