# Async Gemini Image Tasks

## 说明

本页只描述 Gemini 原生异步生图：

```text
POST /v1beta/models/{model}:generateContent
```

如果你要接的是 `gpt-image` / OpenAI 风格异步图片任务，请改看
`references/async-openai-image-tasks.md`，不要直接复用本页的
`contents + generationConfig` 请求体。

## 适用范围

用于耗时较长的生图任务。流程是先提交任务，再按单任务或批量方式轮询结果。

## Base URL

```text
https://async.xinbao-ai.com
```

Gemini 异步生图只按异步任务流描述，提交后轮询和取结果优先使用提交响应中的 `polling_url`、`content_url`。
`https://api.xinbaoai.com` 是主站同步生图入口，不要写成异步生图入口。

## 提交任务

```text
POST /v1beta/models/{model}:generateContent
```

## 整体流程

1. `POST /v1beta/models/{model}:generateContent` 提交任务
2. 读取返回中的 `id`、`polling_url`、`content_url`
3. 单任务用 `GET /v1/tasks/{id}` 查询状态
4. 多个进行中任务改用 `POST /v1/tasks/batch-get`
5. 成功后读取 `candidates[*].content.parts[*].inlineData.data`
6. 或直接访问 `GET /v1/tasks/{id}/content`

## 关键约束

- 最终输出必须解析为 `output=url`
- 参考图只接受公网 `http/https` URL
- 参考图最多 `8` 张
- 提示词总文本长度最多 `4000` 字符
- 解压后的请求体最多 `2 MB`

## 典型请求

```json
{
  "contents": [
    {
      "role": "user",
      "parts": [
        { "text": "生成一张黄色香蕉产品图，纯色背景，棚拍光效。" }
      ]
    }
  ],
  "generationConfig": {
    "responseModalities": ["IMAGE"],
    "imageConfig": {
      "output": "url"
    }
  }
}
```

## 提交成功后读取

- `id`
- `polling_url`
- `content_url`
- `status`

典型状态初值：

- `accepted`

## 单任务轮询

```text
GET /v1/tasks/{id}
```

状态集合：

- `accepted`
- `queued`
- `running`
- `succeeded`
- `failed`
- `uncertain`

推荐节奏：

- 常见生图耗时约 `60s` 到 `300s`
- 推荐客户端在提交后先等待约 `50s` 再开始第一次轮询
- 之后按固定 `10s` 节拍轮询
- 当前常见服务端配置 `Retry-After = 10`
- 如果服务端返回更大的 `Retry-After`，优先遵守更大的值
- 总超时建议 `1200s`
- 并发场景下对 `HTTP 000 / SSL_ERROR_SYSCALL` 先退避重试

## 批量轮询

```text
POST /v1/tasks/batch-get
```

请求体：

```json
{
  "ids": ["img_a", "img_b", "img_c"]
}
```

关键约束：

- `ids` 必须是非空数组
- 单次最多查询 `100` 个任务
- 重复 ID 会按首次出现顺序去重
- 只能返回当前 `Authorization` 对应可见的任务
- 不存在或当前 API Key 不可见的任务都会统一返回 `not_found`
- `items[*]` 字段风格尽量与单任务接口保持一致

返回关键字段：

- `object = batch.task.list`
- `items[*]`：每个任务的状态快照
- `next_poll_after_ms = 10000`，表示当前常见建议下一个批量轮询周期为 `10s`

推荐节奏：

- 多个进行中任务应尽量对齐到统一节拍
- 推荐固定按 `10s` 一个轮询周期发送 batch 请求
- 每轮只查询仍处于 `accepted / queued / running` 的任务
- 如果任务总数超过 `100`，请拆成多个 batch，并保持在同一个轮询周期里发出
- 如果服务端返回更大的 `next_poll_after_ms`，优先遵守更大的值
- 同一个 batch 不要高频重复查询，否则仍可能触发 `429 rate_limited`

实测补充（`2026-03-22`）：

