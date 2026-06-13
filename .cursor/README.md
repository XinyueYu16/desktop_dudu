# 嘟嘟桌宠 — 项目规划索引

## 文件索引

| 文件 | 内容 |
|------|------|
| [01-priority-assessment.md](./01-priority-assessment.md) | 优先级矩阵 + 与另一个 AI 的差异 |
| [02-architecture-blueprint.md](./02-architecture-blueprint.md) | 整体架构、消息协议、动画状态机、Nero 移植策略 |
| [03-tech-validation.md](./03-tech-validation.md) | P0 技术验证：Godot 透明窗口 + WebSocket 通信 |
| [04-dev-phases.md](./04-dev-phases.md) | Phase 0-5+ 开发阶段 + 每周目标 |
| [05-animation-spec.md](./05-animation-spec.md) | 8 个动画的规格、图层架构、Godot 项目结构 |
| [06-persona-spec.md](./06-persona-spec.md) | 嘟嘟的性格设定、说话风格、system prompt 模板 |
| [../design/ui-design-guidelines.md](../design/ui-design-guidelines.md) | UI 设计准则（色板、按钮、卡片；由 `.cursor/rules/ui-design.mdc` 强制注入） |

## Agent 规则

| 规则文件 | 作用 |
|----------|------|
| [rules/ui-design.mdc](./rules/ui-design.mdc) | 每次对话自动加载 UI 硬性规则 |

## 核心决策总结

1. **架构**：Python 后端 + Godot 4.x 前端，WebSocket 通信
2. **先做什么**：P0 技术验证（Godot 透明窗口 → WebSocket 通信 → 协议冻结）
3. **记忆系统**：简化为 2 层（Raw JSONL + 压缩摘要），不搬 Nero 的 4 层
4. **精灵**：多图层架构（body/belly/head/eyes/mouth/ears/paws/tail），支持后续换装
5. **启动方式**：Godot 主进程，用 OS.execute() 拉起 Python 后端
6. **模型**：OpenAI 兼容接口（GLM / 通义千问 均可）
7. **语言**：中文为主，"主人"称呼用户

## 参考来源

- [Nero AI 功能与架构总结](D:\ai_puppy\inspirations\Nero AI 功能与架构总结.md)
- Nero 源码：`D:\ai_puppy\nero_pet\`
- 另一个 AI 的优先级评估 + 动画设想
