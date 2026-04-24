# Verification Status

## Date

- 2026-03-21
- 2026-03-22
- 2026-04-20

## Verified With Live Traffic

使用用户提供的测试 key，对以下接口做了真实请求验证：

1. `POST https://api.xinbao-ai.com/v1/chat/completions`
2. `POST https://async.xinbao-ai.com/v1beta/models/gemini-3-pro-image-preview:generateContent?output=url`
3. `GET https://async.xinbao-ai.com/v1/tasks/{id}`
4. `GET https://async.xinbao-ai.com/v1/tasks/{id}/content`
5. `POST https://api.xinbao-ai.com/v1/videos`
6. `POST https://async.xinbao-ai.com/v1/tasks/batch-get`

说明：

- `POST https://async.xinbao-ai.com/v1/tasks/batch-get` 已纳入当前文档覆盖范围
- 本页的 live verification 主体仍然以单任务查询链路为主
- `2026-04-20` 新增的是一次真实回归，不是直接对公网
  `https://async.xinbao-ai.com/v1/images/generations` 的 live 请求

## Confirmed Results

### Multimodal Chat

- 请求模型：`gemini-3-pro-preview-c`
- HTTP：`200`
- `choices[0].message.content = "OK"`
- 响应里的 `model = "gpt-5.2-2025-12-11"`

这说明响应 `model` 可能是渠道映射后的事实上游模型名，不一定等于请求时传入的模型字符串。

### Async Image Tasks

- 提交任务返回 `HTTP 202`
- 返回 `status = accepted`
- 返回了 `polling_url` 与 `content_url`
- 立即轮询时可见 `status = running`
- 立即访问 `/content` 返回 `HTTP 409`
- 稍后继续轮询，某次真实结果为：

```json
{
  "status": "failed",
  "error": {
    "code": "upstream_timeout",
    "message": "upstream request timed out"
  }
}
```

同日再次并行提交 `4` 笔最小文本生图任务后，又观察到：

- `4/4` 任务都成功提交
- `t30s` 时已有 `1` 笔 `succeeded`
- `t60s` 时已有 `2` 笔 `succeeded`
- `t120s` 时 `4/4` 全部 `succeeded`
- `/content` 最终都返回 `302` 到真实图片 URL

成功样本中的真实图片地址包括：

- `https://d.uguu.se/ziYGQPeq.png`
- `https://h.uguu.se/VaRrXlhm.png`
- `https://h.uguu.se/QnzHMVXw.png`
- `https://n.uguu.se/BVNgVmly.png`

因此当前更准确的判断是：异步生图链路已确认可成功产图，但也存在个别请求后续进入
`upstream_timeout` 的情况。

### Async Image Tasks: 20 Concurrent Multi-Reference Load Test

同日进一步做了 `20` 并发压测，每个任务都带 `3` 张公网参考图，结果如下：

- `19/20` 提交成功，返回 `202`
- `1/20` 提交阶段直接因 `SSL_ERROR_SYSCALL` 失败
- `19/20` 成功任务最终全部 `succeeded`
- `19/20` 最终都拿到 `/content -> 302`
- 本轮 `upstream_timeout = 0`
- 本轮 `rate_limited = 0`

轮询层统计：

- 总轮询 `944` 次
- `HTTP 200 = 913`
- `HTTP 000 = 31`
- 受链路层 `000` 影响的任务数：`16`

成功任务的网关耗时：

- 最短 `165s`
- 平均约 `197.68s`
- 最长 `236s`

因此在高频并发、多图参考图场景下，当前最明显的问题不是业务层失败，而是 TLS / 连接层偶发抖动。

同日又用增强版压测脚本做了 `3` 任务、多图参考图小样本复测，结果为：

- `3/3` 提交成功，`3/3` 最终 `succeeded`
- `poll_http_000 = 4`
- `tasks_with_poll_http_000 = 1`
- 成功任务耗时最短 `94s`、平均约 `99.33s`、最长 `109s`

