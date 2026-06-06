# 嘟嘟桌宠 — 架构蓝图

## 整体架构

```
┌─────────────────────────────────────────────────────────┐
│                    Godot 4.x 前端                         │
│                                                         │
│  ┌──────────────────┐  ┌────────────────────────────┐  │
│  │  透明桌面窗口      │  │  气泡对话层                  │  │
│  │  (per-pixel alpha) │  │  (Label + NinePatchRect)   │  │
│  └──────────────────┘  └────────────────────────────┘  │
│                                                         │
│  ┌──────────────────┐  ┌────────────────────────────┐  │
│  │  精灵动画系统      │  │  历史对话面板                │  │
│  │  (AnimationPlayer │  │  (Control 子树, 可开关)     │  │
│  │   + Sprite2D)     │  └────────────────────────────┘  │
│  └──────────────────┘                                   │
│                                                         │
│  ┌──────────────────────────────────────────────────┐  │
│  │              WebSocket Client                     │  │
│  │              (自动重连 + 心跳)                      │  │
│  └──────────────────────────────────────────────────┘  │
├─────────────────────────────────────────────────────────┤
│              WebSocket (ws://127.0.0.1:9876)            │
├─────────────────────────────────────────────────────────┤
│                    Python 后端                           │
│                                                         │
│  ┌──────────────────┐  ┌────────────────────────────┐  │
│  │  WebSocket Server │  │  消息路由 (MessageRouter)   │  │
│  │  (asyncio +       │  │                            │  │
│  │   websockets)     │  └────────────────────────────┘  │
│  └──────────────────┘                                   │
│                                                         │
│  ┌──────────────────┐  ┌────────────────────────────┐  │
│  │  对话引擎          │  │  定时器引擎                  │  │
│  │  ContextBuilder   │  │  PomodoroTimer              │  │
│  │  MemoryManager    │  │  ReminderScheduler           │  │
│  │  AIWorker         │  │  PoissonHeartbeat            │  │
│  └──────────────────┘  └────────────────────────────┘  │
│                                                         │
│  ┌──────────────────┐  ┌────────────────────────────┐  │
│  │  Persona (人设)    │  │  LLM Client                │  │
│  │  dudu_persona.py │  │  (GLM / 通用 OpenAI 兼容)   │  │
│  └──────────────────┘  └────────────────────────────┘  │
│                                                         │
│  ┌──────────────────────────────────────────────────┐  │
│  │              数据存储                              │  │
│  │  data/config.json          (配置 + API keys)      │  │
│  │  data/full_memory/         (JSONL 日志)            │  │
│  │  data/compressed_memory/   (压缩摘要, JSON)         │  │
│  └──────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

## 关键设计决策

### 1. 为什么 Godot 4.x 而不是 3.x

- 4.x 的 `window/transparent` 和 `window/borderless` 对 Windows 的 per-pixel transparency 支持更成熟
- GDScript 2.0 的类型系统让前后端协议序列化更安全
- 如果后续考虑移动端（不太可能），4.x 的渲染管线更现代

### 2. 为什么 WebSocket 而不是 HTTP

- 桌宠需要 **双向推送**：心跳卖萌、番茄计时结束、提醒触发都是服务端主动推送
- HTTP 轮询对本地应用太重，WebSocket 是长连接，延迟 <1ms
- 不需要考虑跨网络场景（始终 localhost）

### 3. 消息协议设计（前后端 Contract）

所有消息为 JSON，顶层结构：

```json
{
  "type": "message_type",
  "id": "uuid",
  "timestamp": 1717459200.0,
  "payload": { ... }
}
```

**前端 → 后端：**

| type | payload | 说明 |
|------|---------|------|
| `user.chat` | `{text, options}` | 用户输入对话 |
| `pomodoro.start` | `{duration, focus, target}` | 开始番茄钟 |
| `pomodoro.abort` | `{}` | 中止番茄钟 |
| `pomodoro.pause` | `{}` | 暂停 |
| `pomodoro.resume` | `{}` | 继续 |
| `history.request` | `{date?}` | 请求历史对话 |
| `pet.poke` | `{x, y}` | 用户戳了猫 |
| `ping` | `{}` | 连接保活 |

**后端 → 前端：**

| type | payload | 说明 |
|------|---------|------|
| `assistant.chunk` | `{delta, idx}` | AI 回复流式片段 |
| `assistant.done` | `{full_text}` | AI 回复完成 |
| `assistant.thinking` | `{content}` | 思考过程（可选展示） |
| `pet.action` | `{animation, bubble_text?, duration?}` | 触发猫的动作 |
| `pomodoro.tick` | `{phase, remaining, total}` | 计时更新 |
| `pomodoro.phase_change` | `{phase, bubble_text}` | 阶段切换 + 猫的反应 |
| `reminder.trigger` | `{type, bubble_text}` | 提醒触发 |
| `heartbeat.chat` | `{text}` | 猫主动说话 |
| `backend.status` | `{state}` | 后端状态（ready/error/busy） |
| `history.data` | `{date, messages}` | 历史对话数据 |
| `pong` | `{}` | 保活响应 |

### 4. 动画状态机

```
                    ┌──────────┐
           ┌───────→│  IDLE    │←───────┐
           │        │ (坐/舔爪) │        │
           │        └─────┬────┘        │
           │              │             │
     心跳/被戳     番茄开始/提醒触发     │
           │              │             │
           │        ┌─────▼────┐        │
           │        │  TALKING  │        │
           │        │ (张嘴气泡)│        │
           │        └─────┬────┘        │
           │              │             │
           │        回复完成            │
           │              │             │
           │        ┌─────▼────┐        │
           │        │  SPECIAL  │───────┘
           │        │ (事件动画)│
           │        └──────────┘
           │
      ┌────▼─────┐
      │  SLEEPING │  (长时间无交互)
      │ (蜷成圆球)│
      └──────────┘
