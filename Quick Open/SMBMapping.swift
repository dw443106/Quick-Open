import AppKit
import Combine
import Darwin
import ServiceManagement
import SwiftUI

struct SMBMountedVolume: Identifiable, Hashable {
    let remoteSource: String
    let mountPath: String
    let folders: [URL]

    var id: String { mountPath }
    var name: String { URL(fileURLWithPath: mountPath).lastPathComponent }
    var mountURL: URL { URL(fileURLWithPath: mountPath, isDirectory: true) }
}

struct SMBMappingRecord: Codable, Identifiable, Hashable {
    let id: UUID
    let remoteSource: String
    let volumeName: String
    let relativePath: String
    var sourcePath: String
    let localContainerPath: String
    let destinationPath: String
    let createdAt: Date

    init(
        id: UUID = UUID(),
        remoteSource: String,
        volumeName: String,
        relativePath: String,
        sourcePath: String,
        localContainerPath: String,
        destinationPath: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.remoteSource = remoteSource
        self.volumeName = volumeName
        self.relativePath = relativePath
        self.sourcePath = sourcePath
        self.localContainerPath = localContainerPath
        self.destinationPath = destinationPath
        self.createdAt = createdAt
    }
}

enum SMBMappingState {
    case active
    case sourceOffline
    case localConflict
    case missingLink

    var title: String {
        switch self {
        case .active: return "映射正常"
        case .sourceOffline: return "SMB 未连接"
        case .localConflict: return "本地路径被占用"
        case .missingLink: return "等待恢复"
        }
    }

    var color: Color {
        switch self {
        case .active: return .green
        case .sourceOffline: return .orange
        case .localConflict: return .red
        case .missingLink: return .secondary
        }
    }
}

@MainActor
final class SMBMappingManager: ObservableObject {
    static let shared = SMBMappingManager()

    private static let recordsKey = "SMBMappingRecords"
    private let fileManager = FileManager.default

    @Published private(set) var mountedVolumes: [SMBMountedVolume] = []
    @Published private(set) var mappings: [SMBMappingRecord] = []
    @Published private(set) var lastError: String?
    @Published private(set) var isRestoring = false

    var onNeedsAttention: ((String) -> Void)?

    private init() {
        loadMappings()
    }

    func refresh() {
        mountedVolumes = discoverMountedVolumes()
    }

    func folders(in volume: SMBMountedVolume) -> [URL] {
        volume.folders
    }

