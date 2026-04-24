# Changelog

## 0.1.2 - 2026-04-24

### 修复
- 将生图路由建议改为默认优先异步任务流，避免网络差、耗时长或长连接中断导致失败。
- 明确 `https://api.xinbaoai.com` 只命名为同步生图入口，不再使用“异步兼容入口”表述。

## 0.1.1 - 2026-04-24

### 修复
- 修正 `https://api.xinbaoai.com` 的定位：该地址是主站同步生图入口，不是异步生图兼容入口。
- 移除异步生图参考文档和脚本中对 `api.xinbaoai.com` 的错误异步入口说明。

## 0.1.0 - 2026-04-24

### 新增
- 首次发布 `xinbao-api` skill 独立公开仓库。
- 支持多模态聊天、同步生图、Gemini 异步生图、GPT Image / OpenAI 风格异步生图、视频任务与 ComfyUI 工作流参考。
- 补充主站同步生图 Base URL：`https://api.xinbaoai.com`。
- 提供 curl 示例脚本与异步生图并发压测脚本。

### 维护
- 增加 `VERSION` 与 `CHANGELOG.md`，后续按语义化版本管理发布。
