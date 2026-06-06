//
//  RiceWindow.swift
//  Quick Open
//
//  Created by 杜伟 on 2026/5/19.
//

import Cocoa
import SwiftUI
import CoreGraphics
import Combine
import UniformTypeIdentifiers

// Quick Open 窗口数据模型
struct RiceWindowConfig: Identifiable, Codable {
    var id = UUID()
    var title: String
    var x: CGFloat
    var y: CGFloat
    var width: CGFloat
    var height: CGFloat
    var colorHex: String
    var titleColorHex: String     // 标题字体颜色
    var opacity: Double
    var appPaths: [String]
    var backgroundImagePath: String?
    
    // 兼容旧保存数据：没有 titleColorHex 字段时使用白色
    init(id: UUID = UUID(), title: String, x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, colorHex: String, titleColorHex: String = "#FFFFFF", opacity: Double, appPaths: [String], backgroundImagePath: String? = nil) {
        self.id = id
        self.title = title
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.colorHex = colorHex
        self.titleColorHex = titleColorHex
        self.opacity = opacity
        self.appPaths = appPaths
        self.backgroundImagePath = backgroundImagePath
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try container.decode(String.self, forKey: .title)
        x = try container.decode(CGFloat.self, forKey: .x)
        y = try container.decode(CGFloat.self, forKey: .y)
        width = try container.decode(CGFloat.self, forKey: .width)
        height = try container.decode(CGFloat.self, forKey: .height)
        colorHex = try container.decode(String.self, forKey: .colorHex)
        titleColorHex = try container.decodeIfPresent(String.self, forKey: .titleColorHex) ?? "#FFFFFF"
        opacity = try container.decode(Double.self, forKey: .opacity)
        appPaths = try container.decodeIfPresent([String].self, forKey: .appPaths) ?? []
        backgroundImagePath = try container.decodeIfPresent(String.self, forKey: .backgroundImagePath)
    }
}

// 自定义 NSWindow 子类，强制允许无边框窗口获得焦点
class QuickOpenRiceWindow: NSWindow {
    override var canBecomeKey: Bool {
        return true
    }
    
    override var canBecomeMain: Bool {
        return true
    }
}

class RiceWindowController: NSWindowController, ObservableObject {
    @Published var config: RiceWindowConfig {
        didSet {
            onConfigChanged?()
        }
    }
    
    var onConfigChanged: (() -> Void)?
    
    static var defaultTransparentImagePath: String? {
        Bundle.main.path(forResource: "transparent_bg", ofType: "png")
    }
    
    private var vibrancyView: NSVisualEffectView?
    private var backgroundImageView: NSView?
    private var colorOverlay: NSView?
    private var hostingView: NSHostingView<RiceWindowView>?
    
