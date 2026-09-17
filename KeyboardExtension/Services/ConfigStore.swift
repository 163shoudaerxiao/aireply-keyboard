//
//  ConfigStore.swift
//  KeyboardExtension
//
//  配置存储（免费签名版）：不使用 App Groups / 主 App 共享，
//  全部数据存在键盘扩展自己的 UserDefaults.standard 中，键名统一 ai_reply_ 前缀。
//
//  ⚠️ 免费签名 7 天过期后重新安装，UserDefaults 数据会丢失——
//     所有读取路径都做了空状态处理：styles 为空时回填默认 6 种风格；
//     api_key 为空时 UI 显示首次配置引导。
//

import Foundation

// MARK: - 数据模型

enum AIPlatform: String, CaseIterable, Identifiable {
    case deepseek, qwen, kimi, hunyuan, doubao

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .deepseek: return "DeepSeek"
        case .qwen:     return "通义千问"
        case .kimi:     return "Kimi"
        case .hunyuan:  return "腾讯混元"
        case .doubao:   return "豆包"
        }
    }

    var baseUrl: String {
        switch self {
        case .deepseek: return "https://api.deepseek.com/v1"
        case .qwen:     return "https://dashscope.aliyuncs.com/compatible-mode/v1"
        case .kimi:     return "https://api.moonshot.cn/v1"
        case .hunyuan:  return "https://api.hunyuan.cloud.tencent.com/v1"
        case .doubao:   return "https://ark.cn-beijing.volces.com/api/v3"
        }
    }

    var defaultModel: String {
        switch self {
        case .deepseek: return "deepseek-chat"
        case .qwen:     return "qwen-plus"
        case .kimi:     return "moonshot-v1-8k"
        case .hunyuan:  return "hunyuan-turbo"
        case .doubao:   return "doubao-pro-32k"
        }
    }
}

/// 回复风格
struct ReplyStyle: Codable, Identifiable, Equatable {
    let id: String
    var name: String
    var isBuiltin: Bool
    var prompt: String
}

/// AI 配置快照
struct AIConfig {
    var apiKey: String
    var platform: AIPlatform
    var model: String
    var autoSend: Bool   // 保留字段：当前版本固定手动发送（见需求）

    static let empty = AIConfig(apiKey: "", platform: .deepseek, model: "deepseek-chat", autoSend: false)
}

// MARK: - 存储

final class ConfigStore {

    static let shared = ConfigStore()

    private let ud = UserDefaults.standard

    /// 与需求约定的键名
    private enum Keys {
        static let apiKey    = "ai_reply_api_key"
        static let platform  = "ai_reply_platform"
        static let model     = "ai_reply_model"
        static let autoSend  = "ai_reply_auto_send"
        static let styles    = "ai_reply_styles"
    }

    private init() {}

    // MARK: 首次使用 / 空状态

    /// API Key 为空视为未配置（7 天重签后即处于此状态）
    var isConfigEmpty: Bool {
        ud.string(forKey: Keys.apiKey)?.isEmpty ?? true
    }

    // MARK: AI 配置

    func loadAIConfig() -> AIConfig {
        let platformRaw = ud.string(forKey: Keys.platform) ?? AIPlatform.deepseek.rawValue
        let platform = AIPlatform(rawValue: platformRaw) ?? .deepseek
        return AIConfig(
            apiKey:   ud.string(forKey: Keys.apiKey) ?? "",
            platform: platform,
            model:    ud.string(forKey: Keys.model) ?? platform.defaultModel,
            autoSend: ud.bool(forKey: Keys.autoSend)
        )
    }

    func saveAIConfig(_ config: AIConfig) {
        ud.set(config.apiKey, forKey: Keys.apiKey)
        ud.set(config.platform.rawValue, forKey: Keys.platform)
        ud.set(config.model, forKey: Keys.model)
        ud.set(config.autoSend, forKey: Keys.autoSend)
    }

    func savePlatform(_ platform: AIPlatform) {
        ud.set(platform.rawValue, forKey: Keys.platform)
        // 切平台时若模型还是上一平台的默认值，则自动跟随
        let current = ud.string(forKey: Keys.model) ?? ""
        if AIPlatform.allCases.contains(where: { $0.defaultModel == current }) {
            ud.set(platform.defaultModel, forKey: Keys.model)
        }
    }

    // MARK: 风格

    /// 读取风格；空 / 解析失败 / 被清空 → 回填默认 6 种并写回（空状态处理核心）
    func loadStyles() -> [ReplyStyle] {
        if let data = ud.data(forKey: Keys.styles),
           let styles = try? JSONDecoder().decode([ReplyStyle].self, from: data),
           !styles.isEmpty {
            return styles
        }
        let defaults = Self.defaultStyles
        saveStyles(defaults)
        return defaults
    }

    func saveStyles(_ styles: [ReplyStyle]) {
        if let data = try? JSONEncoder().encode(styles) {
            ud.set(data, forKey: Keys.styles)
        }
    }

    // MARK: 默认 6 种风格

    static let defaultStyles: [ReplyStyle] = [
        ReplyStyle(id: "eq", name: "高情商", isBuiltin: true,
                   prompt: "你是高情商聊天助手。请用高情商的方式回复对方的消息：既照顾对方感受，又不卑不亢，自然得体，像情商很高的人在微信里聊天。只输出回复内容本身，不要任何解释。"),
        ReplyStyle(id: "humor", name: "幽默", isBuiltin: true,
                   prompt: "请用幽默风趣的语气回复消息，可以适度玩梗和调侃，但保持分寸、不冒犯对方。只输出回复内容本身，不要任何解释。"),
        ReplyStyle(id: "gentle", name: "温柔", isBuiltin: true,
                   prompt: "请用温柔体贴的语气回复消息，措辞柔和亲切，多关心对方的感受，像一位温暖的知心朋友。只输出回复内容本身，不要任何解释。"),
        ReplyStyle(id: "concise", name: "简洁", isBuiltin: true,
                   prompt: "请用最简洁的语言回复消息，直击要点，不超过两句话，不要客套、不要表情。只输出回复内容本身。"),
        ReplyStyle(id: "flirty", name: "暧昧", isBuiltin: true,
                   prompt: "请用略带暧昧、若有似无的语气回复消息，制造心动感和想象空间，但不过火、不油腻，像暧昧期的高手聊天。只输出回复内容本身，不要任何解释。"),
        ReplyStyle(id: "sharp", name: "毒舌", isBuiltin: true,
                   prompt: "请用犀利毒舌但无脏话的方式回复消息，一针见血、有梗有态度，让对方会心一笑而不觉得被冒犯。只输出回复内容本身，不要任何解释。"),
    ]
}
