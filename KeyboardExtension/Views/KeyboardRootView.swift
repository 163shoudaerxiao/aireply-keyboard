//
//  KeyboardRootView.swift
//  KeyboardExtension
//
//  键盘 SwiftUI 主视图，三段式布局：
//  ┌───────────────────────────────────┐
//  │ 顶部：聊天上下文（前 100 字符）        │
//  ├───────────────────────────────────┤
//  │ 中部：风格按钮横向滚动（最右侧 ⚙️ 设置）│
//  │       + 状态/结果提示                │
//  ├───────────────────────────────────┤
//  │ 底部：🌍 | 删除 | 空格 | 回车         │
//  └───────────────────────────────────┘
//  点击 ⚙️ 时整面板切换为 SettingsView 覆盖层。
//

import SwiftUI

struct KeyboardRootView: View {

    @ObservedObject var viewModel: KeyboardViewModel

    private let panelBackground = Color(UIColor.systemGray6)

    var body: some View {
        ZStack {
            panelBackground

            if viewModel.showSettings {
                SettingsView(viewModel: viewModel)
            } else {
                mainPanel
            }
        }
    }

    // MARK: 主面板

    private var mainPanel: some View {
        VStack(spacing: 6) {
            // 1. 顶部：聊天上下文条
            ContextBarView(viewModel: viewModel)
                .padding(.horizontal, 8)
                .padding(.top, 6)

            // 2. 中部：风格按钮横向滚动（末尾带齿轮设置入口）
            StyleScrollView(viewModel: viewModel)
                .padding(.horizontal, 8)

            // 3. 状态提示区
            StatusView(viewModel: viewModel)
                .frame(minHeight: 34)
                .padding(.horizontal, 8)

            // 4. 底部功能键行
            BottomKeyRow(viewModel: viewModel)
                .padding(.horizontal, 4)
                .padding(.bottom, 4)
        }
    }
}

// MARK: - 顶部：上下文条

private struct ContextBarView: View {
    @ObservedObject var viewModel: KeyboardViewModel

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "text.bubble")
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            if viewModel.contextText.isEmpty {
                Text(viewModel.hasFullAccess
                     ? "复制一段聊天内容后回到这里，AI 帮你回复"
                     : "完全访问未开启：无法读取剪贴板，请在设置中开启")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            } else {
                Text(viewModel.contextText)
                    .font(.system(size: 12))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(UIColor.systemGray5))
        .cornerRadius(8)
    }
}

// MARK: - 中部：风格滚动区 + 齿轮设置入口

private struct StyleScrollView: View {
    @ObservedObject var viewModel: KeyboardViewModel

    var body: some View {
        HStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(viewModel.styles) { style in
                        StyleButton(
                            style: style,
                            isLoading: viewModel.loadingStyleId == style.id,
                            disabled: viewModel.loadingStyleId != nil
                        ) {
                            viewModel.selectStyle(style)
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            // 设置入口（齿轮）
            Button {
                viewModel.openSettings()
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .frame(width: 34, height: 34)
            }
            .background(Circle().fill(Color(UIColor.systemGray5)))
            .buttonStyle(.plain)
        }
    }
}

private struct StyleButton: View {
    let style: ReplyStyle
    let isLoading: Bool
    let disabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                        .frame(width: 14, height: 14)
                }
                Text(style.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule().fill(Color(UIColor.systemGray4).opacity(isLoading ? 0.6 : 1))
            )
        }
        .disabled(disabled)
        .buttonStyle(.plain)
    }
}

// MARK: - 状态提示区

private struct StatusView: View {
    @ObservedObject var viewModel: KeyboardViewModel

    var body: some View {
        Group {
            if !viewModel.hasFullAccess {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("请在系统设置中开启完全访问权限，否则无法联网和读取剪贴板")
                        .font(.system(size: 12))
                        .lineLimit(2)
                }
            } else if viewModel.pasteFallback {
                Text("此输入框不支持直接插入，回复已复制到剪贴板，请长按输入框粘贴")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.orange)
                    .lineLimit(2)
            } else if let message = viewModel.statusMessage {
                Text(message)
                    .font(.system(size: 12))
                    .foregroundColor(.red)
                    .lineLimit(2)
            } else if viewModel.needsSetup {
                Text("首次使用：点击右侧 ⚙️ 填写 API Key 即可开始")
                    .font(.system(size: 12))
                    .foregroundColor(.blue)
            } else if viewModel.loadingStyleId != nil {
                Text("正在生成回复…")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            } else {
                Text("点风格按钮生成回复 → 插入后手动发送")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 底部功能键行

private struct BottomKeyRow: View {
    @ObservedObject var viewModel: KeyboardViewModel

    var body: some View {
        HStack(spacing: 5) {
            KeyButton(icon: "globe") { viewModel.advanceKeyboard() }
                .frame(width: 44)

            KeyButton(icon: "delete.left") { viewModel.deleteBackward() }
                .frame(width: 44)

            Button {
                viewModel.insertSpace()
            } label: {
                Text("空格")
                    .font(.system(size: 15))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(Color(UIColor.systemGray5))
            .cornerRadius(6)
            .buttonStyle(.plain)

            Button {
                viewModel.tapReturn()
            } label: {
                Text("回车")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)
                    .frame(width: 56)
                    .frame(maxHeight: .infinity)
            }
            .background(Color(UIColor.systemGray5))
            .cornerRadius(6)
            .buttonStyle(.plain)
        }
        .frame(height: 44)
    }
}

private struct KeyButton: View {
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 17))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(UIColor.systemGray5))
        .cornerRadius(6)
        .buttonStyle(.plain)
    }
}