    init(config: RiceWindowConfig) {
        self.config = config
        
        let window = QuickOpenRiceWindow(
            contentRect: NSRect(x: config.x, y: config.y, width: config.width, height: config.height),
            styleMask: [.borderless, .resizable],
            backing: .buffered,
            defer: false
        )
        
        super.init(window: window)
        
        window.title = config.title
        window.isOpaque = false
        window.backgroundColor = NSColor.clear
        window.hasShadow = true
        
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
        window.isMovableByWindowBackground = true
        window.orderFront(nil)
        window.hidesOnDeactivate = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        
        // 监听窗口移动和缩放，实时保存位置和尺寸
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidMove),
            name: NSWindow.didMoveNotification,
            object: window
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidMove),
            name: NSWindow.didResizeNotification,
            object: window
        )
        
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func windowDidMove() {
        guard let frame = window?.frame else { return }
        var newConfig = config
        newConfig.x = frame.origin.x
        newConfig.y = frame.origin.y
        newConfig.width = frame.size.width
        newConfig.height = frame.size.height
        config = newConfig
    }
    
    private func setupViews() {
        guard let window = window else { return }
        
        let bounds = window.contentView?.bounds ?? .zero
        
        let containerView = NSView(frame: bounds)
        containerView.autoresizingMask = [.width, .height]
        
        // === 第1层：毛玻璃 ===
        let vibrancy = NSVisualEffectView(frame: bounds)
        vibrancy.autoresizingMask = [.width, .height]
        vibrancy.material = .sidebar
        vibrancy.blendingMode = .behindWindow
        vibrancy.state = .active
        vibrancy.isEmphasized = true
        vibrancy.isHidden = config.backgroundImagePath != nil
        containerView.addSubview(vibrancy)
        self.vibrancyView = vibrancy
        
        // === 第2层：背景图片 ===
        let imgView = NSView(frame: bounds)
        imgView.autoresizingMask = [.width, .height]
        imgView.wantsLayer = true
        imgView.layer?.cornerRadius = 12
        imgView.layer?.masksToBounds = true
        if let path = config.backgroundImagePath, let image = NSImage(contentsOfFile: path) {
            imgView.layer?.contents = image
            imgView.layer?.contentsGravity = .resizeAspectFill
        }
        imgView.isHidden = config.backgroundImagePath == nil
        containerView.addSubview(imgView)
        self.backgroundImageView = imgView
        
        // === 第3层：颜色叠加层 ===
        let overlay = NSView(frame: bounds)
        overlay.autoresizingMask = [.width, .height]
        overlay.wantsLayer = true
        overlay.layer?.cornerRadius = 12
        overlay.layer?.masksToBounds = true
        overlay.layer?.backgroundColor = hexToNSColor(config.colorHex, alpha: config.backgroundImagePath != nil ? 0.35 : config.opacity)
        containerView.addSubview(overlay)
        self.colorOverlay = overlay
        
        // === 第4层：SwiftUI ===
        let rootView = RiceWindowView(controller: self)
        let hosting = NSHostingView(rootView: rootView)
        hosting.frame = bounds
        hosting.autoresizingMask = [.width, .height]
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = .clear
        hosting.layer?.isOpaque = false
        containerView.addSubview(hosting)
        self.hostingView = hosting
        
        window.contentView = containerView
    }
    
    func refreshAppearance() {
        window?.title = config.title
        updateBackgroundViews()
        // 只更新 AppKit 层，不重建 hosting view（节省内存）
    }
    
    // MARK: - 背景图片
    
    func setBackgroundImage(path: String?) {
        var newConfig = config
        newConfig.backgroundImagePath = path
        config = newConfig
        updateBackgroundViews()
        if let hosting = hostingView {
            hosting.rootView = RiceWindowView(controller: self)
        }
    }
    
    func pickBackgroundImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.message = "选择窗口背景图片"
        panel.prompt = "选择"
        panel.begin { [weak self] response in
            if response == .OK, let url = panel.url {
                self?.setBackgroundImage(path: url.path)
            }
        }
    }
    
    func clearBackgroundImage() {
        setBackgroundImage(path: nil)
    }
    
    // MARK: - 颜色/透明度/字体颜色
    
    func updateTitle(_ title: String) {
        var newConfig = config
        newConfig.title = title
        config = newConfig
        window?.title = title
    }
    
    func updateColor(hex: String) {
        var newConfig = config
        newConfig.colorHex = hex
        config = newConfig
        let alpha = config.backgroundImagePath != nil ? 0.35 : config.opacity
        colorOverlay?.layer?.backgroundColor = hexToNSColor(hex, alpha: alpha)
    }
    
    func updateOpacity(_ value: Double) {
        var newConfig = config
        newConfig.opacity = value
        config = newConfig
        let alpha = config.backgroundImagePath != nil ? 0.35 : value
        colorOverlay?.layer?.backgroundColor = hexToNSColor(config.colorHex, alpha: alpha)
    }
    
    func updateTitleColor(hex: String) {
        var newConfig = config
        newConfig.titleColorHex = hex
        config = newConfig
        if let hosting = hostingView {
            hosting.rootView = RiceWindowView(controller: self)
        }
    }
    
    func addApp(path: String) {
        guard !config.appPaths.contains(path) else { return }
        var newConfig = config
        newConfig.appPaths.append(path)
        config = newConfig
        onConfigChanged?()
    }
    
    func removeApp(path: String) {
        guard config.appPaths.contains(path) else { return }
        var newConfig = config
        newConfig.appPaths.removeAll { $0 == path }
        config = newConfig
        onConfigChanged?()
    }
    
    // MARK: - 内部
    
    private func updateBackgroundViews() {
        if let path = config.backgroundImagePath {
            if let image = NSImage(contentsOfFile: path) {
                backgroundImageView?.layer?.contents = image
            }
            backgroundImageView?.isHidden = false
            vibrancyView?.isHidden = true
            colorOverlay?.layer?.backgroundColor = hexToNSColor(config.colorHex, alpha: 0.35)
        } else {
            backgroundImageView?.layer?.contents = nil
            backgroundImageView?.isHidden = true
            vibrancyView?.isHidden = false
            colorOverlay?.layer?.backgroundColor = hexToNSColor(config.colorHex, alpha: config.opacity)
        }
    }
    
    private func hexToNSColor(_ hex: String, alpha: Double) -> CGColor {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: Double
        switch hex.count {
        case 3:
            r = Double((int >> 8) * 17) / 255
            g = Double((int >> 4 & 0xF) * 17) / 255
            b = Double((int & 0xF) * 17) / 255
        case 6:
            r = Double(int >> 16) / 255
            g = Double((int >> 8) & 0xFF) / 255
            b = Double(int & 0xFF) / 255
        default:
            r = 0; g = 0; b = 0
        }
        return NSColor(srgbRed: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: CGFloat(alpha)).cgColor
    }
}
