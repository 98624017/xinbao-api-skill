---
name: xinbao-api
description: Use when integrating Xinbao API for multimodal chat, Gemini image generation, Gemini async image tasks, GPT Image or OpenAI-style async image tasks including gpt-image-2 and gpt-image-2-oai, batch task polling, Sora or Veo or Doubao video tasks, or ComfyUI workflows.
---

# Xinbao API

用于调用心宝 API 的参考 skill。当前范围覆盖：

- 多模态聊天 `POST /v1/chat/completions`
- 主站同步生图 `POST /v1beta/models/{model}:generateContent`
- Gemini 原生异步生图 `POST /v1beta/models/{model}:generateContent` + `/v1/tasks/*` + `POST /v1/tasks/batch-get`
- GPT Image / OpenAI 风格异步生图 `POST /v1/images/generations` + `/v1/tasks/*` + `POST /v1/tasks/batch-get`
  当前已收录 `gpt-image-2`、`gpt-image-2-oai`
- 标准视频任务 `POST /v1/videos`，当前收录 `Sora`、`Veo`、`即梦 / 豆包`
- ComfyUI 特殊工作流 `POST /v1/videos` + `nodeInfoList`

## 何时使用

- 需要为心宝 API 选正确的端点、Base URL、鉴权头和请求体
- 需要同步生图、Gemini 异步生图、GPT Image 异步生图、视频任务或 ComfyUI 工作流示例
- 需要确认 `gpt-image-2-oai` 是否复用 `gpt-image-2` 任务流，以及
  `quality`、`size` 该怎么传
- 需要确认当前文档已覆盖哪些视频模型，以及 `Grok` 缺少独立页面时该怎么说明
- 需要轮询策略、结果解析路径和常见错误处理

如果用户明确要求“真实调用验证”或“以线上结果为准”，先阅读
`references/verification-status.md`。其中已经记录了：

- `2026-03-21 / 2026-03-22` 的公网异步生图与 batch-get live 结果
- `2026-04-20` 的 `gpt-image-2` 异步真实验证结果

当前已能确认：Gemini 异步与 GPT Image 异步都存在真实成功样本；但主站同步生图仍未拿到稳定业务层响应，`GPT Image` 也还不能写成“每一笔都已证明稳定成功”。

## 快速路由

- 接入前准备、鉴权、Base URL、通用错误：`references/quickstart.md`
- 多模态聊天：`references/multimodal-chat.md`
- 主站同步生图：`references/image-generation.md`
- Gemini 原生异步生图：`references/async-image-tasks.md`
- GPT Image / OpenAI 风格异步生图：`references/async-openai-image-tasks.md`
  包含 `gpt-image-2-oai` 的 `quality` / `size` 说明与常用尺寸建议
- 异步生图并发压测脚本：`scripts/run_xinbao_async_pressure_test.sh`
- Sora 视频任务：`references/video-sora.md`
- Veo 视频任务：`references/video-veo.md`
- 即梦 / 豆包视频任务：`references/video-doubao.md`
- ComfyUI 特殊工作流：`references/comfyui.md`
- 当前验证状态与阻塞项：`references/verification-status.md`

## 工作规则

1. 所有接口统一使用：

```http
Authorization: Bearer <API_KEY>
Content-Type: application/json
```

2. Base URL 必须按能力区分，同时保留异步生图兼容入口：

- 主站：`https://api.xinbao-ai.com`
- 异步生图专用入口：`https://async.xinbao-ai.com`
- 异步生图兼容入口：`https://api.xinbaoai.com`
  使用与异步生图专用入口完全相同的请求体发起任务

3. 能同步就不要误走异步：

- 多模态聊天、主站同步生图、视频任务、ComfyUI 都走主站
- 异步生图任务流优先走 `async.xinbao-ai.com`
- 若用户环境统一接入 `api.xinbaoai.com`，Gemini 异步生图与 GPT Image / OpenAI 风格异步生图
  可使用相同请求体向 `https://api.xinbaoai.com` 发起
- 轮询和取结果优先使用提交响应中的 `polling_url`、`content_url`，不要手写猜测域名

4. 异步生图要按任务流处理：

- 提交成功通常是 `202 Accepted`
- Gemini 原生异步提交走 `POST /v1beta/models/{model}:generateContent`
- GPT Image / OpenAI 风格异步提交走 `POST /v1/images/generations`
- `gpt-image-2-oai` 与 `gpt-image-2` 走同一套异步任务流
- 读取 `id`、`polling_url`、`content_url`
- 常见生图耗时约 `60s` 到 `300s`
- 推荐客户端在提交后约 `50s` 再开始第一次轮询
- 单任务轮询 `GET /v1/tasks/{id}`
- 多任务统一优先使用 `POST /v1/tasks/batch-get`
- 后续默认按 `10s` 节拍轮询
- 优先遵守更大的 `Retry-After / next_poll_after_ms`

5. 视频任务按统一兼容路径解析：

- 标准视频优先取 `video_url`
- 再尝试 `data.video_url`、`content.video_url`、`content.url`、`detail.video_url`
- ComfyUI 特殊工作流读取 `results[*].url`

6. 当前收录的视频模型与范围：

- `Sora`
- `Veo`
- `即梦 / 豆包`
- `ComfyUI` 特殊工作流
- `Grok` 当前未提供独立 reference；若用户问到，只说明暂无独立页，不展开细研究

## 建议用法

1. 先判断任务类型，再只读对应 reference 文件。
2. 需要直接给用户命令时，优先复用 `scripts/xinbao_curl_examples.sh`。
3. 若用户要求 live verification，先阅读 `references/verification-status.md`，再基于用户提供的 key 追加验证。
4. 若用户问到 `gpt-image`、`gpt image2`、OpenAI 风格图生图，优先阅读 `references/async-openai-image-tasks.md`，不要套用 Gemini `generateContent` 请求体。
   对客户统一说明传 `image` 数组即可。
   参考图数量浅显说明为建议 `6` 张以内，上游可能有限制。
   若模型是 `gpt-image-2-oai`，补充按原样透传 `quality`、`size`。
5. 若用户问到当前容易失败的视频模型，不要深究各自坏法，直接以实时返回为准并按统一视频任务流处理。
6. 若用户要求异步生图压测，优先使用 `bash scripts/run_xinbao_async_pressure_test.sh`；该脚本默认携带 `3` 张公网参考图，并产出链路层统计。
7. 如果用户同时跟踪多个进行中任务，默认不要逐个高频 `GET /v1/tasks/{id}`，改用 `POST /v1/tasks/batch-get`。

## 示例模板

可直接参考：

- `scripts/xinbao_curl_examples.sh`
- `scripts/run_xinbao_async_pressure_test.sh`

它包含 chat、同步生图、异步生图提交/轮询、`Sora` / `Veo` / `即梦 / 豆包`
视频和 `ComfyUI` 的 curl 模板，其中也包含 Gemini 异步生图、GPT Image 异步生图与 batch-get 示例；并发压测脚本则用于复现多图参考图异步生图的高频轮询与链路层统计。

---

此目录由 `skill-seekers` 生成骨架后手工补全。
