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
import QuartzCore

enum QuickOpenWindowBehaviorSettings {
    static let adaptiveIconsKey = "QuickOpenAdaptiveIconsEnabled"
    static let windowSnappingKey = "QuickOpenWindowSnappingEnabled"
    static let edgeAutoHideKey = "QuickOpenEdgeAutoHideEnabled"
    static let autoHideDelayKey = "QuickOpenAutoHideDelay"
    static let autoHideVisibleStripKey = "QuickOpenAutoHideVisibleStrip"
    static let autoHideLeftEdgeKey = "QuickOpenAutoHideLeftEdgeEnabled"
    static let autoHideRightEdgeKey = "QuickOpenAutoHideRightEdgeEnabled"
    static let autoHideTopEdgeKey = "QuickOpenAutoHideTopEdgeEnabled"
    static let autoHideBottomEdgeKey = "QuickOpenAutoHideBottomEdgeEnabled"
    static let animalTriggerEnabledKey = "QuickOpenAnimalTriggerEnabled"
    static let animalTriggerStyleKey = "QuickOpenAnimalTriggerStyle"
    static let animalTriggerSizeKey = "QuickOpenAnimalTriggerSize"
    static let changedNotification = Notification.Name("QuickOpenWindowBehaviorSettingsChanged")
    
    static var adaptiveIconsEnabled: Bool {
        UserDefaults.standard.object(forKey: adaptiveIconsKey) as? Bool ?? true
    }
    
    static var windowSnappingEnabled: Bool {
        UserDefaults.standard.object(forKey: windowSnappingKey) as? Bool ?? false
    }
    
    static var edgeAutoHideEnabled: Bool {
        UserDefaults.standard.object(forKey: edgeAutoHideKey) as? Bool ?? false
    }
    
    static var autoHideDelay: Double {
        UserDefaults.standard.object(forKey: autoHideDelayKey) as? Double ?? 0.8
    }
    
    static var autoHideVisibleStrip: CGFloat {
        let value = UserDefaults.standard.object(forKey: autoHideVisibleStripKey) as? Double ?? 8
        return CGFloat(value)
    }
    
    static var animalTriggerEnabled: Bool {
        UserDefaults.standard.object(forKey: animalTriggerEnabledKey) as? Bool ?? true
    }
    
    static var animalTriggerStyle: String {
        QuickOpenPetOption.normalizedStyle(UserDefaults.standard.string(forKey: animalTriggerStyleKey))
    }
    
    static var animalTriggerSize: CGFloat {
        let value = UserDefaults.standard.object(forKey: animalTriggerSizeKey) as? Double ?? 128
        return CGFloat(min(max(value, 96), 180))
    }
    
    static func isAutoHideEdgeEnabled(_ edge: WindowDockEdge) -> Bool {
        switch edge {
        case .left:
            return UserDefaults.standard.object(forKey: autoHideLeftEdgeKey) as? Bool ?? true
        case .right:
            return UserDefaults.standard.object(forKey: autoHideRightEdgeKey) as? Bool ?? true
        case .top:
            return UserDefaults.standard.object(forKey: autoHideTopEdgeKey) as? Bool ?? true
        case .bottom:
            return UserDefaults.standard.object(forKey: autoHideBottomEdgeKey) as? Bool ?? true
        case .none:
            return false
        }
    }
    
    static func notifyChanged() {
        NotificationCenter.default.post(name: changedNotification, object: nil)
    }
}

struct QuickOpenPetOption: Identifiable, Hashable {
    let id: String
    let title: String
    let assetName: String
    
    static let all: [QuickOpenPetOption] = [
        QuickOpenPetOption(id: "fox", title: "狐狸", assetName: "PeekingFox"),
        QuickOpenPetOption(id: "raccoon", title: "浣熊", assetName: "PeekingRaccoon"),
        QuickOpenPetOption(id: "bear", title: "小熊", assetName: "PeekingBear"),
        QuickOpenPetOption(id: "owl", title: "猫头鹰", assetName: "PeekingOwl"),
        QuickOpenPetOption(id: "kitten", title: "小猫", assetName: "PeekingKitten"),
        QuickOpenPetOption(id: "puppy", title: "小狗", assetName: "PeekingPuppy"),
        QuickOpenPetOption(id: "bunny", title: "兔子", assetName: "PeekingBunny"),
        QuickOpenPetOption(id: "panda", title: "熊猫", assetName: "PeekingPanda"),
        QuickOpenPetOption(id: "penguin", title: "企鹅", assetName: "PeekingPenguin"),
        QuickOpenPetOption(id: "hamster", title: "仓鼠", assetName: "PeekingHamster")
    ]
    
