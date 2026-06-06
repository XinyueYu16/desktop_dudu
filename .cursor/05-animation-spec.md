# 嘟嘟桌宠 — 动画规格

> GPT 逐帧生成 → 组 GIF → 拆 sprite sheet → Godot AnimatedSprite2D 播放。
> 此方案无骨骼、无关键帧、无多图层分离。如果这条管线效果不行，再回退到手绘+骨骼方案。

## 资产管线

```
Prompt 描述帧序列
  → GPT 生成 GIF（或序列帧 PNG）
    → 工具拆成 sprite sheet（水平条带 PNG）
      → Godot SpriteFrames 资源
        → $AnimatedSprite2D.play("idle")
```

**拆分工具**：ffmpeg 一行搞定 `ffmpeg -i idle.gif idle_sheet.png`（自动拼接为水平条带），或用 ezgif 在线拆。
**帧规格**：统一 256×256 或 512×512 每帧（2 的幂，Godot 友好），背景透明。

## 动画清单（8 个）

每个动画 = 一个 GIF → 一张 sprite sheet。下面描述每个 GIF 给 GPT 生成时的 prompt 要点。

### 1. idle（默认待机）
- **循环**：是，3-4 秒
- **帧数**：8-12 帧
- **画面**：嘟嘟侧坐 45°，肚子随呼吸微微起伏（身体轮廓缩放感），尾巴尖偶尔轻轻晃一下
- **Prompt 要点**：`British shorthair blue cat sitting on desk, side view 45°, breathing belly rising and falling, tail tip occasionally twitching, pixel art or simple cute style, transparent background, sprite sheet frames`

### 2. sleep（睡觉）
- **循环**：是，2-3 秒
- **帧数**：6-8 帧
- **画面**：蜷成完美圆球，像个蓝灰色毛团子，轻微呼吸起伏
- **过渡**：另外需要一个 1 秒的过渡 GIF（sit → 趴下蜷起来），或者接受硬切
- **Prompt 要点**：`British shorthair blue cat curled into perfect round ball sleeping, slight breathing movement, cute round shape like a dumpling, transparent background`

### 3. walk（走路）
- **循环**：是，0.6-0.8 秒
- **帧数**：4-6 帧
- **画面**：侧视角走路，身体上下颠（弹跳感），短腿交替前移
- **Prompt 要点**：`British shorthair blue cat walking sideways, bouncy short legs, chubby body slightly bouncing up and down, 4-6 frame walk cycle, transparent background`

### 4. excited（兴奋跳转圈）
- **循环**：否，1.5 秒，播完回 idle
- **帧数**：12-15 帧
- **画面**：下蹲蓄力 → 跳起 → 空中旋转 360° → 落地站稳
- **Prompt 要点**：`British shorthair blue cat jumping up excitedly, spinning 360 degrees in air, landing and standing, cute celebratory animation, 12-15 frames, transparent background`

### 5. talking（对话中）
- **循环**：是，0.8 秒
- **帧数**：3-4 帧（嘴巴张合）
- **画面**：保持坐姿，嘴巴张合（张 30% → 100% → 合），可以加偶尔眨眼
- **Prompt 要点**：`British shorthair blue cat sitting, mouth opening and closing as if talking, 3-4 frame loop, subtle, transparent background`

### 6. lick_mouth（舔嘴）
- **循环**：否，1.2 秒，播完回 idle
- **帧数**：8-10 帧
- **画面**：舌头伸出 → 上舔嘴唇 → 收回 → 抿嘴
- **Prompt 要点**：`British shorthair blue cat licking its mouth, tongue sticking out and licking upper lip, satisfied after drinking water, 8-10 frames, transparent background`

### 7. wiggle_butt（扭屁股）
- **循环**：是，2 秒（循环直到提醒确认）
- **帧数**：8-10 帧
- **画面**：站立姿态（前腿伸直撑地，屁股抬高），屁股左右摇摆
- **Prompt 要点**：`British shorthair blue cat standing on all fours, butt raised, wiggling hips left and right, playful butt wiggle, 8-10 frame loop, transparent background`

