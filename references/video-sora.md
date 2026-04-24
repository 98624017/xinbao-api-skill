# Video Tasks: Sora

## 当前范围

此页只讲 `Sora`。相关模型另见 `video-veo.md`、`video-doubao.md`。

## 统一入口

```text
POST /v1/videos
GET /v1/videos/{id}
```

## Sora 示例

```json
{
  "model": "sora_video2-portrait",
  "prompt": "让这张图动起来：微风吹动、镜头轻微推近、整体自然稳定。",
  "image": "https://example.com/reference.jpg"
}
```

## 2026-03-21 实测创建结果

使用测试 key 对 `POST /v1/videos` 发起 `sora_video2-portrait` 图生视频请求，服务端返回
`HTTP 200`，并给出如下进行中任务：

```json
{
  "id": "task_nVhsslv7LlnFXCPzFg51LsgzyW7Itzjv",
  "task_id": "task_nVhsslv7LlnFXCPzFg51LsgzyW7Itzjv",
  "status": "in_progress"
}
```

这说明当前链路至少可以成功创建 `Sora` 任务，后续继续轮询即可。

## Pro 参数

`sora-2-pro` 建议同时传：

- `seconds`：`10 | 15 | 25`
- `size`：`1792x1024` 或 `1024x1792`

## 轮询建议

- 前几次可采用 `10s -> 25s -> 25s`
- 之后固定 `10s`
- 普通任务超时：`300s~600s`
- 高耗时任务超时：`600s~1200s`

## 兼容状态值

完成态：

- `completed`
- `succeeded`
- `done`

失败态：

- `failed`
- `error`
- `canceled`
- `cancelled`

## 结果解析

按顺序尝试：

- `video_url`
- `data.video_url`
- `content.video_url`
- `content.url`
- `detail.video_url`

## 注意事项

- 输入图必须公网可访问
- 不要把 `progress` 当唯一完成依据
- 拿到最终 URL 后建议尽快转存到自有存储
