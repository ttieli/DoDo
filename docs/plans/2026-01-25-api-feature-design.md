# API 请求和响应功能设计

## 概述

为 DoDo 添加 API 请求和响应功能，支持 API 组合（数据链式传递）和智能响应显示（JSON/表格双视图）。

## 核心功能

### 1. API 配置（APIEndpoint 模型）

```swift
@Model
final class APIEndpoint {
    var id: UUID
    var name: String
    var url: String
    var method: String          // GET, POST, PUT, DELETE
    var headers: [String: String]
    var bodyTemplate: String?   // 支持 {{variable}} 占位符

    // 认证配置
    var authType: String        // none, apiKey, token, custom
    var authConfig: [String: String]  // key, secret, algorithm 等

    // 输出提取配置（用于组合）
    var outputExtractions: [OutputExtraction]  // JSONPath -> 变量名
}

struct OutputExtraction: Codable {
    var jsonPath: String    // 如 "$.Result.KeyNo"
    var variableName: String // 如 "companyId"
}
```

### 2. API 组合（APIPipeline 模型）

```swift
@Model
final class APIPipeline {
    var id: UUID
    var name: String
    var steps: [APIPipelineStep]  // 有序步骤
    var description: String?
}

struct APIPipelineStep: Codable {
    var endpointId: UUID
    var inputMappings: [String: String]  // 变量名 -> 参数位置
}
```

### 3. 认证支持

- **无认证**: 直接请求
- **API Key**: Header 或 Query 参数
- **Token 生成**: 本地计算（MD5/HMAC），如企查查的 `MD5(Key+Timestamp+Secret)`
- **自定义**: 灵活配置

### 4. 响应显示

#### 双视图切换
- **JSON 视图**: 格式化、语法高亮、折叠展开
- **卡片/表格视图**: 自动根据 JSON 结构转换

#### 自动转换规则
1. **对象数组** → 表格（字段为列）
2. **嵌套对象** → 卡片组（键值对展示）
3. **简单数组** → 列表
4. **混合结构** → 分区卡片

#### 表格特性
- 默认显示 5 行，超出显示"展开更多"按钮
- 展开后显示全部，可"收起"
- 支持复制单元格/行数据

## UI 设计

### 侧边栏结构

```
├── 命令
├── 组合
├── 快捷
├── ─────────
├── API          ← 新增
└── API 组合     ← 新增
```

### 响应式布局

- **宽屏模式**（窗口宽度 > 700pt）: 左侧 JSON，右侧卡片/表格
- **窄屏模式**: 顶部 Tab 切换（JSON / 卡片）

### APIEndpointDetailView 布局

```
┌─────────────────────────────────────────┐
│ [图标] API名称              [编辑] [删除] │
├─────────────────────────────────────────┤
│ 基本信息                                 │
│ ┌─────────────────────────────────────┐ │
│ │ 方法: [GET ▼]  URL: [____________]  │ │
│ │ Headers: [+添加]                    │ │
│ │ Body: [文本框...]                   │ │
│ └─────────────────────────────────────┘ │
│                                         │
│ 认证配置                                 │
│ ┌─────────────────────────────────────┐ │
│ │ 类型: [Token生成 ▼]                 │ │
│ │ Key: [___] Secret: [___]           │ │
│ │ 算法: [MD5(Key+Timestamp+Secret)]  │ │
│ └─────────────────────────────────────┘ │
│                                         │
│ [▶ 发送请求]                            │
│                                         │
│ 响应  [JSON] [卡片/表格]                │
│ ┌─────────────────────────────────────┐ │
│ │ {                                   │ │
│ │   "Status": "200",                  │ │
│ │   "Result": { ... }                 │ │
│ │ }                                   │ │
│ └─────────────────────────────────────┘ │
└─────────────────────────────────────────┘
```

### 卡片/表格视图示例

```
┌─────────────────────────────────────────┐
│ 基本信息                                 │
│ ┌─────────────────────────────────────┐ │
│ │ 企业名称    深圳市腾讯计算机系统有限公司  │ │
│ │ 法定代表人  马化腾                     │ │
│ │ 成立日期    1998-11-11               │ │
│ └─────────────────────────────────────┘ │
│                                         │
│ 股东信息 (共 8 个)                       │
│ ┌─────────────────────────────────────┐ │
│ │ 股东名称        | 持股比例 | 认缴出资   │ │
│ │ 黄惠卿          | 54.29%  | 3252万    │ │
│ │ 马化腾          | 28.57%  | 1714万    │ │
│ │ 许晨晔          | 5.71%   | 343万     │ │
│ │ 陈一丹          | 5.71%   | 343万     │ │
│ │ 张志东          | 5.71%   | 343万     │ │
│ │ ─────── [展开更多 3 条] ───────      │ │
│ └─────────────────────────────────────┘ │
└─────────────────────────────────────────┘
```

## 数据流

### API 组合执行流程

```
1. 用户输入初始参数（如公司名）
2. 执行第一个 API（搜索）
3. 提取指定字段（如 KeyNo）到变量
4. 变量注入第二个 API 的参数
5. 执行第二个 API（详情）
6. 显示最终结果
```

### 变量系统

- `{{input}}` - 用户输入
- `{{timestamp}}` - 当前时间戳
- `{{step1.KeyNo}}` - 前一步提取的值
- `{{auth.token}}` - 计算生成的认证 Token

## 导入导出

### 格式

```json
{
  "version": "1.0",
  "type": "api_endpoints",  // 或 "api_pipelines"
  "data": [...]
}
```

### 操作

- 导出: 选中项目 → 右键/菜单 → 导出为 JSON
- 导入: 拖放 JSON 文件 或 菜单 → 导入

## 实现步骤

1. **模型层**
   - 创建 APIEndpoint 模型
   - 创建 APIPipeline 模型
   - 注册到 ModelContainer

2. **服务层**
   - 创建 APIRunner 服务（HTTP 请求、认证处理）
   - 创建 JSONPathExtractor 工具

3. **视图层**
   - APIEndpointDetailView（配置 + 响应显示）
   - APIPipelineDetailView（组合配置 + 执行）
   - JSONResponseView（格式化 JSON）
   - CardResponseView（智能卡片/表格）
   - 修改 SidebarView 添加 API 分区
   - 修改 ContentView 处理 API 选择

4. **导入导出**
   - 实现 JSON 序列化/反序列化
   - 文件选择器集成

## 注意事项

- 保持现有功能完整，API 为独立模块
- 响应式布局适配各种窗口尺寸
- 表格默认 5 行，支持展开/收起
- 敏感信息（Secret）在 UI 上做适当遮蔽