    func addMapping(sourceURL: URL, volume: SMBMountedVolume, localTargetURL: URL) throws {
        let sourcePath = sourceURL.standardizedFileURL.path
        let mountPath = volume.mountURL.standardizedFileURL.path
        guard sourcePath == mountPath || sourcePath.hasPrefix(mountPath + "/") else {
            throw SMBMappingError.invalidSource
        }

        let destinationURL = localTargetURL.standardizedFileURL
        guard !mountedVolumes.contains(where: {
            destinationURL.path == $0.mountPath || destinationURL.path.hasPrefix($0.mountPath + "/")
        }) else {
            throw SMBMappingError.invalidLocalTarget
        }
        let relativePath = String(sourcePath.dropFirst(mountPath.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        if itemExistsWithoutFollowingLink(atPath: destinationURL.path) {
            if isExpectedSymbolicLink(atPath: destinationURL.path, expectedSourcePath: sourcePath) {
                if !mappings.contains(where: { $0.destinationPath == destinationURL.path }) {
                    mappings.append(
                        SMBMappingRecord(
                            remoteSource: volume.remoteSource,
                            volumeName: volume.name,
                            relativePath: relativePath,
                            sourcePath: sourcePath,
                            localContainerPath: destinationURL.deletingLastPathComponent().path,
                            destinationPath: destinationURL.path
                        )
                    )
                    saveMappings()
                }
                try ensureLaunchAtLogin()
                return
            }

            var isDirectory: ObjCBool = false
            let isExistingDirectory = fileManager.fileExists(atPath: destinationURL.path, isDirectory: &isDirectory) && isDirectory.boolValue
            let isEmptyDirectory = isExistingDirectory
                && ((try? fileManager.contentsOfDirectory(atPath: destinationURL.path))?.isEmpty == true)
            guard isEmptyDirectory else {
                throw SMBMappingError.destinationOccupied(destinationURL.path)
            }
            try fileManager.removeItem(at: destinationURL)
        }

        try fileManager.createSymbolicLink(atPath: destinationURL.path, withDestinationPath: sourcePath)
        mappings.append(
            SMBMappingRecord(
                remoteSource: volume.remoteSource,
                volumeName: volume.name,
                relativePath: relativePath,
                sourcePath: sourcePath,
                localContainerPath: destinationURL.deletingLastPathComponent().path,
                destinationPath: destinationURL.path
            )
        )
        saveMappings()
        try ensureLaunchAtLogin()
        lastError = nil
    }

    func removeMapping(_ record: SMBMappingRecord) throws {
        if itemExistsWithoutFollowingLink(atPath: record.destinationPath) {
            guard isExpectedSymbolicLink(atPath: record.destinationPath, expectedSourcePath: record.sourcePath) else {
                mappings.removeAll { $0.id == record.id }
                saveMappings()
                throw SMBMappingError.linkChanged
            }
            try fileManager.removeItem(atPath: record.destinationPath)
        }
        mappings.removeAll { $0.id == record.id }
        saveMappings()
    }

    func state(for record: SMBMappingRecord) -> SMBMappingState {
        guard let volume = mountedVolume(for: record) else { return .sourceOffline }
        let expectedSource = sourceURL(for: record, on: volume).path
        guard itemExistsWithoutFollowingLink(atPath: record.destinationPath) else { return .missingLink }
        return isExpectedSymbolicLink(atPath: record.destinationPath, expectedSourcePath: expectedSource)
            ? .active
            : .localConflict
    }

    func restoreMappingsAtLogin() {
        guard !mappings.isEmpty else { return }
        isRestoring = true
        lastError = nil
        refresh()

        var unavailableSources = Set<String>()
        for index in mappings.indices {
            guard let volume = mountedVolume(for: mappings[index]) else {
                unavailableSources.insert(mappings[index].remoteSource)
                continue
            }
            do {
                try ensureMapping(at: index, on: volume)
            } catch {
                lastError = error.localizedDescription
            }
        }
        saveMappings()

        if unavailableSources.isEmpty {
            finishRestore()
            return
        }

        for remoteSource in unavailableSources {
            reconnect(remoteSource: remoteSource)
        }
        checkReconnectResult(attempt: 1, maximumAttempts: 5)
    }

    func retryNow() {
        restoreMappingsAtLogin()
    }

    func reveal(_ record: SMBMappingRecord) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: record.destinationPath)])
    }

    private func reconnect(remoteSource: String) {
        guard let url = smbURL(from: remoteSource) else { return }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        NSWorkspace.shared.open(url, configuration: configuration)
    }

    private func checkReconnectResult(attempt: Int, maximumAttempts: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            guard let self else { return }
            self.refresh()

            var pending = false
            for index in self.mappings.indices {
                guard let volume = self.mountedVolume(for: self.mappings[index]) else {
                    pending = true
                    continue
                }
                do {
                    try self.ensureMapping(at: index, on: volume)
                } catch {
                    self.lastError = error.localizedDescription
                }
            }
            self.saveMappings()

            if pending && attempt < maximumAttempts {
                self.checkReconnectResult(attempt: attempt + 1, maximumAttempts: maximumAttempts)
            } else {
                if pending {
                    self.lastError = "无法恢复一个或多个 SMB 映射。请在 Finder 中重新连接飞牛 NAS，然后点击“重新检测”。"
                }
                self.finishRestore()
            }
        }
    }

    private func finishRestore() {
        isRestoring = false
        if let lastError {
            onNeedsAttention?(lastError)
        }
    }

    private func ensureMapping(at index: Int, on volume: SMBMountedVolume) throws {
        let expectedSource = sourceURL(for: mappings[index], on: volume).path
        guard fileManager.fileExists(atPath: expectedSource) else {
            throw SMBMappingError.sourceMissing(expectedSource)
        }

        let destinationPath = mappings[index].destinationPath
        if itemExistsWithoutFollowingLink(atPath: destinationPath) {
            if isExpectedSymbolicLink(atPath: destinationPath, expectedSourcePath: expectedSource) {
                mappings[index].sourcePath = expectedSource
                return
            }
            if isSymbolicLink(atPath: destinationPath) {
                try fileManager.removeItem(atPath: destinationPath)
            } else {
                throw SMBMappingError.destinationOccupied(destinationPath)
            }
        }

        let containerPath = mappings[index].localContainerPath
        guard fileManager.fileExists(atPath: containerPath) else {
            throw SMBMappingError.localContainerMissing(containerPath)
        }
        try fileManager.createSymbolicLink(atPath: destinationPath, withDestinationPath: expectedSource)
        mappings[index].sourcePath = expectedSource
    }

    private func mountedVolume(for record: SMBMappingRecord) -> SMBMountedVolume? {
        mountedVolumes.first { $0.remoteSource == record.remoteSource }
            ?? mountedVolumes.first { $0.name == record.volumeName }
    }

    private func sourceURL(for record: SMBMappingRecord, on volume: SMBMountedVolume) -> URL {
        guard !record.relativePath.isEmpty else { return volume.mountURL }
        return volume.mountURL.appendingPathComponent(record.relativePath, isDirectory: true)
    }

    private func discoverMountedVolumes() -> [SMBMountedVolume] {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/sbin/mount")
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            lastError = "无法读取 SMB 挂载状态：\(error.localizedDescription)"
            return []
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return [] }

        return output
            .split(separator: "\n")
            .compactMap { parseMountLine(String($0)) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private func parseMountLine(_ line: String) -> SMBMountedVolume? {
        guard line.contains("(smbfs,"),
              let onRange = line.range(of: " on "),
              let typeRange = line.range(of: " (smbfs,") else {
            return nil
        }

        let source = String(line[..<onRange.lowerBound])
        let encodedMountPath = String(line[onRange.upperBound..<typeRange.lowerBound])
        let mountPath = decodeMountPath(encodedMountPath)
        let mountURL = URL(fileURLWithPath: mountPath, isDirectory: true)
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .isHiddenKey]
        let folders = (try? fileManager.contentsOfDirectory(
            at: mountURL,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        ))?
            .filter { url in
                let values = try? url.resourceValues(forKeys: keys)
                return values?.isDirectory == true && values?.isHidden != true
            }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
            ?? []

        return SMBMountedVolume(remoteSource: source, mountPath: mountPath, folders: folders)
    }

    private func decodeMountPath(_ path: String) -> String {
        path
            .replacingOccurrences(of: "\\040", with: " ")
            .replacingOccurrences(of: "\\011", with: "\t")
            .replacingOccurrences(of: "\\134", with: "\\")
    }

    private func smbURL(from remoteSource: String) -> URL? {
        guard remoteSource.hasPrefix("//") else { return nil }
        return URL(string: "smb:" + remoteSource)
    }

    private func isSymbolicLink(atPath path: String) -> Bool {
        var info = stat()
        guard lstat(path, &info) == 0 else { return false }
        return (info.st_mode & S_IFMT) == S_IFLNK
    }

    private func itemExistsWithoutFollowingLink(atPath path: String) -> Bool {
        var info = stat()
        return lstat(path, &info) == 0
    }

    private func isExpectedSymbolicLink(atPath path: String, expectedSourcePath: String) -> Bool {
        guard isSymbolicLink(atPath: path),
              let destination = try? fileManager.destinationOfSymbolicLink(atPath: path) else {
            return false
        }
        let resolvedDestination: String
        if destination.hasPrefix("/") {
            resolvedDestination = URL(fileURLWithPath: destination).standardizedFileURL.path
        } else {
            let parent = URL(fileURLWithPath: path).deletingLastPathComponent()
            resolvedDestination = parent.appendingPathComponent(destination).standardizedFileURL.path
        }
        return resolvedDestination == URL(fileURLWithPath: expectedSourcePath).standardizedFileURL.path
    }

    private func ensureLaunchAtLogin() throws {
        guard #available(macOS 13.0, *) else { return }
        if SMAppService.mainApp.status != .enabled {
            do {
                try SMAppService.mainApp.register()
            } catch {
                throw SMBMappingError.loginItemFailed(error.localizedDescription)
            }
        }
    }

    private func loadMappings() {
        guard let data = UserDefaults.standard.data(forKey: Self.recordsKey),
              let records = try? JSONDecoder().decode([SMBMappingRecord].self, from: data) else {
            mappings = []
            return
        }
        mappings = records
    }

    private func saveMappings() {
        guard let data = try? JSONEncoder().encode(mappings) else { return }
        UserDefaults.standard.set(data, forKey: Self.recordsKey)
    }
}

