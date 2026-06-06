# 嘟嘟桌宠 (DuDu Pet)

Godot 4.x 透明桌面宠物 + Python WebSocket 后端，支持 DeepSeek 对话。

## 结构

```
desktop_dudu/
├── dudu_pet/     # Godot 前端
├── backend/      # Python 后端 (WebSocket + LLM)
├── assets/       # 共享素材
└── .cursor/      # 项目规格与开发阶段文档
```

## 快速开始

### 1. 后端

```bat
cd backend
python -m venv venv
venv\Scripts\activate
pip install -r requirements.txt
copy .env.example .env
REM 编辑 .env，填入 DEEPSEEK_API_KEY
run_server.bat
```

后端监听 `ws://127.0.0.1:9876`。

### 2. 前端

用 Godot 4.6+ 打开 `dudu_pet/project.godot`，运行主场景。  
也可直接运行项目，Godot 会自动尝试拉起后端。

## 注意事项

- `.env` 和 `backend/data/memory/` 下的对话记录不会提交到 Git
- Windows 透明窗口需使用 `gl_compatibility` 渲染器（已在 `project.godot` 配置）
