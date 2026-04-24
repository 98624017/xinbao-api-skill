# Quickstart

## 适用范围

- 接入前准备
- 鉴权头
- Base URL 选择
- 通用错误排查

## 鉴权

所有接口统一使用：

```http
Authorization: Bearer <API_KEY>
```

## Base URL

```text
主站 Base URL: https://api.xinbao-ai.com
异步生图专用 Base URL: https://async.xinbao-ai.com
异步生图兼容 Base URL: https://api.xinbaoai.com
```

异步生图模型也支持使用相同请求体向 `https://api.xinbaoai.com` 发起。
如果走兼容入口，提交请求体无需改字段；轮询和取结果优先使用提交响应中的
`polling_url`、`content_url`，避免客户端手写猜测域名。

## 端点速查

- 多模态聊天：
  `POST https://api.xinbao-ai.com/v1/chat/completions`
- 主站同步生图：
  `POST https://api.xinbao-ai.com/v1beta/models/{model}:generateContent`
- Gemini 异步生图提交：
  `POST https://async.xinbao-ai.com/v1beta/models/{model}:generateContent`
  或 `POST https://api.xinbaoai.com/v1beta/models/{model}:generateContent`
- GPT Image / OpenAI 风格异步生图提交：
  `POST https://async.xinbao-ai.com/v1/images/generations`
  或 `POST https://api.xinbaoai.com/v1/images/generations`
- 异步生图状态：
  `GET https://async.xinbao-ai.com/v1/tasks/{id}`
- 异步生图批量状态：
  `POST https://async.xinbao-ai.com/v1/tasks/batch-get`
- 异步生图结果跳转：
  `GET https://async.xinbao-ai.com/v1/tasks/{id}/content`
- 标准视频任务：
  `POST https://api.xinbao-ai.com/v1/videos`
- 视频轮询：
  `GET https://api.xinbao-ai.com/v1/videos/{id}`

## 异步生图轮询建议

- 常见生图耗时约 `60s` 到 `300s`
- 推荐客户端在提交后先等待约 `50s` 再开始第一次轮询
- 后续默认固定每 `10s` 轮询一次
- 单任务可用 `GET /v1/tasks/{id}`
- 多个进行中任务建议改用 `POST /v1/tasks/batch-get`
- 当前常见的服务端建议值为 `Retry-After = 10`、`next_poll_after_ms = 10000`
- 如果服务端返回更大的 `Retry-After / next_poll_after_ms`，优先遵守更大的值
- 如果进行中任务超过 `100` 个，请拆成多个 batch，并放在同一个轮询周期里发出

## GPT Image 异步接入提醒

- `gpt-image` / `gpt image2` 走：
  `POST https://async.xinbao-ai.com/v1/images/generations`
  或兼容入口 `POST https://api.xinbaoai.com/v1/images/generations`
- `gpt-image-2-oai` 也走同一个端点，与 `gpt-image-2`
  共用同一套异步任务流
- 不要误套 Gemini 的 `contents + generationConfig` 请求体
- 客户端提交时统一传 `image` 数组
- 参考图建议 `6` 张以内；上游可能存在数量限制
- 客户端侧只传 `response_format = url`
- 如果是 `gpt-image-2-oai`，可额外传 `quality`、`size`

## 当前文档覆盖范围

- 多模态聊天
- 同步生图
- Gemini 异步生图任务
- GPT Image / OpenAI 风格异步生图任务
- `Sora` / `Veo` / `即梦 / 豆包` 视频
- `ComfyUI` 特殊工作流

`Grok` 当前未提供独立页；若用户问到，先按统一视频任务流兼容说明，再以实时返回为准。

## 常见错误

- `401/403`：`API Key` 无效或未按 `Bearer` 格式传递
- `404`：接口路径或模型名不正确
- `400`：请求体结构错误、字段位置错误或输入格式不合法
- 异步生图 `409`：任务未完成，继续按 `Retry-After / next_poll_after_ms` 轮询
- 异步生图 `429`：单任务或同一批次轮询过快
- 异步任务 `failed/upstream_timeout`：任务已成功创建，但上游执行超时
- 视频任务长时间处理中：先检查轮询间隔和输入 URL 是否可公网访问

## 当前验证状态

实时验证状态见 `verification-status.md`。
