//
//  AIDashboardWindowView.swift
//  Quick Open
//

import SwiftUI
import AppKit
import Security

enum QuickOpenAISettings {
    static let codexRemainingKey = "QuickOpenAICodexWeeklyRemaining"
    static let claudeRemainingKey = "QuickOpenAIClaudeWeeklyRemaining"
    static let codexRenewalDateKey = "QuickOpenAICodexRenewalDate"
    static let claudeRenewalDateKey = "QuickOpenAIClaudeRenewalDate"
    static let domesticProviderKey = "QuickOpenAIDomesticProvider"
    static let domesticTokenBalanceKey = "QuickOpenAIDomesticTokenBalance"
    
    static let domesticProviders = ["DeepSeek", "通义千问", "Kimi", "智谱 GLM", "豆包", "文心一言", "自定义"]
    
    static func double(for key: String, default defaultValue: Double) -> Double {
        UserDefaults.standard.object(forKey: key) as? Double ?? defaultValue
    }
    
    static func date(for key: String) -> Date {
        UserDefaults.standard.object(forKey: key) as? Date
        ?? Calendar.current.date(byAdding: .day, value: 7, to: Date())
        ?? Date()
    }
}

enum QuickOpenTokenBackupStore {
    private static let service = "QuickOpen.LocalAITokenBackup"
    
    static func hasToken(for provider: String) -> Bool {
        var query = baseQuery(provider: provider)
        query[kSecReturnData as String] = false
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        return SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess
    }
    
    static func save(_ token: String, for provider: String) -> Bool {
        guard let data = token.data(using: .utf8) else { return false }
        delete(provider: provider)
        var query = baseQuery(provider: provider)
        query[kSecValueData as String] = data
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }
    
    static func delete(provider: String) {
        SecItemDelete(baseQuery(provider: provider) as CFDictionary)
    }
    
    private static func baseQuery(provider: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: provider
        ]
    }
}

struct AIDashboardWindowView: View {
    @ObservedObject var controller: RiceWindowController
    
    @State private var isEditing = false
    @State private var codexRemaining = QuickOpenAISettings.double(for: QuickOpenAISettings.codexRemainingKey, default: 100)
    @State private var claudeRemaining = QuickOpenAISettings.double(for: QuickOpenAISettings.claudeRemainingKey, default: 100)
    @State private var codexRenewalDate = QuickOpenAISettings.date(for: QuickOpenAISettings.codexRenewalDateKey)
    @State private var claudeRenewalDate = QuickOpenAISettings.date(for: QuickOpenAISettings.claudeRenewalDateKey)
    @State private var domesticProvider = UserDefaults.standard.string(forKey: QuickOpenAISettings.domesticProviderKey) ?? QuickOpenAISettings.domesticProviders[0]
    @State private var domesticTokenBalance = UserDefaults.standard.string(forKey: QuickOpenAISettings.domesticTokenBalanceKey) ?? ""
    @State private var domesticTokenInput = ""
    @State private var domesticTokenSaved = false
    
