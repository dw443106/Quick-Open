//
//  ContentView.swift
//  Quick Open
//
//  Created by mimi on 2026-05-19.
//

import SwiftUI
import AppKit

struct ContentView: View {
    @State private var searchText = ""
    @State private var filteredFiles: [URL] = []
    @State private var selectedIndex = 0
    @State private var isSearching = false
    @State private var lastSearchedText = ""

    var body: some View {
        VStack(spacing: 0) {
            // 搜索框
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 16))

                TextField("搜索文件、应用、文件夹...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16))
                    .onSubmit {
                        openSelectedFile()
                    }
                    .onChange(of: searchText) {
                        performSearch(searchText)
                    }

                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                        filteredFiles = []
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 16))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // 文件列表
            if isSearching {
                ProgressView()
                    .scaleEffect(0.8)
                    .padding()
            } else if filteredFiles.isEmpty && !searchText.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary.opacity(0.3))

                    Text("未找到匹配项")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredFiles.isEmpty && searchText.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary.opacity(0.3))

                    Text("输入关键词开始搜索")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(filteredFiles.enumerated()), id: \.offset) { index, url in
                            FileRowView(
                                url: url,
                                isSelected: index == selectedIndex,
                                onTap: {
                                    selectedIndex = index
                                    openFile(at: url)
                                }
                            )
                        }
                    }
                }
            }
        }
        .onAppear {
            setupKeyboardShortcuts()
        }
    }

    private func performSearch(_ text: String) {
        guard !text.isEmpty else {
            filteredFiles = []
            return
        }

        isSearching = true

        DispatchQueue.global(qos: .userInitiated).async {
            let files = searchFiles(keyword: text)

            DispatchQueue.main.async {
                self.filteredFiles = files
                self.isSearching = false
                self.selectedIndex = 0
            }
        }
    }

    private func searchFiles(keyword: String) -> [URL] {
        var results: [URL] = []

        // 搜索应用程序
        if let appsURL = URL(string: "/Applications") {
            results.append(contentsOf: searchDirectory(at: appsURL, keyword: keyword))
        }

        // 搜索用户应用程序
        if let userAppsURL = FileManager.default.urls(for: .applicationDirectory, in: .userDomainMask).first {
            results.append(contentsOf: searchDirectory(at: userAppsURL, keyword: keyword))
        }

        // 搜索桌面
        if let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first {
            results.append(contentsOf: searchDirectory(at: desktopURL, keyword: keyword))
        }

        // 搜索文档
        if let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            results.append(contentsOf: searchDirectory(at: documentsURL, keyword: keyword))
        }

        // 搜索下载
        if let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first {
            results.append(contentsOf: searchDirectory(at: downloadsURL, keyword: keyword))
        }

        // 按相关性和名称排序
        return results.sorted { url1, url2 in
            let name1 = url1.lastPathComponent.lowercased()
            let name2 = url2.lastPathComponent.lowercased()
            let keyword = keyword.lowercased()

            // 优先显示完全匹配
            if name1 == keyword && name2 != keyword { return true }
            if name2 == keyword && name1 != keyword { return false }

            // 优先显示开头匹配
            let startsWith1 = name1.hasPrefix(keyword)
            let startsWith2 = name2.hasPrefix(keyword)
            if startsWith1 && !startsWith2 { return true }
            if startsWith2 && !startsWith1 { return false }

            // 按名称排序
            return name1 < name2
        }
    }

    private func searchDirectory(at directory: URL, keyword: String) -> [URL] {
        var results: [URL] = []
        let keyword = keyword.lowercased()

        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey, .nameKey],
            options: [.skipsHiddenFiles]
        ) else {
            return results
        }

        for case let fileURL as URL in enumerator {
            do {
                let name = fileURL.lastPathComponent.lowercased()

                // 匹配文件名
                if name.contains(keyword) {
                    results.append(fileURL)
                }
            } catch {
                continue
            }

            // 限制结果数量，避免卡顿
            if results.count >= 50 {
                break
            }
        }

        return results
    }

    private func openFile(at url: URL) {
        let configuration = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.open(url, configuration: configuration) { app, error in
            if let error = error {
                print("Failed to open file: \(error.localizedDescription)")
            } else {
                // 打开成功，清空搜索
                DispatchQueue.main.async {
                    self.searchText = ""
                    self.filteredFiles = []
                }
            }
        }
    }

    private func openSelectedFile() {
        guard selectedIndex < filteredFiles.count else { return }
        openFile(at: filteredFiles[selectedIndex])
    }

    private func setupKeyboardShortcuts() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.modifierFlags.contains(.command) {
                switch event.keyCode {
                case 13: // Command + W 关闭窗口
                    NSApp.keyWindow?.close()
                default:
                    break
                }
            } else if event.keyCode == 125 { // 向下箭头
                if selectedIndex < filteredFiles.count - 1 {
                    selectedIndex += 1
                }
            } else if event.keyCode == 126 { // 向上箭头
                if selectedIndex > 0 {
                    selectedIndex -= 1
                }
            } else if event.keyCode == 36 { // 回车键
                openSelectedFile()
            } else if event.keyCode == 53 { // ESC键
                searchText = ""
                filteredFiles = []
            }

            return event
        }
    }
}

struct FileRowView: View {
    let url: URL
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // 图标
                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                    .resizable()
                    .frame(width: 32, height: 32)

                // 文件名和路径
                VStack(alignment: .leading, spacing: 4) {
                    Text(url.lastPathComponent)
                        .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    Text(url.deletingLastPathComponent().path)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "arrow.right.circle.fill")
                        .foregroundColor(.accentColor)
                        .font(.system(size: 16))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        }
        .buttonStyle(.plain)
    }
}
