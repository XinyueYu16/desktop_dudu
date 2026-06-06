# 嘟嘟桌宠 — 技术验证计划

## P0-1: Godot 桌面透明悬浮窗口

**目标**：一个无边框、透明背景、始终置顶的 Godot 窗口，其中显示一个方块精灵。

**验证标准：**
- [ ] 窗口无边框、背景完全透明（桌面可见）
- [ ] 窗口始终置顶（Always on Top）
- [ ] 点击透明区域穿透到桌面（`mouse_passthrough`）
- [ ] 可拖拽移动窗口
- [ ] 方块（Sprite2D）正常渲染在透明背景上
- [ ] 系统托盘图标（可选收缩）

**Godot 4.x 关键设置（已验证 Win10 + Godot 4.6.3）：**

```toml
# project.godot
[display]
window/size/transparent=true
window/size/borderless=true
window/size/always_on_top=true
window/per_pixel_transparency/allowed=true   # 注意：是 allowed 不是 enabled

[rendering]
renderer/rendering_method="gl_compatibility"  # D3D12 有透明bug，用兼容模式
viewport/transparent_background=true
```

**已验证的坑：**
- `window/per_pixel_transparency/enabled` 无效，正确 key 是 `allowed`
- `forward_plus` (D3D12) 在 Win10 上背景透明不工作，必须用 `gl_compatibility` (D3D11)
- 代码里额外加 `get_viewport().transparent_bg = true` + `get_tree().root.set_transparent_background(true)` 做双保险

**旧版说明（已废弃）：**
window/size/borderless=true
window/size/always_on_top=true
window/per_pixel_transparency/enabled=true

[rendering]
renderer/rendering_method=gl_compatibility  # 先用兼容模式，后续再试 forward+
```

**已知坑点：**
- Godot 4.x 在 Windows 上 `per_pixel_transparency` 需要 `rendering_method=forward_plus`（mobile/gl_compatibility 不支持），但 forward_plus 在某些集显上性能差。需要实测。
- `mouse_passthrough` 是 4.3+ 才有的功能，需要确认版本。
- Windows 11 的 `WS_EX_LAYERED` 行为可能和 Windows 10 不同。目标用户是 Windows 10。

**验证方法：**
1. 创建最小 Godot 项目，用 ColorRect 当"猫"
2. 在 Win10 上运行，截图看透明效果
3. 测试点击穿透：打开记事本放在猫后面，点击猫周围能否点到记事本
4. 测试拖拽：能否拖动猫到桌面任意位置

**预计耗时**：2-4 小时（如果顺利）/ 1 天（如果遇到平台问题）
**降级方案**：如果 Godot 透明窗口不满足要求 → Electron + HTML Canvas 或回退 PyQt6（Nero 方案已证明可行）

---

## P0-2: Python ↔ Godot WebSocket 通信

**目标**：Python 后端启动 WebSocket 服务器，Godot 连接后能收发 JSON 消息，猫显示气泡。

**验证标准：**
- [ ] Python asyncio WebSocket server 在 `ws://localhost:9876` 启动
- [ ] Godot `WebSocketPeer` 能连接并完成握手
- [ ] 前端发送 `user.chat` → 后端收到并打印日志
- [ ] 后端发送 `pet.action {animation: "talking", bubble_text: "喵~"}` → 前端弹出气泡
- [ ] 连接断开后 Godot 能检测并自动重连
- [ ] 后端重启后 Godot 能恢复连接

**Python 侧最小实现：**

```python
# server.py
import asyncio, json
from websockets.asyncio.server import serve

async def handler(ws):
    async for raw in ws:
        msg = json.loads(raw)
        match msg["type"]:
            case "user.chat":
                # 暂时回显，后续接 AI
                await ws.send(json.dumps({
                    "type": "pet.action",
                    "payload": {"animation": "talking", "bubble_text": "嘟嘟听到了！"}
                }))
            case "ping":
                await ws.send(json.dumps({"type": "pong", "payload": {}}))

async def main():
    async with serve(handler, "127.0.0.1", 9876):
        await asyncio.Future()  # run forever

asyncio.run(main())
```

**Godot 侧最小实现（GDScript）：**

```gdscript
# websocket_client.gd
extends Node

var ws = WebSocketPeer.new()

func _ready():
    var err = ws.connect_to_url("ws://127.0.0.1:9876")
    # 轮询在 _process 里处理

func _process(_delta):
    ws.poll()
    var state = ws.get_ready_state()
    match state:
        WebSocketPeer.STATE_OPEN:
            while ws.get_available_packet_count() > 0:
                var packet = ws.get_packet()
                var msg = JSON.parse_string(packet.get_string_from_utf8())
                handle_message(msg)
        WebSocketPeer.STATE_CLOSED:
            # 重连逻辑
            pass

func send(msg: Dictionary):
    ws.send_text(JSON.stringify(msg))

func handle_message(msg: Dictionary):
    match msg["type"]:
        "pet.action":
            show_bubble(msg["payload"]["bubble_text"])
```

**预计耗时**：1-2 小时
**风险**：低。WebSocket 是成熟协议，两端都有标准库支持。

---

## P1-0: 消息协议冻结

**目标**：在 P0 两个验证通过后，把 [架构蓝图](./02-architecture-blueprint.md) 中的消息类型定下来，作为 `protocol.md` 正式文件。不再轻易改动顶层字段。

**为什么在 P1 而不是 P0**：因为 P0 是技术可行性验证，协议细节在验证期间可能调整。P0 通过后立即冻结协议，前后端就可以并行开发了。

**协议文件应包含：**
- 所有消息类型的 JSON Schema
- 错误消息格式
- 心跳间隔（建议 30s）
- 重连策略参数（初始延迟 1s，指数退避上限 30s）