- 真实提交 `3` 笔任务后，立即调用一次 batch-get，`3` 笔都返回 `running`
- 同批再放入 `1` 个假 ID，返回 `status = not_found`
- `next_poll_after_ms` 三轮都稳定为 `10000`
- `55s` 后再查，`3` 笔仍为 `running`
- `125s` 后再查，`3/3` 都进入 `succeeded`
- 成功任务都在 `items[*].candidates[*].content.parts[*].inlineData.data` 中带回图片 URL
- 本次 `200 OK` 的 batch-get 响应头里未观测到额外 `Retry-After`

## 2026-03-21 实测现象

真实请求返回过以下链路：

- 提交任务：`HTTP 202`
- 提交成功体包含：

```json
{
  "id": "img_ad66v4mnqyzdtfw4",
  "object": "image.task",
  "model": "gemini-3-pro-image-preview",
  "status": "accepted",
  "polling_url": "/v1/tasks/img_ad66v4mnqyzdtfw4",
  "content_url": "/v1/tasks/img_ad66v4mnqyzdtfw4/content"
}
```

- 立即轮询：`HTTP 200`，`status = running`
- 立即访问 `/content`：`HTTP 409 task_not_ready`
- 稍后轮询：可能进入 `failed/upstream_timeout`

同日再次并行提交 `4` 笔最小文本生图任务时，观察到：

- `4/4` 提交成功，全部返回 `202`
- 立即轮询时全部为 `running`
- 最终 `4/4` 都进入 `succeeded`
- `/content` 最终返回 `302`，跳转到真实图片 URL

这说明当前异步生图并不是“只能失败”，更准确的结论是：成功和上游超时两种结果都真实存在。

同日再做 `20` 并发、多图参考图压测时，观察到：

- 每个任务都带 `3` 张公网参考图
- `19/20` 提交成功，`19/20` 最终 `succeeded`
- 成功任务的 `/content` 全部返回 `302`
- 本轮没有出现 `rate_limited`
- 本轮没有出现 `upstream_timeout`
- 但提交和轮询过程中多次出现 `SSL_ERROR_SYSCALL`
- 轮询总次数 `944`
- 其中 `HTTP 200 = 913`
- 其中 `HTTP 000 = 31`
- 受 `HTTP 000` 影响的任务数为 `16`
- 成功任务网关耗时最短 `165s`、平均约 `197.68s`、最长 `236s`

因此高并发多图场景下，当前主要风险更偏向链路层抖动，而不是业务层统一失败。

说明：

- 上述 live verification 是历史样本，不要把旧样本里曾出现过的较小轮询值当成当前推荐值
- 当前建议仍以 `50s` 首轮询、后续 `10s` 轮询为准
- 当前常见服务端建议值是 `Retry-After = 10`、`next_poll_after_ms = 10000`

## 压测脚本

skill 包内附带：

```text
scripts/run_xinbao_async_pressure_test.sh
```

它默认执行异步生图并发压测，并为每个任务携带 `3` 张公网参考图，同时汇总：

- `submit_http_000`
- `poll_http_000`
- `tasks_with_poll_http_000`
- 成功任务耗时统计

## 结果解析

成功后优先读取：

```text
candidates[*].content.parts[*].inlineData.data
```

这里的 `data` 预期是图片 URL。

如只要首张图，可直接访问：

```text
GET /v1/tasks/{id}/content
```

行为：

- 成功时 `302 Found`
- `Location` 指向首张图 URL
- 未完成时返回 `409 task_not_ready`

## 最近任务列表

```text
GET /v1/tasks
```

常用参数：

- `days`：默认 `3`，最大 `3`
- `limit`：默认 `20`，最大 `100`
- `before_created_at` / `before_id`：分页游标

## 常见错误码

- `missing_api_key`
- `output_must_be_url`
- `invalid_reference_image_url`
- `invalid_reference_image_scheme`
- `too_many_reference_images`
- `prompt_too_long`
- `request_too_large`
- `queue_full`
- `rate_limited`
- `task_not_ready`
- `upstream_timeout`