enum SMBMappingError: LocalizedError {
    case invalidSource
    case invalidLocalTarget
    case destinationOccupied(String)
    case sourceMissing(String)
    case localContainerMissing(String)
    case linkChanged
    case loginItemFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidSource:
            return "所选文件夹不在当前 SMB 挂载中。"
        case .invalidLocalTarget:
            return "本地映射位置不能位于 SMB 共享内部。"
        case .destinationOccupied(let path):
            return "本地目标已存在其他文件或文件夹，未做覆盖：\(path)"
        case .sourceMissing:
            return "NAS 文件夹当前不可访问。"
        case .localContainerMissing(let path):
            return "本地目标目录不存在：\(path)"
        case .linkChanged:
            return "映射记录已移除，但本地入口已被修改，因此没有删除它。"
        case .loginItemFailed(let reason):
            return "映射已创建，但无法开启登录自动恢复：\(reason)"
        }
    }
}

struct SMBMappingView: View {
    @ObservedObject var manager: SMBMappingManager
    let onClose: () -> Void

    @State private var expandedVolumes = Set<String>()
    @State private var presentedError: String?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    connectionSection
                    mappingSection
                }
                .padding(20)
            }
        }
        .frame(minWidth: 680, minHeight: 520)
        .onAppear {
            manager.refresh()
        }
        .alert("SMB 映射", isPresented: Binding(
            get: { presentedError != nil },
            set: { if !$0 { presentedError = nil } }
        )) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(presentedError ?? "")
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "externaldrive.connected.to.line.below")
                .foregroundColor(.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text("SMB 映射")
                    .font(.system(size: 17, weight: .semibold))
                Text("复用 Finder 当前登录状态，不保存 NAS 密码")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            if manager.isRestoring {
                ProgressView()
                    .controlSize(.small)
                Text("正在恢复")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Button("重新检测") {
                manager.retryNow()
            }
            .controlSize(.small)
            Button("关闭") { onClose() }
                .keyboardShortcut(.escape)
                .controlSize(.small)
        }
        .padding(16)
    }

    private var connectionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("当前 SMB 连接", systemImage: "network")
                .font(.headline)

            if manager.mountedVolumes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("没有检测到已连接的 SMB 共享", systemImage: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("请先在 Finder 中重新连接飞牛 NAS，再回到这里点击“重新检测”。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Button("打开 Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([])
                    }
                    .controlSize(.small)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary.opacity(0.5))
                .cornerRadius(10)
            } else {
                ForEach(manager.mountedVolumes) { volume in
                    volumeRow(volume)
                }
            }
        }
    }

    private func volumeRow(_ volume: SMBMountedVolume) -> some View {
        DisclosureGroup(isExpanded: Binding(
            get: { expandedVolumes.contains(volume.id) },
            set: { expanded in
                if expanded { expandedVolumes.insert(volume.id) }
                else { expandedVolumes.remove(volume.id) }
            }
        )) {
            VStack(spacing: 6) {
                HStack {
                    Button {
                        chooseLocalContainer(for: volume.mountURL, volume: volume)
                    } label: {
                        Label("映射整个“\(volume.name)”共享…", systemImage: "externaldrive.badge.plus")
                    }
                    .controlSize(.small)
                    Spacer()
                }
                .padding(.bottom, 4)

                if volume.folders.isEmpty {
                    Text("此共享根目录下没有可列出的文件夹")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 6)
                } else {
                    ForEach(volume.folders, id: \.path) { folder in
                        HStack {
                            Image(systemName: "folder.fill")
                                .foregroundColor(.blue)
                            Text(folder.lastPathComponent)
                                .lineLimit(1)
                            Spacer()
                            Button("映射此文件夹…") {
                                chooseLocalContainer(for: folder, volume: volume)
                            }
                            .controlSize(.small)
                        }
                        .padding(.leading, 8)
                        .padding(.vertical, 4)
                    }
                }
                HStack {
                    Spacer()
                    Button("浏览其他子文件夹…") {
                        chooseSourceFolder(in: volume)
                    }
                    .controlSize(.small)
                }
                .padding(.top, 4)
            }
            .padding(.top, 8)
        } label: {
            HStack {
                Label(volume.name, systemImage: "externaldrive.fill.badge.checkmark")
                Spacer()
                Text("已连接 · \(volume.folders.count) 个文件夹")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .cornerRadius(10)
    }

    private var mappingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("已配置映射", systemImage: "arrow.triangle.branch")
                .font(.headline)

            if manager.mappings.isEmpty {
                Text("尚未配置。请从上方选择 NAS 文件夹，再选择一个现有的空文件夹作为最终本地映射位置。")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.quaternary.opacity(0.5))
                    .cornerRadius(10)
            } else {
                ForEach(manager.mappings) { record in
                    mappingRow(record)
                }
            }

            if let error = manager.lastError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .padding(.top, 4)
            }
        }
    }

    private func mappingRow(_ record: SMBMappingRecord) -> some View {
        let state = manager.state(for: record)
        return HStack(spacing: 12) {
            Circle()
                .fill(state.color)
                .frame(width: 9, height: 9)
            VStack(alignment: .leading, spacing: 3) {
                Text(URL(fileURLWithPath: record.sourcePath).lastPathComponent)
                    .font(.system(size: 13, weight: .medium))
                Text("→ \(record.destinationPath)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            Text(state.title)
                .font(.caption)
                .foregroundColor(state.color)
            Button("显示") { manager.reveal(record) }
                .controlSize(.small)
            Button(role: .destructive) {
                do {
                    try manager.removeMapping(record)
                } catch {
                    presentedError = error.localizedDescription
                }
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("移除映射入口，不删除 NAS 文件")
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .cornerRadius(10)
    }

    private func chooseLocalContainer(for sourceURL: URL, volume: SMBMountedVolume) {
        let panel = NSOpenPanel()
        panel.title = "选择最终的本地映射文件夹"
        panel.message = "请选择一个现有的空文件夹作为“\(sourceURL.lastPathComponent)”的本地入口。含有内容的文件夹不会被覆盖。"
        panel.prompt = "映射到此文件夹"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser

        guard panel.runModal() == .OK, let localURL = panel.url else { return }
        do {
            try manager.addMapping(sourceURL: sourceURL, volume: volume, localTargetURL: localURL)
        } catch {
            presentedError = error.localizedDescription
        }
    }

    private func chooseSourceFolder(in volume: SMBMountedVolume) {
        let panel = NSOpenPanel()
        panel.title = "选择 NAS 文件夹"
        panel.message = "请选择“\(volume.name)”共享中的文件夹。"
        panel.prompt = "选择此 NAS 文件夹"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.directoryURL = volume.mountURL

        guard panel.runModal() == .OK, let sourceURL = panel.url else { return }
        let normalizedSource = sourceURL.standardizedFileURL.path
        let normalizedMount = volume.mountURL.standardizedFileURL.path
        guard normalizedSource == normalizedMount || normalizedSource.hasPrefix(normalizedMount + "/") else {
            presentedError = SMBMappingError.invalidSource.localizedDescription
            return
        }
        chooseLocalContainer(for: sourceURL, volume: volume)
    }
}

final class SMBMappingWindowController: NSWindowController {
    init(manager: SMBMappingManager) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "SMB 映射"
        window.center()
        window.contentView = NSHostingView(rootView: SMBMappingView(manager: manager, onClose: { window.close() }))
        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
