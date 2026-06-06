# 嘟嘟桌宠 — 开发阶段

## Phase 0: 技术验证（目标 ≤2 天）

> 这两个验证一通过，整个项目的技术风险就清零了。后续都是已知施工。

| # | 任务 | 产出 | 验证方式 |
|---|------|------|---------|
| 0a | Godot 透明悬浮窗口 | 一个方块悬浮在桌面，能拖拽 | 截图 + 手动测试 |
| 0b | WebSocket 通信 | Python↔Godot 收发 JSON | 前端气泡显示后端发来的文字 |
| 0c | 协议冻结 | `protocol.md` | Review 通过后不再改 |

---

## Phase 1: 嘟嘟能动起来（目标 1 周）

> 这个阶段结束，桌面上有只猫了。它不会说话，但它存在。

| # | 任务 | 从 Nero 移植？ | 关键产出 |
|---|------|---------------|---------|
| 1a | 占位精灵系统 (方块 → 临时猫图) | 否 | Sprite2D + AnimationPlayer |
| 1b | idle 动画：坐姿 + 肚子起伏 + 舔爪 | 否 | 帧动画 + 随机触发器 |
| 1c | 动画状态机（idle/sleep/walk/talking/special） | 否 | AnimationTree |
| 1d | 气泡对话 UI | 参考 Nero bubble_widget | Label + NinePatchRect |
| 1e | 窗口管理：拖拽、托盘、右键菜单 | 参考 Nero pet_window | 右键菜单：设置/关于/退出 |
| 1f | 后端启动器 + 进程管理 | 否 | Godot 启动时拉起 Python |

**1f 的启动策略**：有两种模式可选——
- **模式 A（推荐）**：用户双击 `嘟嘟.exe` → Godot 启动 → Godot 用 `OS.execute()` 拉起 Python 后端。后端挂了 Godot 能检测并重启。
- **模式 B**：用户先手动启动 Python，再打开 Godot。简单但体验差。
- 选模式 A。Godot 负责生命周期管理。

---

## Phase 2: 嘟嘟会说话（目标 1-2 周）

> 这个阶段结束，嘟嘟是一个能聊天的桌面猫。已经可用了。

| # | 任务 | 从 Nero 移植？ | 关键产出 |
|---|------|---------------|---------|
| 2a | 人设 system prompt ("蓝猫嘟嘟") | 参考 Nero persona | `persona/dudu.md` |
| 2b | LLM Client（OpenAI 兼容接口） | 参考 Nero GLM/Gemini client | 支持 GLM / 通义千问 / 任意 OpenAI 兼容端点 |
| 2c | AIWorker：异步调用 + 流式返回 | 参考 Nero AIWorker (去 Qt) | asyncio + async generator |
| 2d | 上下文组装 (ContextBuilder) | 移植 Nero context.py | 简化为：system → summary → recent N turns → user |
| 2e | 前端流式显示 + talking 动画 | 否 | chunk 逐步追加 + 猫张嘴 |
| 2f | 对话历史持久化 (JSONL) | 移植 Nero MemoryManager | `data/full_memory/YYYY-MM-DD.jsonl` |

---

## Phase 3: 嘟嘟的节奏感（目标 1 周）

> 这个阶段结束，番茄钟 + 提醒可用了。嘟嘟已经融入日常。

| # | 任务 | 从 Nero 移植？ | 关键产出 |
|---|------|---------------|---------|
| 3a | 番茄钟状态机 (work/break/idle) | 移植 Nero pomodoro.py | async timer + 状态机 |
| 3b | 番茄钟 UI 面板 | 否 | 简单 Control 面板：选时长 + 开始/暂停/中止 |
| 3c | 番茄事件动画（开始/结束/中止） | 否 | excited 动画 + 气泡 |
| 3d | 喝水/提肛提醒调度器 | 参考 Nero goodnight | 定时检查 + 触发 |
| 3e | 提醒动画（舔嘴/扭屁股） | 否 | lick_mouth + wiggle_butt |
| 3f | 提醒配置面板 | 否 | 开关 + 时间设置 |

---

## Phase 4: 嘟嘟会卖萌（目标 1 周）

> 这个阶段结束，嘟嘟真正"像宠物"——它会自己找你。

| # | 任务 | 从 Nero 移植？ | 关键产出 |
|---|------|---------------|---------|
| 4a | Poisson 心跳引擎 | 直接移植 idle_poisson.py | 每 15-20min tick |
| 4b | 心跳内容生成 | 参考 Nero 心跳 prompt | 蓝猫主动说话/卖萌 |
| 4c | 上下文压缩 | 移植 Nero 压缩逻辑 | 简化版：单层压缩，保留最近 15 轮 |
| 4d | 睡眠状态 (30min 无交互 → 蜷成圆球) | 否 | idle_sleep 动画 + 过渡 |
| 4e | 被戳反应 (用户点猫 → 眯眼蹭头) | 否 | petted 动画 + 随机语音 |

---

## Phase 5: 嘟嘟的记忆（目标 1 周）

> 这个阶段结束，嘟嘟记得你们聊过什么。长期运行不丢上下文。

| # | 任务 | 从 Nero 移植？ | 关键产出 |
|---|------|---------------|---------|
| 5a | 历史对话窗口 | 参考 Nero ChatHistoryDialog | 按日期浏览历史 |
| 5b | 压缩记忆摘要持久化 | 移植 Nero 压缩 | 启动时加载上次摘要 |

---

## Phase 6+: V2 功能（不排期）

- 星盘
- 换装（多图层精灵 + 配饰系统）
- 喂食互动（Unity-like 拖拽食物到猫）
- 小屋（移植 Nero house 系统）
- 旅游（小屋扩展 + AI 生成场景）
