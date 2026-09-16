//
//  KeyboardViewController.swift
//  KeyboardExtension
//
//  键盘扩展入口：UIInputViewController 子类，承载 SwiftUI 视图。
//  免费签名版：无 App Groups，配置由扩展自身 UserDefaults 管理。
//
//  ⚠️ viewDidLoad 中不做任何同步网络请求或大 IO（避免 watchdog 0x8badf00d）。
//  ⚠️ 不调用 UIApplication.shared.open()；不请求麦克风权限。
//

import UIKit
import SwiftUI

final class KeyboardViewController: UIInputViewController {

    // MARK: - Properties

    private let viewModel = KeyboardViewModel()
    private var hostingController: UIHostingController<KeyboardRootView>?
    private var heightConstraint: NSLayoutConstraint?

    private static let keyboardHeight: CGFloat = 280

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupSwiftUIHost()   // 只做轻量 UI 搭建，无同步 IO / 网络
        bindProxyActions()
        viewModel.loadInitialData()   // 本地 UserDefaults 读取，纳秒级
        refreshContext()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewModel.refreshFullAccess()
        refreshContext()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        viewModel.cancelPendingTask()
    }

    override func textWillChange(_ textInput: UITextInput?) { refreshContext() }
    override func textDidChange(_ textInput: UITextInput?)  { refreshContext() }
    override func selectionWillChange(_ sel: UITextInput?)  { refreshContext() }
    override func selectionDidChange(_ sel: UITextInput?)   { refreshContext() }

    // MARK: - Setup

    private func setupSwiftUIHost() {
        let rootView = KeyboardRootView(viewModel: viewModel)
        let host = UIHostingController(rootView: rootView)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        host.view.backgroundColor = .clear

        addChild(host)
        view.addSubview(host.view)
        host.didMove(toParent: self)

        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        hostingController = host

        // 固定键盘高度 280pt
        let constraint = view.heightAnchor.constraint(equalToConstant: Self.keyboardHeight)
        constraint.priority = .required
        constraint.isActive = true
        heightConstraint = constraint

        // hasFullAccess 真实值由宿主提供
        viewModel.hostFullAccessProvider = { [weak self] in
            self?.hasFullAccess ?? false
        }
    }

    private func bindProxyActions() {
        viewModel.onInsertText = { [weak self] text in
            self?.insertAndVerify(text)
        }
        viewModel.onReturnKey = { [weak self] in
            // 仅插入换行；生成结果永远由用户手动点击发送
            self?.textDocumentProxy.insertText("\n")
        }
        viewModel.onDeleteBackward = { [weak self] in
            self?.textDocumentProxy.deleteBackward()
        }
        viewModel.onAdvanceToNextKeyboard = { [weak self] in
            self?.advanceToNextInputMode()
        }
    }

    // MARK: - Context

    private func refreshContext() {
        let before = textDocumentProxy.documentContextBeforeInput ?? ""
        let after = textDocumentProxy.documentContextAfterInput ?? ""
        viewModel.updateInputContext(before: before, after: after)
    }

    // MARK: - 插入兼容处理

    /// insertText 在部分第三方 App（自定义输入框/富文本框）会静默失败。
    /// 策略：插入后校验光标前文本是否包含插入内容结尾；失败则把回复
    /// 复制到剪贴板，由 UI 提示用户手动粘贴。
    private func insertAndVerify(_ text: String) -> Bool {
        guard !text.isEmpty else { return false }

        let proxy = textDocumentProxy
        proxy.insertText(text)

        // 光标移到末尾（insertText 后光标自然在插入文本之后，再显式兜底）
        proxy.adjustCursor(forward: true, offset: Int.max)

        // 验证：取插入文本结尾 20 个字符，看光标前上下文是否包含
        let suffix = String(text.suffix(20))
        if let before = proxy.documentContextBeforeInput, before.contains(suffix) {
            return true
        }

        // 验证失败：兼容处理——复制到剪贴板，提示手动粘贴
        UIPasteboard.general.string = text
        return false
    }
}
