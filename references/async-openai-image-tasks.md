# Async OpenAI Image Tasks

## 适用范围

用于 `gpt-image` / OpenAI 风格图片异步任务。

- 文生图
- 图生图
- 多参考图任务
- 统一提交后走 `/v1/tasks/*` 轮询

如果用户口头说的是 `gpt image2`、`gpt-image-2-oai`，这里优先按
“GPT Image 图生图 / 多参考图异步” 理解；接口仍然走：

```text
POST /v1/images/generations
```

## Base URL

```text
https://async.xinbao-ai.com
https://api.xinbaoai.com
```

`https://api.xinbaoai.com` 是异步生图兼容入口。GPT Image / OpenAI 风格异步生图
可以使用与 `https://async.xinbao-ai.com` 完全相同的请求体提交任务。
后续轮询和取结果优先使用提交响应中的 `polling_url`、`content_url`。

## 提交任务

```text
POST /v1/images/generations
```

本文档当前收录的模型包括：

- `gpt-image-2`
- `gpt-image-1`
- `gpt-image-2-oai`

其中：

- `gpt-image-2-oai` 的提交、轮询、结果解析、错误处理，与
  `gpt-image-2` 走同一套机制
- 当前可明确补充的差异是：该模型常用并显式支持 `quality`、`size`
- 因此客户端实现无需拆新任务流，只要在既有
  `POST /v1/images/generations` 请求体上补充字段即可

## 请求体规则

- 必须有 `model`
- 面向客户的调用说明，统一使用 `image`
- `image` 必须是数组
- 每项都必须是绝对 `http/https` URL
- 参考图建议控制在 `6` 张以内；上游可能存在数量限制
- 单个参考图 URL 最长 `4096` 字符
- `response_format` 只接受 `url`
- 如果不传 `response_format`，服务端也会补成 `url`
- 解压后的请求体最大 `2 MB`
- 除上述校验外，其余字段继续往后传

### `gpt-image-2-oai` 补充参数

- `quality`：可选，常见值 `low`、`medium`、`high`
- `size`：可选，表示输出分辨率尺寸
- 若用户指定 `gpt-image-2-oai`，优先原样透传 `quality`、`size`
- 若未指定，按业务默认值处理；文档示例默认使用 `quality = medium`

因此对接建议是：

- 面向 async 接口时，统一传 `image`
- `gpt-image-2-oai` 仍复用同一套轮询与结果解析，不要额外拆分状态机
- 参考图建议 `6` 张以内，避免撞上未公开的上游数量限制

重点：

- 不要把参考图拆成 `image1`、`image2`、`image3`
- 单张参考图也要放进数组

## 典型请求

```json
{
  "model": "gpt-image-2",
  "prompt": "把香蕉产品图改成奶油白背景的电商主图，保留主体结构和材质细节。",
  "image": [
    "https://placehold.co/600x400/png"
  ],
  "size": "1536x1024",
  "quality": "high",
  "response_format": "url"
}
```

`gpt-image-2-oai` 示例：

```json
{
  "model": "gpt-image-2-oai",
  "prompt": "创建图片，图中鞋子的专业商业拍摄，背景干净，材质细节清晰。",
  "quality": "medium",
  "response_format": "url",
  "size": "2048x1152",
  "image": [
    "https://img.cdn1.vip/i/69a3fd7a9d39a_1772354938.webp"
  ]
}
```

## 提交成功返回

提交成功通常是 `202 Accepted`：

```json
{
  "content_url": "/v1/tasks/img_zzq527dlonb4efiu/content",
  "created_at": 1776702935,
  "id": "img_zzq527dlonb4efiu",
  "model": "gpt-image-2",
  "object": "image.task",
  "polling_url": "/v1/tasks/img_zzq527dlonb4efiu",
  "status": "accepted"
}
```

字段解释：

- `id`：任务 ID，后续轮询与 batch-get 都用它
- `status = accepted`：只代表任务已入队，不代表已经开始出图
- `polling_url`：单任务状态查询入口
- `content_url`：首张图直跳入口；任务未完成时不要假定它已可用