### 8. petted（被摸头）
- **循环**：否，1 秒，播完回 idle
- **帧数**：6-8 帧
- **画面**：眯眼（眼睛变弯线），头微仰，往一侧蹭一下然后恢复
- **Prompt 要点**：`British shorthair blue cat being petted on head, eyes closing into happy curves, head tilting up and nuzzling, cute reaction, 6-8 frames, transparent background`

## Godot 实现

### 核心节点

```
Cat (Node2D)
├── AnimatedSprite2D          # 猫本体，播放上述 8 个动画
├── Sprite2D (accessory)      # 配饰层，换装时换这个 texture
└── Marker2D (bubble_anchor)  # 气泡出现的位置（头顶）
```

只需要 3 个节点。AnimatedSprite2D 负责一切动画，换装只是给 accessory 换一张 PNG。

### SpriteFrames 资源结构

```
res://assets/sprites/dudu_sprite_frames.tres
  ├── "idle"         → 8-12 frames
  ├── "sleep"        → 6-8 frames
  ├── "walk"         → 4-6 frames
  ├── "excited"      → 12-15 frames
  ├── "talking"      → 3-4 frames
  ├── "lick_mouth"   → 8-10 frames
  ├── "wiggle_butt"  → 8-10 frames
  └── "petted"       → 6-8 frames
```

### 动画状态机（GDScript 逻辑，不用 AnimationTree）

```gdscript
# cat_controller.gd
extends Node2D

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var current_state: String = "idle"
var one_shot_pending: bool = false  # 单次动画正在播放

func play_anim(state: String):
    if state in ["excited", "lick_mouth", "petted"]:
        one_shot_pending = true
        sprite.play(state)
        # 播完回 idle，在 _on_animation_finished 里处理
    else:
        one_shot_pending = false
        sprite.play(state)
    current_state = state

func _on_animation_finished():
    if one_shot_pending:
        play_anim("idle")
```

### 换装

```gdscript
# 换装就是换 accessory 的 texture
func set_accessory(texture_path: String):
    if texture_path == "":
        $accessory.texture = null
    else:
        $accessory.texture = load(texture_path)
```

配饰 PNG 需要和猫精灵等大（256 或 512），在对应位置画配饰，其余部分透明。

## 项目结构（简化后）

```
dudu_pet/
├── project.godot
├── scenes/
│   ├── main.tscn
│   ├── cat.tscn               # 猫本体：AnimatedSprite2D + accessory + bubble_anchor
│   ├── bubble.tscn
│   └── panels/                # 番茄钟面板、设置面板等（后续）
├── scripts/
│   ├── websocket_client.gd
│   ├── cat_controller.gd      # 动画状态机 + 换装
│   ├── bubble_manager.gd
│   └── window_manager.gd
├── assets/
│   ├── sprites/
│   │   └── dudu_sprite_frames.tres   # 所有动画
│   ├── accessories/                  # 配饰 PNG（V2）
│   └── fonts/
└── backend/                   # Python 后端
```

## 占位方案

在 GPT 出图之前，每个动画用一张静态纯色方块代替：
- idle: 蓝色方块 + 文字 "idle"
- walk: 蓝色方块 + 箭头 → 左右移动
- etc.

动画先调通，猫图到齐后一键替换 `dudu_sprite_frames.tres`。

## 风险与回退

如果 GPT 生成的关键帧不稳定（闪烁、风格不一致、动作不连贯）：
- **尝试**：改用更详细的 prompt，指定风格参考图，或换 Stable Diffusion + ControlNet 逐帧生成
- **回退**：手绘关键帧 + Krita/Aseprite 做像素动画，仍用 sprite sheet 管线
- **极端回退**：骨骼方案（原方案），用 DragonBones 或 Godot Skeleton2D

先在 Phase 0 验证阶段用一个动画（比如 idle）跑通 GPT→GIF→Godot 全管线，确认可行再批量生成其余 7 个。
