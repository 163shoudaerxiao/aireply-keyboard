# 从零到装上 iPhone · 完整操作手册（Windows + 免费 Apple ID，无需 Mac）

> **已选定的方案（自动决策）**：GitHub Actions macOS 云机器编译未签名 IPA
> → Windows 上 Sideloadly 免费签名 → iPhone 安装。
> 选它的理由：macOS 运行环境由 GitHub 免费提供（公开仓库），你本地零安装零配置；
> XcodeGen 在云端自动生成 Xcode 工程，你不需要碰任何 Mac 工具。
> 全程只有四样东西需要装在你电脑/手机上：GitHub 桌面端（或纯网页）、Sideloadly、iTunes（Sideloadly 依赖驱动）、本 IPA。

---

## 第 1 步 · 整理上传文件（10 分钟）

### 1.1 本地文件已就绪

`ai_reply_github_build/` 文件夹就是完整的 GitHub 仓库内容，结构如下（**只需上传这一个文件夹里的东西**）：

```
ai_reply_github_build/
├── .github/
│   └── workflows/
│       └── build.yml              ← 云端构建脚本
├── AIReplyShell/                  ← 宿主壳 App（把键盘带上 iPhone 用）
│   ├── AIReplyShellApp.swift
│   └── ContentView.swift
├── KeyboardExtension/             ← 键盘扩展全部源码
│   ├── KeyboardViewController.swift
│   ├── Info.plist
│   ├── Views/
│   │   ├── KeyboardRootView.swift
│   │   └── SettingsView.swift
│   ├── ViewModels/
│   │   └── KeyboardViewModel.swift
│   └── Services/
│       ├── AIService.swift
│       └── ConfigStore.swift
└── project.yml                    ← XcodeGen 工程定义（云端用它生成 .xcodeproj）
```

> ⚠️ 注意 `.github` 文件夹以点开头。资源管理器里直接可见，但拖拽上传时要确认它被一起传上去（构建脚本就住在里面）。

### 1.2 注册 GitHub 并创建仓库

1. 浏览器打开 `https://github.com` → Sign up 注册（免费）
2. 右上角 **+** → **New repository**
3. Repository name：`aireply-keyboard`；选 **Public**（必须选公开！私有仓库的 macOS 构建按 10 倍计费额度，免费额度很快耗尽）
4. 不勾任何初始化选项 → **Create repository**

### 1.3 上传文件（两种方式任选其一）

**方式 A：网页拖拽（最省事，推荐）**
1. 仓库页面点 **uploading an existing file**（或 Add file → Upload files）
2. 把 `ai_reply_github_build` 里的**全部内容**（含 `.github`、`AIReplyShell`、`KeyboardExtension` 文件夹和 `project.yml`）拖进浏览器窗口 —— 文件夹结构会自动保留
3. 确认文件列表里能看到 `.github/workflows/build.yml` 这一条
4. 底部 Commit changes 点 **Commit changes**

**方式 B：GitHub Desktop（文件多时更稳）**
1. 下载安装 GitHub Desktop（Windows 版）：`https://desktop.github.com`，登录你的 GitHub 账号
2. File → Add Local Repository → 选择 `ai_reply_github_build` 文件夹 → 提示"不是 git 仓库"时点 **create a repository here instead**（Name 填 `aireply-keyboard`，不勾私有）
3. 左侧勾选全部变更 → 填一句 `init` → **Commit to main** → 顶部 **Push origin**

---

## 第 2 步 · 触发云端构建（5 分钟）

1. 打开你的仓库页面 → 顶部 **Actions** 标签
2. 首次进入若提示 workflows are disabled → 点绿色按钮 **I understand my workflows, go ahead and enable them**
3. 左侧列表选 **Build unsigned IPA** → 右侧 **Run workflow** → **Run workflow** 按钮（push 上传后其实已自动触发一次，可不手动跑）
4. 构建中会出现一条黄色记录（约 3~5 分钟）：
   - 变 ✅ 绿色 → 成功，进入第 3 步
   - 变 ❌ 红色 → 跳到本手册第 7 步「编译失败排查」