## 单任务轮询返回

单任务查询：

```text
GET /v1/tasks/{id}
```

### 已受理但未开始

某些任务在刚提交后，单任务轮询里仍可能短暂看到：

```json
{
  "created_at": 1776702935,
  "id": "img_zzq527dlonb4efiu",
  "model": "gpt-image-2",
  "object": "image.task",
  "status": "accepted"
}
```

说明：

- `accepted` 说明任务已经被系统接收
- 这个阶段通常还没分配到实际执行

### 已排队

如果任务已经进入本地或上游等待队列，可能看到：

```json
{
  "created_at": 1776702935,
  "id": "img_zzq527dlonb4efiu",
  "model": "gpt-image-2",
  "object": "image.task",
  "status": "queued"
}
```

说明：

- `queued` 比 `accepted` 更接近实际执行
- 对客户端来说，`accepted / queued / running` 都属于继续轮询的非终态

### 进行中示例

任务开始执行后，典型返回会变成：

```json
{
  "created_at": 1776702935,
  "id": "img_zzq527dlonb4efiu",
  "model": "gpt-image-2",
  "object": "image.task",
  "status": "running"
}
```

说明：

- `running` 阶段通常还没有 `result`
- 这时如果访问 `content_url`，预期会拿到 `409 task_not_ready`

### 成功示例

成功时，`GET /v1/tasks/{id}` 顶层不是 `candidates`，而是 `result`：

```json
{
  "created_at": 1776693307,
  "finished_at": 1776693320,
  "id": "img_sqsn753gj4j3ejpy",
  "object": "image.task",
  "model": "gpt-image-2",
  "result": {
    "created": 1776693314,
    "data": [
      {
        "url": "https://o.uguu.se/Awscoxej.png"
      }
    ],
    "usage": {
      "input_tokens": 1024,
      "input_tokens_details": {
        "image_tokens": 1000,
        "text_tokens": 24
      },
      "output_tokens": 1024,
      "output_tokens_details": {
        "image_tokens": 1024,
        "text_tokens": 0
      },
      "total_tokens": 2048
    }
  },
  "status": "succeeded"
}
```

### 失败示例

失败时，通常会返回任务状态加错误对象：

```json
{
  "created_at": 1776702935,
  "finished_at": 1776703058,
  "id": "img_xxxxxxxx",
  "object": "image.task",
  "model": "gpt-image-2",
  "status": "failed",
  "error": {
    "code": "upstream_error",
    "message": "upstream request failed"
  }
}
```

说明：

- `failed` 与 `uncertain` 都要继续读取 `error.code / error.message`
- 某些错误消息里还会内嵌一层 JSON 字符串，客户端如果要细分原因，建议再做一次解析尝试

### 不确定示例

如果链路在“请求可能已经发到上游”之后中断，任务可能进入：

```json
{
  "created_at": 1776702935,
  "finished_at": 1776703058,
  "id": "img_xxxxxxxx",
  "object": "image.task",
  "model": "gpt-image-2",
  "status": "uncertain",
  "error": {
    "code": "upstream_transport_uncertain",
    "message": "connection to newapi broke after request dispatch; task result may be uncertain"
  }
}
```

说明：

- `uncertain` 不是普通失败
- 它表示系统无法 100% 断言上游一定没处理成功
- 客户端如果对幂等要求高，建议把这类任务单独记录并人工复核

## 轮询与结果读取

任务查询接口与 Gemini 异步生图共用同一套：

- 单任务：`GET /v1/tasks/{id}`
- 批量查询：`POST /v1/tasks/batch-get`
- 首图跳转：`GET /v1/tasks/{id}/content`

读取规则：

1. 轮询成功后优先取 `result.data[*].url`
2. 如果只要首张图，可直接请求 `GET /v1/tasks/{id}/content`
3. `/content` 成功时返回 `302 Found`，`Location` 指向首张图片 URL
4. 任务未完成时，`/content` 返回 `409 task_not_ready`

