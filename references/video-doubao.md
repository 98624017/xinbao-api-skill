# Video Tasks: 即梦 / 豆包

## 统一入口

```text
POST /v1/videos
GET /v1/videos/{id}
```

## 适用模型

- `doubao-seedance-1-5-pro-251215`

## 参数规则

- `seconds`：仅支持 `4~12` 的整数字符串
- `input_reference`：最多 `2` 图

`input_reference` 规则：

- `0` 图：不传该字段
- `1` 图：传单个 URL 字符串
- `2` 图：字段值仍然是 JSON 数组文本字符串

## 请求示例

```json
{
  "model": "doubao-seedance-1-5-pro-251215",
  "prompt": "生成一段产品广告短视频 -ratio=16:9 -resolution=720p -generate_audio=true -camera_fixed=false",
  "seconds": "8",
  "input_reference": "[\"https://example.com/first.jpg\",\"https://example.com/last.jpg\"]"
}
```

## Prompt 扩展参数

- `-ratio=21:9 | 16:9 | 4:3 | 1:1 | 3:4 | 9:16`
- `-resolution=480p | 720p`
- `-generate_audio=true|false`
- `-camera_fixed=true|false`

## 注意事项

- `seconds` 请严格使用支持范围
- 双图场景下，`input_reference` 很容易写错，建议由代码生成
- 本轮不深挖豆包接口的坏法细节；若线上失败，以实时返回为准