---

## 第 3 步 · 下载未签名 IPA（1 分钟）

1. 点开那条绿色构建记录 → 页面底部 **Artifacts** 区域
2. 下载 **AIReplyShell-unsigned-ipa**（会得到一个 zip）
3. 解压 → 得到 **AIReplyShell-unsigned.ipa**，先放到桌面
4. （可选）同目录的 **build-log** 是完整构建日志，排查失败时用

---

## 第 4 步 · Windows 免费签名并安装（15 分钟）

### 4.1 装两个软件

1. **Sideloadly**：`https://sideloadly.io` → Download for Windows → 安装
2. **iTunes**（Sideloadly 需要 Apple 设备驱动）：`https://www.apple.com/itunes/download/win64/` → 安装后重启电脑

### 4.2 签名安装

1. iPhone 用数据线连电脑，手机上点「**信任**」（可能要求输入锁屏密码）
2. 打开 Sideloadly：
   - 把 `AIReplyShell-unsigned.ipa` 拖进左侧 IPA 区域
   - **Apple ID**：填你的免费 Apple ID（iCloud 账号邮箱）
   - 其他选项全部保持默认（**不要**勾任何 Advanced 里的选项）
3. 点 **Start** → 弹出密码框：
   - 若你的 Apple ID 开了双重认证（大概率开了）：先去 `https://appleid.apple.com` → 登录 → App 专用密码 → 生成密码 → 填这个专用密码
4. 等进度条走完（约 1~2 分钟），iPhone 上出现「AI Reply」图标

### 4.3 信任证书（首次必做）

手机：**设置 → 通用 → VPN 与设备管理** → 找到你的 Apple ID 那一行 → 点进去 → **信任**

---

## 第 5 步 · iPhone 上启用键盘并测试（10 分钟）

### 5.1 启用键盘 + 完全访问

1. 手机上打开「AI Reply」App 确认能启动（显示启用指引）
2. **设置 → 通用 → 键盘 → 键盘 → 添加新键盘** → 第三方键盘区点「**AI Reply**」
3. 点列表里的「AI Reply」→ 打开「**允许完全访问**」→ 弹窗点允许
   - 若开关打开后自动弹回：重启手机再试；还不行就重新连 Sideloadly 装一遍（免费签名偶发，重装宿主可解）
4. 打开微信/备忘录任意输入框 → 呼出键盘 → **长按 🌍** → 选「AI Reply」

### 5.2 配置 API Key

1. 点键盘面板中部风格条**最右侧的 ⚙️**
2. 粘贴 API Key（如 DeepSeek 的 `sk-...`）→ 平台选 DeepSeek → 点**完成**
3. 首次使用键盘状态区会显示「首次使用：点击右侧 ⚙️ 填写 API Key」，配好即消失

### 5.3 全流程测试

| # | 操作 | 预期 |
|---|---|---|
| 1 | 在微信复制一段消息 | 键盘顶部显示该消息（前 100 字） |
| 2 | 点「高情商」按钮 | 按钮转圈，状态区显示"正在生成回复…" |
| 3 | 等 3~15 秒 | 回复文本自动插入输入框，光标在文本末尾 |
| 4 | 你自己点微信的发送按钮 | 消息发出（键盘绝不自动发送） |
| 5 | 点 ⚙️ 修改某风格提示词 → 完成 → 再生成 | 回复风格按新提示词变化 |
| 6 | 底部 🌍 / 删除 / 空格 / 回车 | 分别为切键盘 / 删字 / 空格 / 换行 |