`/content` 的典型返回语义可以理解为：

### 首图可用时

```http
HTTP/1.1 302 Found
Location: https://o.uguu.se/Awscoxej.png
```

### 任务未就绪时

```json
{
  "error": {
    "code": "task_not_ready",
    "message": "task is not ready for content redirect"
  }
}
```

## 批量轮询

```text
POST /v1/tasks/batch-get
```

请求体：

```json
{
  "ids": ["img_a", "img_b"]
}
```

约束与 Gemini 异步相同：

- `ids` 必须是非空数组
- 单次最多 `100` 个任务
- 重复 ID 会按首次出现顺序去重
- 不存在或当前 API Key 不可见的任务统一返回 `not_found`
- `next_poll_after_ms` 是服务端建议的下次轮询间隔

成功任务在 batch 响应里同样会带 `result`，不是 `candidates`。

典型 batch-get 响应可以同时混合 `running`、`succeeded`、`not_found`：

```json
{
  "object": "batch.task.list",
  "items": [
    {
      "id": "img_running",
      "object": "image.task",
      "model": "gpt-image-2",
      "created_at": 1776702935,
      "status": "running"
    },
    {
      "id": "img_succeeded",
      "object": "image.task",
      "model": "gpt-image-2",
      "created_at": 1776693307,
      "status": "succeeded",
      "result": {
        "created": 1776693314,
        "data": [
          {
            "url": "https://o.uguu.se/Awscoxej.png"
          }
        ]
      }
    },
    {
      "id": "img_missing",
      "object": "image.task",
      "status": "not_found",
      "error": {
        "code": "not_found",
        "message": "task not found"
      }
    }
  ],
  "next_poll_after_ms": 10000
}
```

批量解析建议：

1. 先按 `id` 建索引
2. 继续轮询 `accepted / queued / running`
3. 终态任务直接移出轮询集合
4. `not_found` 同时覆盖“任务不存在”和“当前 API Key 不可见”

如果 batch 响应里出现失败任务，形态通常与单任务一致，只是嵌在 `items[*]` 里：

```json
{
  "id": "img_failed",
  "object": "image.task",
  "model": "gpt-image-2",
  "status": "failed",
  "error": {
    "code": "upstream_error",
    "message": "..."
  }
}
```

## 状态与轮询节拍

常见状态：

- `accepted`
- `queued`
- `running`
- `succeeded`
- `failed`
- `uncertain`
- `not_found`

推荐把这些状态直接分成两类处理：

- 继续轮询：`accepted`、`queued`、`running`
- 终态停止轮询：`succeeded`、`failed`、`uncertain`、`not_found`

推荐轮询建议：

- 首次轮询可延后约 `50s`
- 后续默认按 `10s` 节拍轮询
- 如果返回更大的 `Retry-After / next_poll_after_ms`，优先遵守更大的值

## `size` 参数规则与常用尺寸

`gpt-image-2-oai` 的 `size` 是输出分辨率枚举字符串。

下面提到的 `1K / 2K / 4K`，按常见生图语境统一理解为**尺寸档位**：

- `1K`：主边大约在 `1024` 左右
- `2K`：主边大约在 `2048` 左右
- `4K`：主边大约在 `3840` 左右

`MP` 只表示总像素量，用来辅助判断清晰度、裁切空间和素材体积。