    var body: some View {
        VStack(spacing: 0) {
            header
            
            if isEditing {
                editorPanel
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            Divider().opacity(0.3)
            
            ScrollView {
                VStack(spacing: 10) {
                    quotaTile(title: "Codex", remaining: codexRemaining, renewalDate: codexRenewalDate)
                    quotaTile(title: "Claude Code", remaining: claudeRemaining, renewalDate: claudeRenewalDate)
                    domesticTile
                }
                .padding(10)
            }
        }
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.15), lineWidth: 1))
        .onAppear {
            reloadTokenState()
        }
    }
    
    private var header: some View {
        ZStack {
            Text(controller.config.title)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Color(hex: controller.config.titleColorHex))
                .frame(maxWidth: .infinity, alignment: .center)
            
            HStack {
                Spacer()
                Button(action: { withAnimation { isEditing.toggle() } }) {
                    Image(systemName: isEditing ? "checkmark.circle.fill" : "gearshape.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
    
    private var editorPanel: some View {
        VStack(spacing: 10) {
            quotaEditor(
                title: "Codex",
                remaining: $codexRemaining,
                renewalDate: $codexRenewalDate,
                remainingKey: QuickOpenAISettings.codexRemainingKey,
                dateKey: QuickOpenAISettings.codexRenewalDateKey
            )
            
            Divider().opacity(0.35)
            
            quotaEditor(
                title: "Claude Code",
                remaining: $claudeRemaining,
                renewalDate: $claudeRenewalDate,
                remainingKey: QuickOpenAISettings.claudeRemainingKey,
                dateKey: QuickOpenAISettings.claudeRenewalDateKey
            )
            
            Divider().opacity(0.35)
            domesticEditor
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
    
    private func quotaTile(title: String, remaining: Double, renewalDate: Date) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Text("\(Int(remaining))%")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(quotaColor(remaining))
            }
            ProgressView(value: remaining, total: 100)
                .tint(quotaColor(remaining))
            Text(renewalText(for: renewalDate))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(10)
        .background(Color.primary.opacity(0.055))
        .cornerRadius(8)
    }
    
    private var domesticTile: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(domesticProvider)
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Text(domesticTokenSaved ? "Token 已备份" : "Token 未备份")
                    .font(.caption)
                    .foregroundColor(domesticTokenSaved ? .green : .secondary)
            }
            Text(domesticTokenBalance.isEmpty ? "未记录余额" : domesticTokenBalance)
                .font(.system(size: 13))
                .foregroundColor(domesticTokenBalance.isEmpty ? .secondary : .primary)
        }
        .padding(10)
        .background(Color.primary.opacity(0.055))
        .cornerRadius(8)
    }
    
    private func quotaEditor(
        title: String,
        remaining: Binding<Double>,
        renewalDate: Binding<Date>,
        remainingKey: String,
        dateKey: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(Int(remaining.wrappedValue))%")
                    .font(.caption.monospacedDigit())
                    .foregroundColor(quotaColor(remaining.wrappedValue))
            }
            Slider(value: remaining, in: 0...100, step: 1)
                .controlSize(.small)
                .onChange(of: remaining.wrappedValue) {
                    UserDefaults.standard.set(remaining.wrappedValue, forKey: remainingKey)
                }
            DatePicker("续费日", selection: renewalDate, displayedComponents: .date)
                .font(.caption)
                .controlSize(.small)
                .onChange(of: renewalDate.wrappedValue) {
                    UserDefaults.standard.set(renewalDate.wrappedValue, forKey: dateKey)
                }
        }
    }
    
    private var domesticEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("国内模型")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Picker("", selection: $domesticProvider) {
                    ForEach(QuickOpenAISettings.domesticProviders, id: \.self) { provider in
                        Text(provider).tag(provider)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: domesticProvider) {
                    UserDefaults.standard.set(domesticProvider, forKey: QuickOpenAISettings.domesticProviderKey)
                    domesticTokenInput = ""
                    reloadTokenState()
                }
            }
            
            HStack {
                SecureField("Token 备份到本机 Keychain", text: $domesticTokenInput)
                    .textFieldStyle(.roundedBorder)
                Button("保存") {
                    saveDomesticToken()
                }
                .controlSize(.small)
                .disabled(domesticTokenInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Button("删除") {
                    QuickOpenTokenBackupStore.delete(provider: domesticProvider)
                    domesticTokenInput = ""
                    domesticTokenSaved = false
                }
                .controlSize(.small)
                .disabled(!domesticTokenSaved)
            }
            
            TextField("余额，例如 120 万 token / ¥38.50", text: $domesticTokenBalance)
                .textFieldStyle(.roundedBorder)
                .onChange(of: domesticTokenBalance) {
                    UserDefaults.standard.set(domesticTokenBalance, forKey: QuickOpenAISettings.domesticTokenBalanceKey)
                }
        }
    }
    
    private func reloadTokenState() {
        domesticTokenSaved = QuickOpenTokenBackupStore.hasToken(for: domesticProvider)
    }
    
    private func saveDomesticToken() {
        let token = domesticTokenInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else { return }
        domesticTokenSaved = QuickOpenTokenBackupStore.save(token, for: domesticProvider)
        if domesticTokenSaved {
            domesticTokenInput = ""
        }
    }
    
    private func quotaColor(_ value: Double) -> Color {
        if value < 20 {
            return .red
        } else if value < 50 {
            return .orange
        }
        return .green
    }
    
    private func renewalText(for date: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: Calendar.current.startOfDay(for: date)).day ?? 0
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy-MM-dd"
        if days < 0 {
            return "续费日期已过：\(formatter.string(from: date))"
        } else if days == 0 {
            return "今天续费：\(formatter.string(from: date))"
        } else {
            return "\(days) 天后续费：\(formatter.string(from: date))"
        }
    }
}
