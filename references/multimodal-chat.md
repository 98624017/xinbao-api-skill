# Multimodal Chat

## 端点

```text
POST /v1/chat/completions
```

## 用途

用于 OpenAI Chat Completions 兼容的多模态聊天场景，典型输入是：

- 文本
- 图片 URL
- `data:image/...;base64,...`

## 请求字段

- `model`
- `messages`
- `messages[].content[]`
- `max_tokens`
- `temperature`
- `seed`

## 示例

```json
{
  "model": "gemini-3-pro-preview-c",
  "messages": [
    {
      "role": "user",
      "content": [
        { "type": "text", "text": "请描述这张图。" },
        {
          "type": "image_url",
          "image_url": {
            "url": "data:image/jpeg;base64,<BASE64_IMAGE>"
          }
        }
      ]
    }
  ],
  "max_tokens": 1024,
  "temperature": 0.7
}
```

## 返回解析

优先读取：

```text
choices[0].message.content
```

兼容处理：

- 如果是字符串，直接当最终文本
- 如果是数组，拼接其中 `type=text` 的 `text`

## 2026-03-21 实测提示

对 `POST /v1/chat/completions` 做最小真实请求时：

- 请求模型：`gemini-3-pro-preview-c`
- HTTP：`200`
- `choices[0].message.content = "OK"`
- 响应 `model = "gpt-5.2-2025-12-11"`

因此，接入侧不要假设响应里的 `model` 一定等于请求时传入的模型名。

## 常见坑

- 把 `content` 写成对象而不是数组
- base64 图片未带 `data:image/...;base64,` 前缀
- 图片数量超出调用方支持范围