- 可直接使用：`auto`
- 优先推荐的常见尺寸：
  - `1024x1024`：`1K` 档，约 `1.0MP`，比例 `1:1`，常用于电商主图方图、商品卡片图；非电商也常用于社媒封面、头像封面图
  - `1536x1024`：`1K` 档，约 `1.6MP`，比例 `3:2`，常用于横版商品图、详情头图；非电商也适合内容配图、博客头图
  - `1024x1536`：`1K` 档，约 `1.6MP`，比例 `2:3`，常用于竖版海报图、详情长图；非电商也适合竖版封面、活动海报
  - `2048x2048`：`2K` 档，约 `4.2MP`，比例 `1:1`，常用于高精度电商主图、二次裁切素材；非电商也适合品牌视觉方图
  - `2048x1152`：`2K` 档，约 `2.3MP`，比例 `16:9`，常用于横版 Banner、KV、详情首屏图；非电商也适合官网首屏、演示页头图
  - `3840x2160`：`4K` 档，约 `8.3MP`，比例 `16:9`，常用于大屏横版视觉、首页 KV；非电商也适合投放主视觉、展示屏素材
  - `2160x3840`：`4K` 档，约 `8.3MP`，比例 `9:16`，常用于竖版广告图、竖版海报；非电商也适合开屏图、短视频封面
- 尺寸限制：
  - 最大边长 `<= 3840`
  - 宽高均为 `16` 的倍数
  - 长宽比不超过 `3:1`
  - 总像素数在 `655360` 到 `8294400` 之间

选尺寸时，优先按“目标比例 + 分辨率档位”来选。因为必须满足 `16` 倍数限制，
部分尺寸对理论比例会有轻微取整，这属于正常情况。

### 1K 常用补充尺寸

- `1024x1024`：`1K` 档，约 `1.0MP`，比例 `1:1`，电商主图方图、商品封面；非电商也适合社媒方图
- `1536x1024`：`1K` 档，约 `1.6MP`，比例 `3:2`，横版商品精修图、详情头图；非电商也适合文章头图
- `1024x1536`：`1K` 档，约 `1.6MP`，比例 `2:3`，竖版海报、竖版详情头图；非电商也适合活动海报
- `1152x768`：`1K` 档，约 `0.9MP`，比例 `3:2`，横版产品图、商品展示图；非电商也适合内容配图
- `768x1152`：`1K` 档，约 `0.9MP`，比例 `2:3`，竖版模特图、详情页竖图；非电商也适合图文封面
- `1024x768`：`1K` 档，约 `0.8MP`，比例 `4:3`，说明图、图文详情图；非电商也适合文档插图、课程配图
- `768x1024`：`1K` 档，约 `0.8MP`，比例 `3:4`，竖版说明图、商品卖点图；非电商也适合人物卡片图
- `1280x720`：`1K` 档，约 `0.9MP`，比例 `16:9`，横版横幅、小型 Banner；非电商也适合视频封面
- `720x1280`：`1K` 档，约 `0.9MP`，比例 `9:16`，竖版封面、短内容配图；非电商也适合短视频封面
- `1344x576`：`1K` 档，约 `0.77MP`，比例 `21:9`，超宽氛围图、首屏背景条幅；非电商也适合网页背景横幅

### 2K 常用补充尺寸

- `2048x2048`：`2K` 档，约 `4.2MP`，比例 `1:1`，高精电商主图、可裁切方图；非电商也适合品牌方图主视觉
- `2048x1536`：`2K` 档，约 `3.1MP`，比例 `4:3`，商品对比图、功能说明图；非电商也适合报告配图、演示插图
- `1536x2048`：`2K` 档，约 `3.1MP`，比例 `3:4`，卖点长图、详情竖版图；非电商也适合竖版宣传页
- `2048x1152`：`2K` 档，约 `2.3MP`，比例 `16:9`，首页 Banner、品牌 KV；非电商也适合官网首图、发布页头图
- `1152x2048`：`2K` 档，约 `2.3MP`，比例 `9:16`，竖版广告图、移动端首图；非电商也适合开屏海报
- `2400x1024`：`2K` 档，约 `2.5MP`，比例 `21:9`，超宽横幅、氛围背景图；非电商也适合展示页沉浸背景

### 4K 常用补充尺寸

