# Image Generation

## 主站同步生图

同步生图走主站：

```text
POST https://api.xinbao-ai.com/v1beta/models/{model}:generateContent
```

## 当前文档示例模型

- `gemini-3-pro-image-preview`

## 关键字段

- `contents[].parts[].text`
- `contents[].parts[].inlineData`
- `generationConfig.responseModalities=["IMAGE"]`
- `generationConfig.imageConfig.output`

## 说明

- 同步接口适合短耗时、直接回图场景
- 同步请求成功通常返回 `200`
- 图片结果位于 `candidates[*].content.parts[*].inlineData`

## 返回解析

优先读取：

```text
candidates[*].content.parts[*].inlineData
```

处理规则：

1. 检查 `mimeType` 是否是 `image/*`
2. 读取 `inlineData.data`
3. 若值以 `http://` 或 `https://` 开头，当作图片 URL
4. 否则按 base64 图片处理

## 输入建议

- 大图优先用公网 URL
- 小图或临时流程可用 base64
- 保留正确的 `mimeType`
- 如需更稳定的后台任务流，改走异步生图


## 接入建议

默认优先建议使用异步生图任务流，避免网络差、耗时长或长连接中断导致失败。
只有用户明确要求同步返回，或业务场景必须同步等待结果时，才使用本页同步生图入口。
`https://api.xinbaoai.com` 只命名为同步生图入口，不要叫异步兼容入口。