这说明即使并发量降到 `3`，链路层 `SSL_ERROR_SYSCALL` 仍可能偶发出现，但通常可通过继续轮询恢复。

补充说明：

- 上述 live verification 发生在较早一版轮询配置下
- 当前轮询建议已调整为：提交后约 `50s` 再开始第一次轮询，后续固定 `10s`
- 当前常见服务端建议值为 `Retry-After = 10`，批量轮询返回 `next_poll_after_ms = 10000`
- 联调建议应以当前文档为准，而不是以历史 live 样本里出现过的较小轮询值为准

### Async Image Tasks: Batch Polling

`2026-03-22` 又用真实测试 key 做了一轮 batch-get live verification：

- 先真实提交 `3` 笔异步生图任务，三笔都返回 `HTTP 202`
- 立即调用 `POST /v1/tasks/batch-get`，返回 `HTTP 200`
- `items` 中 `3` 个真实任务都处于 `running`
- 同批额外加入的一个假 ID 返回 `status = not_found`
- 返回体顶层 `object = "batch.task.list"`
- 三轮查询里的 `next_poll_after_ms` 都稳定为 `10000`
- `55s` 后再次 batch-get，`3` 笔真实任务仍都为 `running`
- `125s` 后再次 batch-get，`3/3` 都进入 `succeeded`
- 成功任务都在 `items[*].candidates[*].content.parts[*].inlineData.data` 里返回真实图片 URL

成功图片 URL 样本：

- `https://d.uguu.se/ZBvpygmx.png`
- `https://o.uguu.se/yYoXnFwk.png`
- `https://h.uguu.se/mhjCOBJH.png`

本次 `200 OK` 的 batch-get 响应头里没有额外返回 `Retry-After`，因此当前更准确的接口理解是：

- 单任务轮询继续看响应头 `Retry-After`
- 批量轮询优先看响应体 `next_poll_after_ms`

### GPT Image / OpenAI-Style Async Image Tasks

`2026-04-20` 又补做了一轮真实回归。

这轮验证里确认到：

- `POST /v1/images/generations` 可真实提交成功
- 成功样例任务：`img_sqsn753gj4j3ejpy`
- 任务最终状态：`succeeded`
- 成功拿到真实图片 URL：
  `https://o.uguu.se/Awscoxej.png`

成功样例请求特征：

- `model = gpt-image-2`
- 客户端提交字段使用 `image`
- 客户端提交 `response_format = url`

同轮还观察到：

- 某一笔真实请求出现过 `502`
- 第二笔 async 真实任务在关闭调试实例前仍处于 `running`

因此当前更准确的判断是：

- `GPT Image` 异步链路的真实成功样本：**已经确认存在**
- 当前接入链路：**已经确认能跑通**
- “每一笔都已证明稳定成功”：**不能这么写**

文档语义上还应注意：

- 给用户示例时，统一保留客户端请求里的 `image` 写法

### Video Tasks: Sora

- 请求模型：`sora_video2-portrait`
- HTTP：`200`
- 返回 `id` / `task_id`
- 返回 `status = in_progress`

### Main-Site Sync Image Generation

对 `POST https://api.xinbao-ai.com/v1beta/models/gemini-3-pro-image-preview:generateContent`
做过真实请求，但当前只观测到链路层现象：

- 一次 `curl: (35) SSL_ERROR_SYSCALL`
- 一次 `curl: (28) Operation timed out after 25001 milliseconds with 0 bytes received`

这只能说明当前环境或链路层未拿到业务响应，不能据此写成接口语义结论。

## Current Scope Notes

- `Sora` 已有真实创建结果
- `Veo`、`即梦 / 豆包` 已纳入当前文档覆盖范围，但本轮不深挖坏模型细节
- `Grok` 当前未提供独立文档页

## Suggested Next Verifications

如果后续还要补强文档，建议按下面顺序追加验证：

1. 主站同步生图拿到一次业务层响应
2. `Veo` 最小视频任务
3. `即梦 / 豆包` 最小视频任务