    static func normalizedStyle(_ style: String?) -> String {
        switch style {
        case "cat", "fox", nil:
            return "fox"
        case "dog", "raccoon":
            return "raccoon"
        case "bear":
            return "bear"
        case "owl":
            return "owl"
        case "kitten":
            return "kitten"
        case "puppy":
            return "puppy"
        case "bunny":
            return "bunny"
        case "panda":
            return "panda"
        case "penguin":
            return "penguin"
        case "hamster":
            return "hamster"
        default:
            return "fox"
        }
    }
    
    static func option(for style: String?) -> QuickOpenPetOption {
        let normalized = normalizedStyle(style)
        return all.first { $0.id == normalized } ?? all[0]
    }
    
    static func assetName(for style: String?) -> String {
        option(for: style).assetName
    }
}

enum RiceWindowKind {
    static let shortcuts = "shortcuts"
    static let aiDashboard = "aiDashboard"
}

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
    var animalTriggerStyle: String?
    var windowKind: String
    
    // 兼容旧保存数据：没有 titleColorHex 字段时使用白色
    init(id: UUID = UUID(), title: String, x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, colorHex: String, titleColorHex: String = "#FFFFFF", opacity: Double, appPaths: [String], backgroundImagePath: String? = nil, animalTriggerStyle: String? = nil, windowKind: String = RiceWindowKind.shortcuts) {
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
        self.animalTriggerStyle = animalTriggerStyle
        self.windowKind = windowKind
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
        animalTriggerStyle = try container.decodeIfPresent(String.self, forKey: .animalTriggerStyle)
        windowKind = try container.decodeIfPresent(String.self, forKey: .windowKind) ?? RiceWindowKind.shortcuts
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

private final class WeakRiceWindowController {
    weak var value: RiceWindowController?
    
    init(_ value: RiceWindowController) {
        self.value = value
    }
}

enum WindowDockEdge {
    case none
    case left
    case right
    case top
    case bottom
}

private enum PetImageCache {
    private static var croppedImages: [String: NSImage] = [:]
    
    static func image(named name: String) -> NSImage? {
        if let image = croppedImages[name] {
            return image
        }
        
        guard let sourceImage = NSImage(named: name),
              let cgImage = sourceImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return NSImage(named: name)
        }
        
        let rep = NSBitmapImageRep(cgImage: cgImage)
        var minX = rep.pixelsWide
        var minY = rep.pixelsHigh
        var maxX = 0
        var maxY = 0
        
        for y in 0..<rep.pixelsHigh {
            for x in 0..<rep.pixelsWide {
                guard (rep.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.04 else { continue }
                minX = min(minX, x)
                minY = min(minY, y)
                maxX = max(maxX, x)
                maxY = max(maxY, y)
            }
        }
        
        guard minX <= maxX, minY <= maxY else {
            croppedImages[name] = sourceImage
            return sourceImage
        }
        
        let padding = 2
        let cropX = max(minX - padding, 0)
        let cropY = max(minY - padding, 0)
        let cropMaxX = min(maxX + padding, rep.pixelsWide - 1)
        let cropMaxY = min(maxY + padding, rep.pixelsHigh - 1)
        let cropRect = CGRect(
            x: cropX,
            y: cropY,
            width: cropMaxX - cropX + 1,
            height: cropMaxY - cropY + 1
        )
        
        guard let croppedCGImage = cgImage.cropping(to: cropRect) else {
            croppedImages[name] = sourceImage
            return sourceImage
        }
        
        let croppedImage = NSImage(cgImage: croppedCGImage, size: NSSize(width: cropRect.width, height: cropRect.height))
        croppedImages[name] = croppedImage
        return croppedImage
    }
}

private struct AnimalTriggerView: View {
    let style: String
    let size: CGFloat
    let edge: WindowDockEdge
    let windowTitle: String
    let onHover: () -> Void
    
    private var imageName: String {
        QuickOpenPetOption.assetName(for: style)
    }
    
    private var panelSize: CGSize {
        switch edge {
        case .left, .right:
            return CGSize(width: size * 1.08, height: size * 1.08)
        case .top, .bottom:
            return CGSize(width: size * 1.25, height: size * 1.22)
        case .none:
            return CGSize(width: size * 0.72, height: size * 1.05)
        }
    }
    
    private var petSize: CGSize {
        CGSize(width: size * 0.84, height: size * 1.05)
    }
    
    private var displayTitle: String {
        let trimmed = windowTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "窗口" : trimmed
    }
    
    var body: some View {
        ZStack {
            switch edge {
            case .right:
                horizontalLayout(isRightEdge: true)
            case .left:
                horizontalLayout(isRightEdge: false)
            case .top:
                verticalLayout(signBelowPet: true)
            case .bottom:
                verticalLayout(signBelowPet: false)
            case .none:
                petImage
            }
        }
        .frame(width: panelSize.width, height: panelSize.height)
        .clipped()
        .contentShape(Rectangle())
        .onHover { hovering in
            if hovering {
                onHover()
            }
        }
    }
    
    private func horizontalLayout(isRightEdge: Bool) -> some View {
        ZStack(alignment: isRightEdge ? .trailing : .leading) {
            signView
                .frame(width: size * 0.60, height: size * 0.27)
                .offset(
                    x: isRightEdge ? -size * 0.26 : size * 0.26,
                    y: size * 0.36
                )
                .zIndex(0)
            
            petImage
                .frame(width: petSize.width, height: petSize.height)
                .offset(x: isRightEdge ? size * 0.11 : -size * 0.11)
                .scaleEffect(x: isRightEdge ? -1 : 1, y: 1, anchor: .center)
                .zIndex(1)
        }
        .frame(width: panelSize.width, height: panelSize.height)
    }
    
    private func verticalLayout(signBelowPet: Bool) -> some View {
        ZStack {
            petImage
                .frame(width: petSize.width, height: petSize.height)
                .offset(y: signBelowPet ? -size * 0.08 : size * 0.08)
                .zIndex(1)
            
            signView
                .frame(width: size * 0.78, height: size * 0.30)
                .offset(y: signBelowPet ? size * 0.42 : -size * 0.42)
                .zIndex(0)
        }
        .frame(width: panelSize.width, height: panelSize.height)
    }
    
    private var petImage: some View {
        Group {
            if let image = PetImageCache.image(named: imageName) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(imageName)
                    .resizable()
                    .scaledToFit()
            }
        }
    }
    
    private var signView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.055, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.96, green: 0.70, blue: 0.38),
                            Color(red: 0.82, green: 0.48, blue: 0.20)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.055, style: .continuous)
                        .stroke(Color(red: 0.55, green: 0.28, blue: 0.10), lineWidth: max(1, size * 0.018))
                )
                .shadow(color: .black.opacity(0.16), radius: size * 0.025, x: 0, y: size * 0.018)
            
            VStack(spacing: size * 0.045) {
                Capsule()
                    .fill(Color(red: 0.72, green: 0.38, blue: 0.14).opacity(0.45))
                    .frame(height: max(1, size * 0.012))
                Capsule()
                    .fill(Color(red: 0.72, green: 0.38, blue: 0.14).opacity(0.32))
                    .frame(height: max(1, size * 0.01))
            }
            .padding(.horizontal, size * 0.075)
            
            Text(displayTitle)
                .font(.system(size: size * 0.15, weight: .heavy, design: .rounded))
                .foregroundStyle(Color(red: 0.22, green: 0.12, blue: 0.05))
                .lineLimit(1)
                .minimumScaleFactor(0.46)
                .allowsTightening(true)
                .padding(.horizontal, size * 0.08)
                .shadow(color: .white.opacity(0.35), radius: 0, x: 0, y: 1)
        }
    }
}