- `3840x2160`：`4K` 档，约 `8.3MP`，比例 `16:9`，大屏 Banner、官网首屏、投放视觉；非电商也适合展示屏、舞台大屏素材
- `2160x3840`：`4K` 档，约 `8.3MP`，比例 `9:16`，高精竖版广告、竖版开屏图；非电商也适合移动端开屏图
- `3648x2432`：`4K` 档，约 `8.9MP`，比例 `3:2`，高精商品场景图、印刷级横版素材；非电商也适合高精宣传图
- `2432x3648`：`4K` 档，约 `8.9MP`，比例 `2:3`，高精海报图、印刷级竖版素材；非电商也适合印刷海报
- `3328x2496`：`4K` 档，约 `8.3MP`，比例 `4:3`，高精说明图、对比图、详情信息图；非电商也适合演示文稿主图
- `2496x3328`：`4K` 档，约 `8.3MP`，比例 `3:4`，高精卖点图、竖版陈列图；非电商也适合展架海报
- `3840x1648`：`4K` 档，约 `6.3MP`，比例 `21:9`，超宽舞台屏、沉浸式横幅、首屏背景；非电商也适合展厅背景图

### 其他常见比例档位补充

#### `5:4` / `4:5`

- `1024x816`：`1K` 档，约 `0.84MP`，比例约 `5:4`，适合电商卡片图、商品介绍图；非电商也适合社媒信息流图
- `816x1024`：`1K` 档，约 `0.84MP`，比例约 `4:5`，适合电商卖点图、竖版详情插图；非电商也适合社媒竖图
- `2048x1632`：`2K` 档，约 `3.34MP`，比例约 `5:4`，适合高精商品卡片图、说明图
- `1632x2048`：`2K` 档，约 `3.34MP`，比例约 `4:5`，适合高精卖点竖图、详情插页
- `3200x2560`：`4K` 档，约 `8.19MP`，比例 `5:4`，适合高精电商物料、印刷宣传图
- `2560x3200`：`4K` 档，约 `8.19MP`，比例 `4:5`，适合高精竖版宣传图、陈列海报

#### `2:1` / `1:2`

- `1152x576`：`1K` 档，约 `0.66MP`，比例 `2:1`，适合电商横向条幅、品类导航横幅；非电商也适合栏目横幅
- `576x1152`：`1K` 档，约 `0.66MP`，比例 `1:2`，适合电商窄长竖图、移动端导购图；非电商也适合封面条图
- `2048x1024`：`2K` 档，约 `2.10MP`，比例 `2:1`，适合频道 Banner、活动页横幅
- `1024x2048`：`2K` 档，约 `2.10MP`，比例 `1:2`，适合长竖版导购图、移动端活动长图
- `3840x1920`：`4K` 档，约 `7.37MP`，比例 `2:1`，适合超宽首页视觉、展示页横幅
- `1920x3840`：`4K` 档，约 `7.37MP`，比例 `1:2`，适合高精竖版海报、开屏长图

#### `5:3` / `3:5`

- `1280x768`：`1K` 档，约 `0.98MP`，比例 `5:3`，适合电商横版氛围图、商品故事图；非电商也适合博客头图
- `768x1280`：`1K` 档，约 `0.98MP`，比例 `3:5`，适合电商竖版卖点图；非电商也适合宣传封面
- `2560x1536`：`2K` 档，约 `3.93MP`，比例 `5:3`，适合高精横版商品视觉、品牌头图
- `1536x2560`：`2K` 档，约 `3.93MP`，比例 `3:5`，适合高精竖版物料、长页封面
- `3680x2208`：`4K` 档，约 `8.13MP`，比例 `5:3`，适合大幅横版宣传图、发布页视觉
- `2208x3680`：`4K` 档，约 `8.13MP`，比例 `3:5`，适合高精竖版活动海报、导视图

#### `7:5` / `5:7`

