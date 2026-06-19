# Feature: Tree-Structured Conversation Manager

## Status
design

## Problem
当前对话列表是扁平列表，随着对话增多难以管理。用户需要一个树形分层结构来组织对话——类似知识体系，可以无限嵌套分类，把对话归入对应节点。

## 设计目标
- 自由树形结构，无限层级
- 文件夹和对话混合排列
- 拖拽移动（长按拖动文件夹或对话到新位置）
- 轻量，不引入重量级包

## Data Model

### Folder
```
id: String (uuid)
name: String
parent_id: String? (null = root)
created_at: DateTime
sort_order: int (同层排序)
```

### Conversation (扩展)
```
+ folder_id: String? (null = 不在任何文件夹)
+ server_id: String?  (绑定 Hermes 实例，切换时自动重连)
现有字段不变
```

### 树节点（UI 用）
```
TreeNode {
  type: folder | conversation
  data: Folder | Conversation
  children: List<TreeNode>  // folder only
  depth: int
  isExpanded: bool
}
```

## DB Schema

```sql
-- 新增表
CREATE TABLE folders (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  parent_id TEXT,
  sort_order INTEGER DEFAULT 0,
  created_at TEXT NOT NULL,
  FOREIGN KEY (parent_id) REFERENCES folders(id) ON DELETE CASCADE
);

-- 扩展 conversations 表
ALTER TABLE conversations ADD COLUMN folder_id TEXT;
```

DB migration: StorageService._schemaVersion → 2，`onUpgrade` 中执行 ALTER TABLE。

## UI Design

### 主界面：Tree View

```
┌──────────────────────────────────┐
│  ⋮  Conversations            [+] │  ← AppBar: menu + 新建按钮
├──────────────────────────────────┤
│  ▼ 📁 Code                       │  ← 展开的文件夹
│    ▼ 📁 vllm                     │
│      💬 PR #44602 讨论   3 msgs  │  ← 对话，右侧消息数
│      💬 disaggregated    12 msgs │
│    ▶ 📁 hermes-mobile            │  ← 折叠的文件夹
│  ▶ 📁 股票研究                   │
│  💬 随便聊聊             8 msgs  │  ← 不在文件夹的对话
└──────────────────────────────────┘
```

### 交互

| 操作 | 方式 | 效果 |
|------|------|------|
| 展开/折叠文件夹 | 点击文件夹 | 切换子节点显示 |
| 打开对话 | 点击对话 | 进入聊天界面 |
| 新建文件夹 | FAB 菜单 → New Folder | 弹出命名对话框 |
| 新建对话 | FAB 菜单 → New Chat | 在当前文件夹下创建 |
| 重命名 | 长按 → Rename | 弹出编辑框 |
| 删除 | 长按 → Delete | 确认后删除（文件夹递归删）|
| 移动 | 长按 → Move to... | 弹出文件夹选择器 |
| 排序 | 长按拖动 | 同层重排 |

### 快捷操作

- 点击对话 → 直接进入聊天
- 对话旁显示消息数
- 当前活跃对话高亮

## 与现有代码的关系

### 需要改的文件

| 文件 | 改动 |
|------|------|
| `models/folder.dart` | 新增 |
| `models/conversation.dart` | 加 folder_id |
| `services/storage_service.dart` | 加 folders 表 + CRUD + migration |
| `providers/chat_provider.dart` | 新建对话时传 folder_id，树数据加载 |
| `screens/conversations_screen.dart` | 完全重写为树形界面 |
| `screens/chat_screen.dart` | 小改：新建对话传 folder_id |

### 不影响

- ChatScreen 核心聊天逻辑不变
- Settings、Server 管理不变
- Relay 方案不变
- 直连/API Server 不变

## 分阶段实现

### Step 1: 数据层（本次）
- Folder 模型 ✅
- Conversation 加 folder_id
- StorageService: folders 表 + migration + CRUD
- 单元测试

### Step 2: Provider 层
- ChatProvider: 加载树结构，新建/移动/删除文件夹和对话
- TreeNode 构建逻辑

### Step 3: UI 层
- TreeView widget（递归展开/折叠）
- 长按菜单（重命名/删除/移动）
- FAB 菜单（新建文件夹/新建对话）
- 拖拽排序（可选，先 skip）

### Step 4: 集成
- ConversationsScreen 切换为 TreeView
- ChatScreen 新建对话关联文件夹
- 测试 + 提交
