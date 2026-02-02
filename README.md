# DoDo

macOS 原生应用，用于管理和组合命令行工具，让复杂的命令变得简单易用。

A native macOS app for managing and composing CLI tools with a graphical interface.

![macOS 14.0+](https://img.shields.io/badge/macOS-14.0%2B-blue)
![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange)
![License: MIT](https://img.shields.io/badge/License-MIT-green)

## 功能特性 / Features

**命令管理 / Command Management**
- 输入命令名自动解析 `--help` 生成图形化配置界面
- Auto-parse `--help` output to generate GUI forms for any CLI tool

**Pipeline 组合 / Pipeline Composition**
- 多命令串联，智能格式匹配，自动清理中间文件
- Chain multiple commands together with smart format matching and auto-cleanup

**快捷命令 / Quick Commands**
- 保存常用命令和 Pipeline 配置，支持一键执行
- Save frequently used commands/pipelines for one-click execution

**API 管理 / API Management**
- 可视化配置 REST API 端点，支持多种认证方式（API Key / Token / Bearer / 自定义）
- Visual REST API endpoint editor with multiple auth methods (API Key / Token / Bearer / Custom)

**API 组合 / API Pipeline**
- 多个 API 串联调用，支持变量提取和步骤间数据传递
- Chain multiple API calls with variable extraction and data passing between steps

**批量执行 / Batch Execution**
- 命令和 API 均支持批量输入并行执行
- Batch execution support for both CLI commands and API calls

**定时任务 / Scheduled Tasks**
- 快捷命令支持启动时执行和定时重复
- Quick commands can run on app launch or on a recurring schedule

**菜单栏 / Menu Bar**
- 常驻菜单栏，查看定时任务状态
- Persistent menu bar icon for monitoring scheduled tasks

## 技术栈 / Tech Stack

- **Swift 5.9** + **SwiftUI** + **SwiftData**
- macOS 14.0 (Sonoma) 以上 / macOS 14.0+ required
- Swift Package Manager
- 零外部依赖 / Zero external dependencies

## 构建运行 / Build & Run

```bash
# 编译 / Build
swift build -c release

# 复制到 App Bundle / Copy to App Bundle
cp .build/release/DoDo .build/DoDo.app/Contents/MacOS/

# 运行 / Run
open .build/DoDo.app

# 或一步打包 DMG / Or build DMG in one step
./scripts/build-dmg.sh
```

> 首次运行需先创建 App Bundle 目录：
> `mkdir -p .build/DoDo.app/Contents/MacOS`

## 自定义命令 / Custom Commands

内置了几个示例命令（curl、ffmpeg、convert）。你可以：

1. **在应用内添加** — 侧边栏点击 "+" 输入命令名，自动解析 `--help`
2. **通过配置文件** — 将 JSON 配置放到 iCloud 目录自动加载：
   `~/Library/Mobile Documents/com~apple~CloudDocs/DoDo/configs/`
3. **导入导出** — 应用内支持 JSON 格式的命令导入导出

Includes example commands (curl, ffmpeg, convert). You can:

1. **Add in-app** — Click "+" in the sidebar and enter a command name to auto-parse `--help`
2. **Via config files** — Place JSON configs in the iCloud directory for auto-loading:
   `~/Library/Mobile Documents/com~apple~CloudDocs/DoDo/configs/`
3. **Import/Export** — Import and export command configs as JSON within the app

### JSON 配置格式 / JSON Config Format

支持三种配置类型，通过 `type` 字段区分。

Three config types are supported, distinguished by the `type` field.

**命令配置 / Action Config** (无 type 字段 / no `type` field):

```json
{
  "name": "curl",
  "label": "HTTP 请求",
  "command": "curl",
  "commandMode": "pipe",
  "input": { "type": "url", "label": "URL", "allowMultiple": false, "placeholder": "https://..." },
  "output": { "flag": "-o", "label": "输出文件" },
  "options": [
    { "flag": "-s", "type": "bool", "label": "Silent mode" },
    { "flag": "-H", "type": "string", "label": "Header", "placeholder": "Content-Type: ..." },
    { "flag": "-vcodec", "type": "enum", "label": "Codec", "choices": ["libx264", "copy"], "default": "libx264" }
  ],
  "supportedInputFormats": ["url"],
  "supportedOutputFormats": [
    { "format": "json" },
    { "format": "pdf", "options": ["--pdf"] }
  ]
}
```

| 字段 / Field | 说明 / Description |
|---|---|
| `commandMode` | 可选。`"standard"`（默认）或 `"pipe"`（管道模式：`cat input \| cmd > output`）/ Optional. |
| `input.type` | `"file"` / `"url"` / `"string"` / `"directory"` |
| `options[].type` | `"bool"` / `"string"` / `"enum"` |
| `supportedInputFormats` | 可选。支持的输入格式列表 / Optional. Accepted input formats. |
| `supportedOutputFormats` | 可选。输出格式及对应选项 / Optional. Output formats with required flags. |

**组合命令 / Pipeline Config** (`type: "pipeline"`):

```json
{
  "name": "url2image",
  "label": "网页转图片",
  "type": "pipeline",
  "steps": ["wf", "docxjs"],
  "stepOptions": { "docxjs": ["--image"] },
  "cleanupIntermediates": true
}
```

**快捷命令 / Quick Command Config** (`type: "quickcommand"`):

```json
{
  "name": "息屏保活",
  "type": "quickcommand",
  "command": "caffeinate -s & pmset displaysleepnow",
  "runOnLaunch": false,
  "repeatInterval": null
}
```

| 字段 / Field | 说明 / Description |
|---|---|
| `runOnLaunch` | 可选。启动时自动执行 / Optional. Run on app launch. |
| `repeatInterval` | 可选。重复间隔秒数（如 3600=每小时）/ Optional. Repeat interval in seconds. |

## 项目结构 / Project Structure

```
DoDo/
├── Package.swift
├── Sources/DoDo/
│   ├── DoDoApp.swift                 # 应用入口 / App entry
│   ├── Models/
│   │   ├── Action.swift              # 命令模型 / Command model
│   │   ├── Pipeline.swift            # 组合模型 / Pipeline model
│   │   ├── QuickCommand.swift        # 快捷命令 / Quick command
│   │   ├── APIEndpoint.swift         # API 端点 / API endpoint
│   │   ├── APIPipeline.swift         # API 组合 / API pipeline
│   │   ├── BatchExecution.swift      # 批量执行 / Batch execution
│   │   └── Execution.swift           # 执行记录 / Execution record
│   ├── Services/
│   │   ├── CommandRunner.swift       # 命令执行 / Command runner
│   │   ├── PipelineRunner.swift      # Pipeline 执行 / Pipeline runner
│   │   ├── APIRunner.swift           # API 执行 / API runner
│   │   ├── BatchRunner.swift         # 批量执行 / Batch runner
│   │   ├── SchedulerService.swift    # 定时调度 / Task scheduler
│   │   ├── HelpParser.swift          # --help 解析 / Help parser
│   │   ├── BuiltInConfigs.swift      # 内置命令 / Built-in commands
│   │   ├── BuiltInPipelines.swift    # 内置组合 / Built-in pipelines
│   │   ├── ConfigLoader.swift        # 配置加载 / Config loader
│   │   ├── ConfigManager.swift       # 配置管理 / Config manager
│   │   └── PromptGenerator.swift     # 提示生成 / Prompt generator
│   └── Views/
│       ├── ContentView.swift         # 主视图 / Main view
│       ├── Sidebar/SidebarView.swift # 侧边栏 / Sidebar
│       ├── Main/                     # 详情视图 / Detail views
│       ├── API/                      # API 视图 / API views
│       ├── Common/                   # 通用组件 / Common components
│       ├── MenuBar/MenuBarView.swift # 菜单栏 / Menu bar
│       └── Import/ImportView.swift   # 导入视图 / Import view
├── Assets.xcassets/                  # 应用图标 / App icon
└── scripts/build-dmg.sh             # 打包脚本 / Build script
```

## License

[MIT](LICENSE)