class RiceWindowController: NSWindowController, ObservableObject {
    @Published var config: RiceWindowConfig {
        didSet {
            onConfigChanged?()
        }
    }
    
    var onConfigChanged: (() -> Void)?
    
    private static var controllerRegistry: [WeakRiceWindowController] = []
    private static let screenSnapThreshold: CGFloat = 18
    private static let windowSnapThreshold: CGFloat = 8
    
    static var defaultTransparentImagePath: String? {
        Bundle.main.path(forResource: "transparent_bg", ofType: "png")
    }
    
    private var vibrancyView: NSVisualEffectView?
    private var backgroundImageView: NSView?
    private var colorOverlay: NSView?
    private var hostingView: NSHostingView<AnyView>?
    private var isApplyingSnap = false
    private var isLiveResizing = false
    private var dockedEdge: WindowDockEdge = .none
    private var expandedFrameBeforeHide: NSRect?
    private var isEdgeHidden = false
    private var isEdgeTransitioning = false
    private var isMouseInside = false
    private var pendingHideWorkItem: DispatchWorkItem?
    private var animalTriggerPanel: NSPanel?
    
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
            selector: #selector(windowDidResize),
            name: NSWindow.didResizeNotification,
            object: window
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowWillStartLiveResize),
            name: NSWindow.willStartLiveResizeNotification,
            object: window
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidEndLiveResize),
            name: NSWindow.didEndLiveResizeNotification,
            object: window
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowBehaviorSettingsChanged),
            name: QuickOpenWindowBehaviorSettings.changedNotification,
            object: nil
        )
        
        Self.register(controller: self)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        animalTriggerPanel?.close()
        Self.unregister(controller: self)
    }
    
    @objc private func windowDidMove() {
        guard !isEdgeTransitioning else { return }
        if !isApplyingSnap && !isLiveResizing && QuickOpenWindowBehaviorSettings.windowSnappingEnabled {
            applySnappingIfNeeded()
        }
        refreshDockedEdge()
        scheduleAutoHideIfNeeded()
        updateConfigFromWindow()
    }
    
    @objc private func windowDidResize() {
        guard !isEdgeTransitioning else { return }
        refreshDockedEdge()
        scheduleAutoHideIfNeeded()
        updateConfigFromWindow()
    }
    
    @objc private func windowWillStartLiveResize() {
        isLiveResizing = true
        pendingHideWorkItem?.cancel()
    }
    
    @objc private func windowDidEndLiveResize() {
        isLiveResizing = false
        refreshDockedEdge()
        scheduleAutoHideIfNeeded()
        updateConfigFromWindow()
    }
    
    @objc private func windowBehaviorSettingsChanged() {
        guard !isEdgeTransitioning else { return }
        updateAnimalTriggerVisibility()
        if !QuickOpenWindowBehaviorSettings.edgeAutoHideEnabled {
            showFromEdgeIfNeeded()
        } else {
            refreshDockedEdge()
            scheduleAutoHideIfNeeded()
        }
    }
    
    private func updateConfigFromWindow() {
        guard let window = window else { return }
        let frame = isEdgeHidden ? (expandedFrameBeforeHide ?? window.frame) : window.frame
        var newConfig = config
        newConfig.x = frame.origin.x
        newConfig.y = frame.origin.y
        newConfig.width = frame.size.width
        newConfig.height = frame.size.height
        config = newConfig
    }
    
    private static func register(controller: RiceWindowController) {
        controllerRegistry = controllerRegistry.filter { $0.value != nil }
        controllerRegistry.append(WeakRiceWindowController(controller))
    }
    
    private static func unregister(controller: RiceWindowController) {
        controllerRegistry.removeAll { $0.value == nil || $0.value === controller }
    }
    
    private static var liveControllers: [RiceWindowController] {
        controllerRegistry.compactMap(\.value)
    }
    
    private func applySnappingIfNeeded() {
        guard let window = window else { return }
        let currentFrame = window.frame
        let snappedFrame = snappedFrame(for: currentFrame)
        
        guard snappedFrame.origin != currentFrame.origin else { return }
        
        isApplyingSnap = true
        window.setFrame(snappedFrame, display: true, animate: false)
        isApplyingSnap = false
    }
    
    private func snappedFrame(for frame: NSRect) -> NSRect {
        var snappedFrame = frame
        
        if let visibleFrame = activeScreen(for: frame)?.visibleFrame {
            snapHorizontalEdges(of: &snappedFrame, to: visibleFrame)
            snapVerticalEdges(of: &snappedFrame, to: visibleFrame)
        }
        
        for controller in Self.liveControllers {
            guard controller !== self,
                  let otherWindow = controller.window,
                  otherWindow.isVisible else {
                continue
            }
            
            let otherFrame = otherWindow.frame
            snapAdjacentWindowEdges(of: &snappedFrame, to: otherFrame)
        }
        
        return snappedFrame
    }
    
    private func activeScreen(for frame: NSRect) -> NSScreen? {
        if let currentScreen = window?.screen {
            return currentScreen
        }
        
        return NSScreen.screens
            .map { screen in
                (screen: screen, area: screen.visibleFrame.intersection(frame).width * screen.visibleFrame.intersection(frame).height)
            }
            .max { $0.area < $1.area }?
            .screen ?? NSScreen.main
    }
    
    private func snapHorizontalEdges(of frame: inout NSRect, to target: NSRect) {
        if abs(frame.minX - target.minX) <= Self.screenSnapThreshold {
            frame.origin.x = target.minX
        } else if abs(frame.maxX - target.maxX) <= Self.screenSnapThreshold {
            frame.origin.x = target.maxX - frame.width
        }
    }
    
    private func snapVerticalEdges(of frame: inout NSRect, to target: NSRect) {
        if abs(frame.minY - target.minY) <= Self.screenSnapThreshold {
            frame.origin.y = target.minY
        } else if abs(frame.maxY - target.maxY) <= Self.screenSnapThreshold {
            frame.origin.y = target.maxY - frame.height
        }
    }
    
    private func snapAdjacentWindowEdges(of frame: inout NSRect, to target: NSRect) {
        let horizontalOverlap = min(frame.maxX, target.maxX) - max(frame.minX, target.minX)
        let verticalOverlap = min(frame.maxY, target.maxY) - max(frame.minY, target.minY)
        
        if horizontalOverlap > 0 {
            if abs(frame.minY - target.maxY) <= Self.windowSnapThreshold {
                frame.origin.y = target.maxY
            } else if abs(frame.maxY - target.minY) <= Self.windowSnapThreshold {
                frame.origin.y = target.minY - frame.height
            }
        }
        
        if verticalOverlap > 0 {
            if abs(frame.minX - target.maxX) <= Self.windowSnapThreshold {
                frame.origin.x = target.maxX
            } else if abs(frame.maxX - target.minX) <= Self.windowSnapThreshold {
                frame.origin.x = target.minX - frame.width
            }
        }
    }
    
    private func refreshDockedEdge() {
        guard let window = window,
              let visibleFrame = activeScreen(for: window.frame)?.visibleFrame else {
            dockedEdge = .none
            return
        }
        
        let frame = window.frame
        if abs(frame.minX - visibleFrame.minX) <= Self.screenSnapThreshold {
            dockedEdge = .left
        } else if abs(frame.maxX - visibleFrame.maxX) <= Self.screenSnapThreshold {
            dockedEdge = .right
        } else if abs(frame.maxY - visibleFrame.maxY) <= Self.screenSnapThreshold {
            dockedEdge = .top
        } else if abs(frame.minY - visibleFrame.minY) <= Self.screenSnapThreshold {
            dockedEdge = .bottom
        } else {
            dockedEdge = .none
        }
    }
    
    private func scheduleAutoHideIfNeeded() {
        pendingHideWorkItem?.cancel()
        guard QuickOpenWindowBehaviorSettings.edgeAutoHideEnabled,
              dockedEdge != .none,
              QuickOpenWindowBehaviorSettings.isAutoHideEdgeEnabled(dockedEdge),
              !isEdgeHidden,
              !isEdgeTransitioning,
              !isMouseInside else {
            return
        }
        
        let workItem = DispatchWorkItem { [weak self] in
            self?.hideToEdgeIfNeeded()
        }
        pendingHideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + QuickOpenWindowBehaviorSettings.autoHideDelay, execute: workItem)
    }
    
    private func hideToEdgeIfNeeded() {
        guard QuickOpenWindowBehaviorSettings.edgeAutoHideEnabled,
              let window = window,
              dockedEdge != .none,
              QuickOpenWindowBehaviorSettings.isAutoHideEdgeEnabled(dockedEdge),
              !isEdgeTransitioning,
              let visibleFrame = activeScreen(for: window.frame)?.visibleFrame else {
            return
        }
        
        let currentFrame = window.frame
        expandedFrameBeforeHide = expandedFrame(for: currentFrame, visibleFrame: visibleFrame, edge: dockedEdge)
        let hiddenFrame = hiddenFrame(for: expandedFrameBeforeHide ?? currentFrame, visibleFrame: visibleFrame, edge: dockedEdge)
        
        guard hiddenFrame.origin != currentFrame.origin else { return }
        pendingHideWorkItem?.cancel()
        isEdgeTransitioning = true
        isEdgeHidden = true
        hideAnimalTrigger()
        setWindowFrame(hiddenFrame, animated: true) { [weak self] in
            guard let self = self else { return }
            self.isEdgeTransitioning = false
            if self.isEdgeHidden {
                self.showAnimalTrigger(for: hiddenFrame, visibleFrame: visibleFrame, edge: self.dockedEdge)
            }
        }
    }
    
    private func showFromEdgeIfNeeded() {
        guard let expandedFrame = expandedFrameBeforeHide,
              let window = window else {
            isEdgeHidden = false
            return
        }
        guard isEdgeHidden, !isEdgeTransitioning else { return }
        
        pendingHideWorkItem?.cancel()
        isEdgeTransitioning = true
        hideAnimalTrigger()
        window.makeKeyAndOrderFront(nil)
        setWindowFrame(expandedFrame, animated: true) { [weak self] in
            guard let self = self else { return }
            self.isEdgeHidden = false
            self.isEdgeTransitioning = false
            self.refreshDockedEdge()
            self.updateConfigFromWindow()
            self.scheduleAutoHideIfNeeded()
        }
    }
    
    private func expandedFrame(for frame: NSRect, visibleFrame: NSRect, edge: WindowDockEdge) -> NSRect {
        var expandedFrame = frame
        switch edge {
        case .left:
            expandedFrame.origin.x = visibleFrame.minX
        case .right:
            expandedFrame.origin.x = visibleFrame.maxX - frame.width
        case .top:
            expandedFrame.origin.y = visibleFrame.maxY - frame.height
        case .bottom:
            expandedFrame.origin.y = visibleFrame.minY
        case .none:
            break
        }
        return expandedFrame
    }
    
    private func hiddenFrame(for frame: NSRect, visibleFrame: NSRect, edge: WindowDockEdge) -> NSRect {
        var hiddenFrame = frame
        switch edge {
        case .left:
            hiddenFrame.origin.x = visibleFrame.minX - frame.width + QuickOpenWindowBehaviorSettings.autoHideVisibleStrip
        case .right:
            hiddenFrame.origin.x = visibleFrame.maxX - QuickOpenWindowBehaviorSettings.autoHideVisibleStrip
        case .top:
            hiddenFrame.origin.y = visibleFrame.maxY - QuickOpenWindowBehaviorSettings.autoHideVisibleStrip
        case .bottom:
            hiddenFrame.origin.y = visibleFrame.minY - frame.height + QuickOpenWindowBehaviorSettings.autoHideVisibleStrip
        case .none:
            break
        }
        return hiddenFrame
    }
    
    private func setWindowFrame(_ frame: NSRect, animated: Bool, completion: (() -> Void)? = nil) {
        guard let window = window else { return }
        isApplyingSnap = true
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.24
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                window.animator().setFrame(frame, display: true)
            } completionHandler: { [weak self] in
                self?.isApplyingSnap = false
                self?.updateConfigFromWindow()
                completion?()
            }
        } else {
            window.setFrame(frame, display: true, animate: false)
            isApplyingSnap = false
            updateConfigFromWindow()
            completion?()
        }
    }
    
    private func showAnimalTrigger(for hiddenFrame: NSRect, visibleFrame: NSRect, edge: WindowDockEdge) {
        guard QuickOpenWindowBehaviorSettings.animalTriggerEnabled else {
            hideAnimalTrigger()
            return
        }
        
        let size = QuickOpenWindowBehaviorSettings.animalTriggerSize
        let triggerSize = animalTriggerPanelSize(size: size, edge: edge)
        let panel = animalTriggerPanel ?? makeAnimalTriggerPanel(size: triggerSize)
        let frame = animalTriggerFrame(
            hiddenFrame: hiddenFrame,
            visibleFrame: visibleFrame,
            edge: edge,
            triggerSize: triggerSize
        )
        
        panel.contentView = NSHostingView(
            rootView: AnimalTriggerView(
                style: config.animalTriggerStyle ?? QuickOpenWindowBehaviorSettings.animalTriggerStyle,
                size: size,
                edge: edge,
                windowTitle: config.title,
                onHover: { [weak self] in
                    self?.showFromEdgeIfNeeded()
                }
            )
        )
        panel.setFrame(frame, display: true)
        panel.orderFront(nil)
        animalTriggerPanel = panel
    }
    
    private func hideAnimalTrigger() {
        animalTriggerPanel?.orderOut(nil)
    }
    
    private func updateAnimalTriggerVisibility() {
        guard isEdgeHidden,
              !isEdgeTransitioning,
              let window = window,
              let visibleFrame = activeScreen(for: window.frame)?.visibleFrame else {
            hideAnimalTrigger()
            return
        }
        
        showAnimalTrigger(for: window.frame, visibleFrame: visibleFrame, edge: dockedEdge)
    }
    
    private func makeAnimalTriggerPanel(size: CGSize) -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: size.width, height: size.height),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 2)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        return panel
    }
    
    private func animalTriggerPanelSize(size: CGFloat, edge: WindowDockEdge) -> CGSize {
        switch edge {
        case .left, .right:
            return CGSize(width: size * 1.08, height: size * 1.08)
        case .top, .bottom:
            return CGSize(width: size * 1.25, height: size * 1.22)
        case .none:
            return CGSize(width: size * 0.72, height: size * 1.05)
        }
    }
    
    private func animalTriggerFrame(hiddenFrame: NSRect, visibleFrame: NSRect, edge: WindowDockEdge, triggerSize: CGSize) -> NSRect {
        let inset: CGFloat = 2
        switch edge {
        case .left:
            return NSRect(
                x: visibleFrame.minX + inset,
                y: hiddenFrame.midY - triggerSize.height / 2,
                width: triggerSize.width,
                height: triggerSize.height
            )
        case .right:
            return NSRect(
                x: visibleFrame.maxX - triggerSize.width - inset,
                y: hiddenFrame.midY - triggerSize.height / 2,
                width: triggerSize.width,
                height: triggerSize.height
            )
        case .top:
            return NSRect(
                x: hiddenFrame.midX - triggerSize.width / 2,
                y: visibleFrame.maxY - triggerSize.height - inset,
                width: triggerSize.width,
                height: triggerSize.height
            )
        case .bottom:
            return NSRect(
                x: hiddenFrame.midX - triggerSize.width / 2,
                y: visibleFrame.minY + inset,
                width: triggerSize.width,
                height: triggerSize.height
            )
        case .none:
            return .zero
        }
    }
    
    override func mouseEntered(with event: NSEvent) {
        isMouseInside = true
        showFromEdgeIfNeeded()
    }
    
    override func mouseExited(with event: NSEvent) {
        isMouseInside = false
        refreshDockedEdge()
        scheduleAutoHideIfNeeded()
    }
    
    private func setupViews() {
        guard let window = window else { return }
        
        let bounds = window.contentView?.bounds ?? .zero
        
        let containerView = NSView(frame: bounds)
        containerView.autoresizingMask = [.width, .height]
        containerView.addTrackingArea(
            NSTrackingArea(
                rect: .zero,
                options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                owner: self,
                userInfo: nil
            )
        )
        
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
        let rootView = makeRootView()
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
    
    private func makeRootView() -> AnyView {
        if config.windowKind == RiceWindowKind.aiDashboard {
            return AnyView(AIDashboardWindowView(controller: self))
        }
        return AnyView(RiceWindowView(controller: self))
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
            hosting.rootView = makeRootView()
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
        updateAnimalTriggerVisibility()
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
            hosting.rootView = makeRootView()
        }
    }
    
    func updateAnimalTriggerStyle(_ style: String?) {
        var newConfig = config
        newConfig.animalTriggerStyle = style.map { QuickOpenPetOption.normalizedStyle($0) }
        config = newConfig
        updateAnimalTriggerVisibility()
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
