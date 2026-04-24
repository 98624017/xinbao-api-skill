# Video Tasks: Veo

## 统一入口

```text
POST /v1/videos
GET /v1/videos/{id}
```

## 适用模型

- `veo_3_1`
- `veo_3_1-fast`

## 关键参数

- `aspect_ratio`：`16:9` 或 `9:16`
- `images`：最多 `3` 张

多图语义：

- `1` 张：图生视频
- `2` 张：首尾帧
- `3` 张：元素参考模式

## 请求示例

```json
{
  "model": "veo_3_1",
  "prompt": "生成一段 16:9 的产品短视频：镜头环绕、光线柔和、背景简洁，风格偏真实。",
  "aspect_ratio": "16:9",
  "images": [
    "https://example.com/veo_ref_1.jpg",
    "https://example.com/veo_ref_2.jpg",
    "https://example.com/veo_ref_3.jpg"
  ]
}
```

## 结果解析

完成态后按顺序尝试：

- `video_url`
- `content.video_url`
- `content.url`
- `detail.video_url`

## 注意事项

- `images` 超过 `3` 张通常会失败
- 输入图顺序会影响首尾帧和运动连续性
- 本轮不深挖 Veo 的坏法细节；若线上失败，以实时返回为准
