//
//  ContentView.swift
//  AIReplyShell
//
//  壳 App 首页：显示启用键盘的分步指引（键盘扩展不能调用
//  UIApplication.shared.open()，所以引导只靠文字）。
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("AI 回复键盘已安装 ✅")
                .font(.title2.bold())

            VStack(alignment: .leading, spacing: 12) {
                Label("打开 iPhone「设置 → 通用 → 键盘 → 键盘 → 添加新键盘」", systemImage: "1.circle")
                Label("在第三方键盘列表选择「AI Reply」", systemImage: "2.circle")
                Label("点击「AI Reply → 允许完全访问」并开启开关", systemImage: "3.circle")
                Label("任意输入框长按 🌍 切换到 AI Reply，点 ⚙️ 填入 API Key", systemImage: "4.circle")
            }
            .font(.system(size: 14))

            Text("配置（API Key / 平台 / 风格）全部在键盘内部的 ⚙️ 设置里完成，本 App 只负责安装。")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

#Preview {
    ContentView()
}
