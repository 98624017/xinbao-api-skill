# ComfyUI Workflows

## 协议说明

ComfyUI 特殊工作流不是独立协议，而是复用标准视频任务流：

```text
POST /v1/videos
GET /v1/videos/{id}
```

## 适用场景

- 高清放大
- 特定工作流节点输入
- 通过 `nodeInfoList` 传递节点值的任务

## 核心差异

- 请求体必须包含 `nodeInfoList`
- 不同工作流使用不同的 `model`、`nodeId`、`fieldName`
- 结果通常位于 `results[*].url`

## 示例

```json
{
  "model": "gqfd",
  "prompt": ".",
  "nodeInfoList": [
    {
      "nodeId": "308",
      "fieldName": "image",
      "fieldValue": "https://o.uguu.se/tZuuEUzB.jpg",
      "description": "上传图片"
    },
    {
      "nodeId": "306",
      "fieldName": "value",
      "fieldValue": "false",
      "description": "开启8K，默认4K"
    }
  ]
}
```

## 创建成功响应

```json
{
  "id": "2013530038900760577",
  "status": "queued",
  "progress": 0,
  "created_at": 1768897945
}
```

## 轮询中的兼容字段

- `status`
- `progress`
- `taskId`
- `taskStatus`
- `results`

## 完成态结果

遍历：

```text
results[*].url
```

高清放大场景通常只输出单图，可直接取 `results[0].url`。

## 注意事项

- `prompt` 必须保留，即使只是占位字符
- `nodeInfoList` 不能跨工作流硬编码复用
- 第三方结果链接建议尽快转存