**异常对照**：
- 显示「请在系统设置中开启完全访问权限」→ 回到 5.1 第 3 步
- 显示「请先点击齿轮图标配置 API Key」→ 回到 5.2
- 一直转圈 → 检查手机网络；确认完全访问开着；等满 30 秒再看错误提示
- 提示「此输入框不支持直接插入，回复已复制到剪贴板」→ 长按输入框粘贴即可（个别 App 的兼容行为，属正常）

---

## 第 6 步 · 7 天过期续签（每 7 天约 5 分钟）

免费 Apple ID 签名有效期 **7 天**。过期表现：App 打不开、键盘从系统键盘列表消失。

**续签操作**：
1. 重新连数据线 → 打开 Sideloadly → 拖入**同一个 ipa** → 同一个 Apple ID → Start
2. 手机上重新信任证书（通常不用，同账号证书还在）
3. 重新去设置里开启「允许完全访问」
4. 打开键盘 ⚙️ 检查 API Key——**若被清空（重装可能清 UserDefaults），重新粘贴一次**；建议把 Key 平时记在备忘录里

**想省掉每周连电脑**：改用 **AltStore**（`https://altstore.io`）——Windows 上装 AltServer 后，手机装 AltStore，之后**同一 Wi-Fi 下手机会自动后台续签**，无需再连电脑。首次仍需连线装一次。

---

## 第 7 步 · 编译失败排查路径

### 7.1 看报错日志

1. Actions 页面 → 点那条**红色**构建记录 → 左侧点失败的 job（build）→ 展开红色的步骤（通常是 "归档构建"）
2. 在日志里找含 `error:` 的行（可用浏览器 Ctrl+F 搜 `error:`）
3. 同时下载 Artifacts 里的 **build-log** 看完整日志

### 7.2 把报错发给我让我改代码

复制以下三样内容发到对话里即可，我直接修：
1. 含 `error:` 的那几行日志（原样复制）
2. 你最后一次改动过的文件名（如果改过）
3. 构建编号（Actions 记录页 URL 里的 run number）

### 7.3 常见报错速查（自己就能处理的）

| 报错关键词 | 原因 | 处理 |
|---|---|---|
| `xcodegen: command not found` | brew 装失败 | 重跑构建（偶发网络抖动） |
| `No profile for team` / `signing` 相关 | 某处开了签名 | 不用管——本 workflow 全程 CODE_SIGNING_ALLOWED=NO；确认你没用修改过的 workflow |
| `Compiling failed` + 某文件行号 | Swift 代码问题 | 把日志发我 |
| `No such module` | 缺依赖 | 本项目无第三方依赖，出现即说明文件传漏了，核对第 1.1 步的文件清单 |
| Artifact 里没有 ipa | 打包步骤失败 | 下载 build-log 发我 |
| 仓库 Actions 标签是空的 | workflow 没传上去 | 确认 `.github/workflows/build.yml` 在仓库根目录 |

### 7.4 改完代码后重新构建

改了本地文件 → 用第 1.3 步同样的方式重新上传（GitHub Desktop 提交并 Push / 网页上 Add file 再传一次同名文件会覆盖）→ push 后 Actions 自动重新构建。

---

## 附：本方案的关键设计（供了解，无需操作）

- **未签名构建**：云端全程 `CODE_SIGNING_ALLOWED=NO`，产出未签名 IPA——这正是 Sideloadly 需要的输入形态，它用自己的免费证书机制签名，绕开了"必须有开发者账号才能出 ipa"的限制。
- **XcodeGen**：Windows 上无法生成 .xcodeproj（那是 Mac 专有格式），所以仓库里只放声明式的 `project.yml`，云端 macOS 机器上自动生成工程文件。
- **公开仓库**：GitHub 免费额度下 macOS 构建私有仓库按 10 倍计费，公开仓库完全免费——本仓库代码无密钥（API Key 只存在你手机上），公开无风险。
- **不依赖 App Groups**：键盘扩展配置全部存自己沙盒的 UserDefaults（`ai_reply_` 前缀键），已做空状态引导。