- `1120x800`：`1K` 档，约 `0.90MP`，比例 `7:5`，适合电商图文卡片、功能介绍图；非电商也适合课程配图
- `800x1120`：`1K` 档，约 `0.90MP`，比例 `5:7`，适合电商竖版说明图；非电商也适合活动招贴图
- `2240x1600`：`2K` 档，约 `3.58MP`，比例 `7:5`，适合高精图文信息图、商品功能页
- `1600x2240`：`2K` 档，约 `3.58MP`，比例 `5:7`，适合高精竖版宣传页、活动页封面
- `3360x2400`：`4K` 档，约 `8.06MP`，比例 `7:5`，适合高精说明海报、展示物料
- `2400x3360`：`4K` 档，约 `8.06MP`，比例 `5:7`，适合高精竖版海报、印刷宣传页

#### `1.91:1` / `1:1.91`

- `1216x640`：`1K` 档，约 `0.78MP`，比例约 `1.9:1`，适合电商分享卡片图；非电商也适合社媒分享图、Open Graph 卡片图
- `640x1216`：`1K` 档，约 `0.78MP`，比例约 `1:1.9`，适合窄长竖卡片图；非电商也适合移动端封面
- `2432x1280`：`2K` 档，约 `3.11MP`，比例约 `1.9:1`，适合高精分享横图、活动分享卡
- `1280x2432`：`2K` 档，约 `3.11MP`，比例约 `1:1.9`，适合高精竖版分享图
- `3840x2016`：`4K` 档，约 `7.74MP`，比例约 `1.9:1`，适合高精横版分享主图、大型横向卡片图
- `2016x3840`：`4K` 档，约 `7.74MP`，比例约 `1:1.9`，适合高精竖版展示图、移动端开屏图

#### `3:1` / `1:3`

- `1536x512`：`1K` 档，约 `0.79MP`，比例 `3:1`，适合电商超长横幅、频道头部条幅；非电商也适合网页顶部横幅
- `512x1536`：`1K` 档，约 `0.79MP`，比例 `1:3`，适合电商超长竖图、侧边导购图；非电商也适合窄长竖版视觉
- `3072x1024`：`2K` 档，约 `3.15MP`，比例 `3:1`，适合大型横向促销条幅、沉浸式横版视觉
- `1024x3072`：`2K` 档，约 `3.15MP`，比例 `1:3`，适合超长活动页竖图、移动端长屏海报
- `3840x1280`：`4K` 档，约 `4.92MP`，比例 `3:1`，适合超宽舞台屏、展厅横幅、超宽首屏背景
- `1280x3840`：`4K` 档，约 `4.92MP`，比例 `1:3`，适合超长竖版导视图、展架画面

### 电商常见尺寸建议

如果用户没给明确像素，但场景明显是电商图，可优先推荐：

- 电商主图方图：`1024x1024`、`2048x2048`
  常见参数：`size=1024x1024` 或 `size=2048x2048`
- 横版详情头图 / Banner：`1536x1024`、`2048x1152`、`3840x2160`
  常见参数：`size=1536x1024`、`size=2048x1152`
- 竖版详情图 / 海报图：`1024x1536`、`1536x2048`、`2160x3840`
  常见参数：`size=1024x1536`、`size=1536x2048`
- 商品对比图 / 说明图：`2048x1536`、`1536x2048`
  常见参数：`size=2048x1536`、`size=1536x2048`
- 超宽氛围图 / 首屏视觉：`2400x1024`、`3840x1648`
  常见参数：`size=2400x1024`、`size=3840x1648`

经验建议：

- 要兼顾成本与清晰度，默认先用 `1024x1024`、`1536x1024`、`1024x1536`
- 要做高质感商品精修、裁切留白、二次排版，优先 `2K`
- 要做大屏投放、首页 KV、重裁切素材，再考虑 `4K`

## 常见错误码

- `missing_api_key`
- `invalid_model`
- `invalid_reference_image_url`
- `invalid_reference_image_scheme`
- `invalid_response_format`
- `request_too_large`
- `queue_full`
- `task_not_ready`
- `rate_limited`
- `not_found`

如果任务已经进入 `failed / uncertain`，继续看响应里的：

```json
{
  "error": {
    "code": "...",
    "message": "..."
  }
}
```
