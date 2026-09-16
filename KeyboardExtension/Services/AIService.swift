//
//  AIService.swift
//  KeyboardExtension
//
//  AI 调用服务：OpenAI 兼容 Chat Completion API。
//  仅用 URLSession（async/await），无第三方依赖，30s 超时，符合扩展内存预算。
//  ⚠️ 所有请求前强制检查 hasFullAccess，未开启直接抛错。
//

import Foundation

// MARK: - 错误定义

enum AIServiceError: LocalizedError {
    case noFullAccess
    case missingAPIKey
    case invalidURL
    case httpError(status: Int, message: String)
    case emptyResponse
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .noFullAccess:
            return "请在设置中开启完全访问权限"
        case .missingAPIKey:
            return "请先点击齿轮图标配置 API Key"
        case .invalidURL:
            return "API 地址无效"
        case .httpError(let status, let message):
            return "服务返回错误(\(status))：\(message)"
        case .emptyResponse:
            return "AI 未返回内容，请重试"
        case .decodingFailed:
            return "响应解析失败"
        }
    }
}

// MARK: - 请求/响应模型

private struct ChatCompletionRequest: Encodable {
    struct Message: Encodable {
        let role: String
        let content: String
    }
    let model: String
    let messages: [Message]
    let temperature: Double
}

private struct ChatCompletionResponse: Decodable {
    struct Choice: Decodable {
        struct Msg: Decodable { let content: String? }
        let message: Msg
    }
    struct APIError: Decodable {
        struct Detail: Decodable { let message: String? }
        let error: Detail?
    }
    let choices: [Choice]?
    let error: APIError?
}

// MARK: - 服务

final class AIService {

    private enum Const {
        static let timeout: TimeInterval = 30   // 需求要求 30s
    }

    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = Const.timeout
        config.timeoutIntervalForResource = Const.timeout
        config.waitsForConnectivity = false
        session = URLSession(configuration: config)
    }

    /// 生成回复
    /// - Parameters:
    ///   - apiKey / model / platform: 来自 ConfigStore 的配置
    ///   - stylePrompt: 风格提示词（system 角色）
    ///   - userText: 待回复的聊天上下文
    ///   - hasFullAccess: 宿主传入的完全访问状态（强制显式传入防止漏检）
    func generateReply(apiKey: String,
                       model: String,
                       platform: AIPlatform,
                       stylePrompt: String,
                       userText: String,
                       hasFullAccess: Bool) async throws -> String {

        // 1. 权限：无完全访问时 iOS 会静默拦截网络请求，必须提前给出提示
        guard hasFullAccess else { throw AIServiceError.noFullAccess }

        // 2. 配置检查（空状态处理）
        guard !apiKey.isEmpty else { throw AIServiceError.missingAPIKey }
        guard let url = URL(string: "\(platform.baseUrl)/chat/completions") else {
            throw AIServiceError.invalidURL
        }

        // 3. 组装 OpenAI 兼容请求体
        let body = ChatCompletionRequest(
            model: model,
            messages: [
                .init(role: "system", content: stylePrompt),
                .init(role: "user", content: userText.isEmpty ? "（对方未输入内容，请主动开启话题）" : userText),
            ],
            temperature: 0.8
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(body)

        // 4. 发起请求
        let (data, response) = try await session.data(for: request)

        // 5. HTTP 状态处理
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let apiMessage = (try? JSONDecoder().decode(ChatCompletionResponse.self, from: data))?
                .error?.error?.message ?? "请检查 API Key 与网络"
            throw AIServiceError.httpError(status: http.statusCode, message: apiMessage)
        }

        // 6. 解析
        guard let decoded = try? JSONDecoder().decode(ChatCompletionResponse.self, from: data) else {
            throw AIServiceError.decodingFailed
        }
        guard let content = decoded.choices?.first?.message.content, !content.isEmpty else {
            throw AIServiceError.emptyResponse
        }
        // 去掉部分模型爱加的引号包裹
        return content
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"“”"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 键盘收起时取消进行中的请求
    func cancelAll() {
        session.getAllTasks { tasks in tasks.forEach { $0.cancel() } }
    }
}