```

**动画→精灵映射：**

| 动画状态 | 精灵帧 | 循环 | 触发条件 |
|---------|--------|------|---------|
| idle_sit | 嘟嘟坐，肚子起伏，偶尔舔爪 | 循环 + 随机舔爪 | 默认状态 |
| idle_sleep | 蜷成完美圆球 | 循环（呼吸起伏） | 30分钟无交互 |
| walk | 走路颠颠的 | 循环 | 偶尔在桌面移动 |
| excited | 跳起来转一圈 | 单次 → 回到 idle | 番茄钟结束 |
| talking | 张嘴 + 气泡 | 循环 | AI 回复中 |
| lick_mouth | 舔嘴 | 单次 → 回到 idle | 喝水提醒 |
| wiggle_butt | 站起来扭屁股 | 循环 → 回到 idle | 提肛提醒 |
| petted | 眯眼蹭头 | 单次 → 回到 idle | 用户戳猫 |

### 5. 从 Nero 移植什么，不移植什么

**直接移植（算法/逻辑）：**
- `context.py` 的上下文组装逻辑 → 简化参数（MAX_FULL_MESSAGES=20）
- `memory.py` 的压缩算法 → 保留 token 窗口 + 批次策略，去掉二级压缩
- `idle_poisson.py` → 直接复用 Poisson 采样算法
- `pomodoro.py` 的状态机 → 去掉 Qt 信号，改用 async callback

**简化移植：**
- Persona 系统 → 不需要多 variant，一个系统 prompt
- Memory 系统 → Raw (JSONL) + Summary (JSON) 两层，去掉 daily/core/evolving MD 文件
- Tool system → v1 不需要，纯对话模式

**不移植：**
- PyQt6 UI 全套（用 Godot 替代）
- Ombre Brain（你们不需要）
- 晚安闹钟（v1 不需要，后续可选）
- Focus Challenge（不需要）
- 小屋系统（v2 再说）
- Brave 搜索工具（v1 不搞自主行动）

### 6. 错误恢复约定

- Godot 侧 WebSocket 断开 → 显示 `[连接中断]` 半透明遮罩，5 秒后自动重连，指数退避
- Python 后端崩溃 → Godot 保持窗口存活，猫进入 `idle_sleep` 状态
- AI 调用超时（>30s）→ 后端返回 `backend.status {state: "error"}` + 气泡显示"嘟嘟卡住了，等一下哦"
- API key 未配置 → 启动时后端返回 `backend.status {state: "no_api_key"}` → 前端显示设置引导
