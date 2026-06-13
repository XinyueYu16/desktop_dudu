# 嘟嘟桌宠 UI 设计准则

参考 [animal-island-ui](https://github.com/guokaigdg/animal-island-ui)（动森风格组件库）与项目内 `ACStyle` 实现。所有新 UI 应优先复用 `dudu_pet/scripts/ac_style.gd` 中的样式工厂，禁止在面板内手写一次性按钮样式。

## 设计气质

- 温暖、圆润、低对比度的「小岛」感：奶油底、棕褐字、鼠尾草绿强调色
- 卡片有轻微描边与柔和阴影，避免扁平纯色块
- 参考 animal-island-ui 的圆角（约 8–12px）、充足内边距、按钮「可按压」质感

## 色板（`ACStyle`）

| 角色 | 常量 | 用途 |
|------|------|------|
| 面板底 | `CREAM` / `CREAM_BG` | 设置、提醒等浮层背景 |
| 主文字 | `BROWN` | 标题、正文、**所有可点击按钮文字** |
| 次要文字 | `BROWN_LIGHT` | 说明、占位、已保存态按钮 |
| 强调 | `SAGE` | Tab 选中、滑块、聊天气泡等 |
| 主操作绿 | `AC_GREEN` `#6fba2c` | 保存、添加、发送、知道了 |
| 危险 | 珊瑚红 | 删除、清空等破坏性操作 |
| 悬停底 | `HOVER` / `TAN` | 分隔、弱提示条 |

## 硬性规则

### 1. 禁止白色 / 近白字体

- **不允许**使用 `Color.WHITE`、`#FFFFFF` 或 `LIGHT_TEXT` 作为面板、设置、提醒、聊天气泡面板内的字体色
- 按钮文字统一 `BROWN`；已保存 / 禁用态可用 `BROWN_LIGHT`
- 例外：桌面悬浮输入框、深色半透明气泡（`chat_bubble_style` 暗色底）可保留浅色字，但不得为纯白

### 2. 可交互单键必须是「有阴影的实体按钮」

凡独立可点击的操作（非 Tab、非菜单项），须满足：

- `flat = false`（否则 StyleBox 背景不渲染，看起来像纯文字）
- `focus_mode = FOCUS_NONE`（桌宠场景不需要键盘焦点框）
- 使用带阴影的 `StyleBoxFlat`；强度与定时提醒卡片一致：`apply_soft_elevation_shadow`（主题色 α0.18，`shadow_size` 3，向下 2px）
- 通过统一 API 应用主题，勿复制粘贴 stylebox 代码

| 操作类型 | API | 示例 |
|----------|-----|------|
| 主操作（保存、添加、知道了） | `ACStyle.apply_footer_button_theme(btn, saved)` | 设置保存、提醒保存/添加 |
| 危险操作（删除、清空） | `ACStyle.apply_danger_button_theme(btn, min_width)` | 清空聊天记录、删除单条提醒 |
| 发送 | `ACStyle.chat_send_button_stylebox` + 棕字 | 聊天发送 |

尺寸默认：高 `32px`（`UiConfig.s(32)`），主按钮宽 `88px`，宽危险按钮 `160px`，紧凑删除 `52px`。

### 3. 列表卡片（定时提醒条 — 标杆实现）

每条提醒使用独立 `PanelContainer` 卡片，**当前实现为标杆**，新功能列表应参照：

- 按语义配色（如喝水浅蓝、提肛浅绿，自定义项轮换桃/薰衣草/暖黄）
- 圆角 12px、1px 同色描边、轻阴影（`shadow_offset` 向下 2px）
- 内边距 8–10px；禁用项整体 `modulate` 降至 0.55
- 次级信息（东八区、下次时间）用主题色 `badge` 的 65% 透明度，时间放在小徽章容器内

实现参考：`reminders_panel.gd` → `_card_stylebox`、`_time_badge_stylebox`、`_ROW_THEMES`。

### 4. 表单控件

- 输入框 / 下拉：`ACStyle.apply_line_edit_theme`、`apply_option_button_theme`
- 复选框：`ACStyle.apply_checkbox_theme`（棕字，不用默认灰字）
- 滑块 / 滚动条：`apply_slider_theme`、`apply_scroll_container_theme`

### 5. 面板布局

- 面板宽度统一 `400px` 设计宽（`UiConfig` 缩放）
- 内边距：左右 `12px`，内容右边界 `388px`（与 `settings_panel` 一致）
- 页脚按钮右对齐，`HBox` separation `8px`

## 组件清单（维护表）

新增 UI 时更新此表：

| 位置 | 控件 | 样式 API | 状态 |
|------|------|----------|------|
| 设置页脚 | 保存 | `apply_footer_button_theme` | ✅ |
| 设置·对话 | 清空聊天记录 | `apply_danger_button_theme(160)` | ✅ |
| 定时提醒页脚 | + 添加 / 保存 | `apply_footer_button_theme` | ✅ |
| 定时提醒行 | 删除 | `apply_danger_button_theme(52)` | ✅ |
| 提醒气泡 | 知道了 | `apply_footer_button_theme` | ✅ |
| 聊天 | 发送 | `chat_send_button_stylebox` | ✅ |

## 动效与反馈

- 按钮 hover：背景提亮约 8–10%，阴影保留
- 保存流程：未保存 → 可点绿色「保存」；已保存 → 浅绿「已保存 ✓」+ `disabled`
- 破坏性操作：使用危险色按钮，重要操作可加 `ConfirmationDialog`

## 参考链接

- [animal-island-ui](https://github.com/guokaigdg/animal-island-ui) — 动森风格 React 组件库
- [DESIGN_PROMPT.md](https://github.com/guokaigdg/animal-island-ui/blob/main/DESIGN_PROMPT.md) — 色板与禁止项
- 项目实现：`dudu_pet/scripts/ac_style.gd`、`reminders_panel.gd`、`settings_panel.gd`
- **Agent 自动加载**：`.cursor/rules/ui-design.mdc`（精简版）；本文档为完整版
