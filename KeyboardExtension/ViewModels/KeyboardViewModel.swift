//
//  KeyboardViewModel.swift
//  KeyboardExtension
//
//  MVVM ViewModel：@MainActor ObservableObject。
//  数据来自本扩展自己的 ConfigStore（UserDefaults.standard，无 App Groups）。
//  UITextDocumentProxy 能力由 KeyboardViewController 通过闭包注入。
//

import Foundation
import UIKit

@MainActor
final class KeyboardViewModel: ObservableObject {

    // MARK: - Published State

    /// 顶部上下文（剪贴板优先，截断前 100 字符）
    @Published var contextText: String = ""
    @Published var styles: [ReplyStyle] = []
    /// 正在生成回复的风格 id
    @Published var loadingStyleId: String? = nil
    @Published var statusMessage: String? = nil
    @Published var hasFullAccess: Bool = false
    /// 是否显示设置页（面板内覆盖层）
    @Published var showSettings: Bool = false
    /// 首次使用 / 7 天重签后数据丢失的引导状态
    @Published var needsSetup: Bool = false
    /// insertText 失败时提示「已复制，请手动粘贴」
    @Published var pasteFallback: Bool = false

    // MARK: - 宿主注入

    /// 插入文本；返回值 = 是否验证插入成功（失败时宿主已把文本复制到剪贴板）
    var onInsertText: ((String) -> Bool)?
    var onReturnKey: (() -> Void)?
    var onDeleteBackward: (() -> Void)?
    var onAdvanceToNextKeyboard: (() -> Void)?

    /// 宿主提供 hasFullAccess 真实值
    var hostFullAccessProvider: (() -> Bool)?

    // MARK: - Private

    private let store = ConfigStore.shared
    private let aiService = AIService()
    private var config: AIConfig = .empty
    private var generateTask: Task<Void, Never>?
    private var latestInputContext: String = ""

    // MARK: - Lifecycle

    func loadInitialData() {
        config = store.loadAIConfig()
        styles = store.loadStyles()          // 空状态自动回填默认 6 种
        needsSetup = store.isConfigEmpty
    }

    func refreshFullAccess() {
        hasFullAccess = hostFullAccessProvider?() ?? false
    }

    func cancelPendingTask() {
        generateTask?.cancel()
        generateTask = nil
        aiService.cancelAll()
        loadingStyleId = nil
    }

    // MARK: - 上下文

    /// 输入框变化时由宿主回调
    func updateInputContext(before: String, after: String) {
        latestInputContext = before + after
        let source = latestInputContext.isEmpty ? Self.clipboardText() : latestInputContext
        contextText = Self.truncate(source, limit: 100)
    }

    /// 完全访问关闭时 UIPasteboard 静默返回空 → UI 层根据 contextText 空值给出提示
    private static func clipboardText() -> String {
        UIPasteboard.general.hasStrings ? (UIPasteboard.general.string ?? "") : ""
    }

    private static func truncate(_ text: String, limit: Int) -> String {
        guard text.count > limit else { return text }
        return String(text.prefix(limit)) + "…"
    }

    // MARK: - 键盘基础按键

    func advanceKeyboard() { onAdvanceToNextKeyboard?() }
    func deleteBackward() { onDeleteBackward?() }
    func insertSpace()    { onInsertText?(" ") }
    func tapReturn()      { onReturnKey?() }   // 回车仅插入换行，不触发 AI 发送

    // MARK: - 风格生成（手动发送模式：生成后只插入，不自动发送）

    func selectStyle(_ style: ReplyStyle) {
        guard loadingStyleId == nil else { return }

        // 1. 网络请求前必须检查 hasFullAccess
        guard let fullAccess = hostFullAccessProvider?(), fullAccess else {
            hasFullAccess = false
            statusMessage = "请在设置中开启完全访问权限"
            return
        }
        // 2. 空状态引导
        guard !config.apiKey.isEmpty else {
            needsSetup = true
            showSettings = true
            statusMessage = "请先配置 API Key"
            return
        }

        loadingStyleId = style.id
        statusMessage = nil
        pasteFallback = false

        let text = latestInputContext.isEmpty ? Self.clipboardText() : latestInputContext

        generateTask = Task { [weak self] in
            guard let self else { return }
            do {
                let reply = try await self.aiService.generateReply(
                    apiKey: self.config.apiKey,
                    model: self.config.model,
                    platform: self.config.platform,
                    stylePrompt: style.prompt,
                    userText: text,
                    hasFullAccess: fullAccess
                )
                guard !Task.isCancelled else { return }
                self.loadingStyleId = nil
                // 需求：不自动发送，仅插入，由用户手动点击发送
                self.handleGeneratedReply(reply)
            } catch {
                guard !Task.isCancelled else { return }
                self.loadingStyleId = nil
                self.statusMessage = error.localizedDescription
            }
        }
    }

    /// 生成完成：插入文本（含第三方 App 兼容处理），绝不自动发送
    private func handleGeneratedReply(_ reply: String) {
        // 宿主负责 insertText 并验证插入是否生效；
        // 失败时宿主已把回复复制到剪贴板，pasteFallback 置真提示用户手动粘贴
        insertionVerified = onInsertText?(reply) ?? false
    }

    /// 插入验证结果
    var insertionVerified: Bool = true {
        didSet {
            pasteFallback = !insertionVerified
        }
    }

    // MARK: - 设置页数据流

    func openSettings() { showSettings = true }

    func closeSettings() {
        // 关闭时重新读配置（用户可能在设置页改了 Key/模型）
        config = store.loadAIConfig()
        styles = store.loadStyles()
        needsSetup = store.isConfigEmpty
        showSettings = false
    }
}
