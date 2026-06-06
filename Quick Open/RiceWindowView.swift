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
    
    let columns = [
        GridItem(.adaptive(minimum: 80, maximum: 80), spacing: 12)
    ]
    
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
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(config.appPaths, id: \.self) { path in
                        AppIconItem(path: path) {
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
                .padding(12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                handleDrop(providers: providers)
                return true
            }
        }
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.15), lineWidth: 1))
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

// 单个App图标组件
struct AppIconItem: View {
    let path: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                    .resizable()
                    .frame(width: 56, height: 56)
                
                Text(URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent)
                    .font(.system(size: 12))
                    .lineLimit(1)
                    .foregroundColor(.primary)
            }
            .frame(width: 80)
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
