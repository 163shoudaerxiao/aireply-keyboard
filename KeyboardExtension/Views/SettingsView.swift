//
//  SettingsView.swift
//  KeyboardExtension
//
//  键盘内设置页（面板内覆盖层，非 modal——键盘扩展不能 present 视图控制器）。
//  功能：API Key 输入 / 平台选择 / 模型名 / 风格提示词编辑（可增删自定义风格）。
//  所有修改即时写入 UserDefaults.standard（ai_reply_ 前缀键）。
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: KeyboardViewModel

    @State private var apiKey: String = ""
    @State private var platform: AIPlatform = .deepseek
    @State private var model: String = ""
    @State private var showApiKey: Bool = false
    @State private var styles: [ReplyStyle] = []
    @State private var addStyleName: String = ""
    @State private var showAddStyle: Bool = false

    private let store = ConfigStore.shared

    var body: some View {
        VStack(spacing: 0) {
            // 顶部导航条
            HStack {
                Text("AI 键盘设置")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Button {
                    viewModel.closeSettings()
                } label: {
                    Text("完成")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)

            Divider()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    // ---- API Key ----
                    Group {
                        Text("API Key")
                            .sectionTitle()
                        HStack {
                            Group {
                                if showApiKey {
                                    TextField("sk-...", text: $apiKey)
                                } else {
                                    SecureField("sk-...", text: $apiKey)
                                }
                            }
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 13))
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)

                            Button {
                                showApiKey.toggle()
                            } label: {
                                Image(systemName: showApiKey ? "eye.slash" : "eye")
                                    .font(.system(size: 13))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // ---- 平台选择 ----
                    Group {
                        Text("AI 平台")
                            .sectionTitle()
                        Picker("平台", selection: $platform) {
                            ForEach(AIPlatform.allCases) { p in
                                Text(p.displayName).tag(p)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: platform) { newPlatform in
                            model = newPlatform.defaultModel
                            store.savePlatform(newPlatform)
                        }
                    }

                    // ---- 模型名 ----
                    Group {
                        Text("模型名")
                            .sectionTitle()
                        TextField(platform.defaultModel, text: $model)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 13))
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }

                    // ---- 风格编辑 ----
                    Group {
                        HStack {
                            Text("回复风格提示词")
                                .sectionTitle()
                            Spacer()
                            Button {
                                showAddStyle.toggle()
                            } label: {
                                Image(systemName: "plus.circle")
                                    .font(.system(size: 15))
                            }
                            .buttonStyle(.plain)
                        }

                        if showAddStyle {
                            HStack {
                                TextField("新风格名称", text: $addStyleName)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(size: 13))
                                Button("添加") {
                                    addCustomStyle()
                                }
                                .font(.system(size: 13, weight: .medium))
                                .disabled(addStyleName.trimmingCharacters(in: .whitespaces).isEmpty)
                                .buttonStyle(.plain)
                            }
                        }

                        ForEach($styles) { $style in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(style.name)
                                        .font(.system(size: 13, weight: .medium))
                                    if style.isBuiltin {
                                        Text("内置")
                                            .font(.system(size: 10))
                                            .foregroundColor(.secondary)
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 1)
                                            .background(Capsule().fill(Color(UIColor.systemGray5)))
                                    }
                                    Spacer()
                                    if !style.isBuiltin {
                                        Button {
                                            deleteStyle(style)
                                        } label: {
                                            Image(systemName: "trash")
                                                .font(.system(size: 12))
                                                .foregroundColor(.red)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                TextField("提示词模板", text: $style.prompt, axis: .vertical)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(size: 12))
                                    .lineLimit(2...4)
                                    .onChange(of: style.prompt) { _ in
                                        store.saveStyles(styles)   // 改动即写盘
                                    }
                            }
                            .padding(8)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color(UIColor.systemGray6)))
                        }
                    }

                    // ---- 数据丢失说明（免费签名 7 天重签场景）----
                    Text("提示：免费签名 7 天后需重新安装，届时配置会重置。重装后打开此页重新填写 API Key 即可。")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 10)
            }
        }
        .onAppear(perform: loadFromStore)
        .onDisappear { persistAll() }
    }

    // MARK: - 数据流

    private func loadFromStore() {
        let config = store.loadAIConfig()
        apiKey = config.apiKey
        platform = config.platform
        model = config.model
        styles = store.loadStyles()
    }

    /// 完成/离开时统一落盘
    private func persistAll() {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        store.saveAIConfig(AIConfig(
            apiKey: trimmed,
            platform: platform,
            model: model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? platform.defaultModel
                : model.trimmingCharacters(in: .whitespacesAndNewlines),
            autoSend: false   // 当前版本固定手动发送
        ))
        store.saveStyles(styles)
    }

    private func addCustomStyle() {
        let name = addStyleName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let newStyle = ReplyStyle(
            id: "custom_\(Int(Date().timeIntervalSince1970))",
            name: name,
            prompt: "请用「\(name)」的语气回复对方的消息，只输出回复内容本身。",
            isBuiltin: false
        )
        styles.append(newStyle)
        store.saveStyles(styles)
        addStyleName = ""
        showAddStyle = false
    }

    private func deleteStyle(_ style: ReplyStyle) {
        guard !style.isBuiltin else { return }
        styles.removeAll { $0.id == style.id }
        store.saveStyles(styles)
    }
}

private extension Text {
    func sectionTitle() -> some View {
        font(.system(size: 12, weight: .medium))
            .foregroundColor(.secondary)
    }
}
