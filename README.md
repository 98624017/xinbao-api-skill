# xinbao-api Skill

Agent skill for integrating Xinbao API.

It covers:

- Multimodal chat via `/v1/chat/completions`
- Gemini-style synchronous image generation
- Gemini async image tasks
- GPT Image / OpenAI-style async image tasks, including `gpt-image-2` and `gpt-image-2-oai`
- Batch task polling via `/v1/tasks/batch-get`
- Video tasks for Sora, Veo, Doubao / Jimeng
- ComfyUI workflow submission through Xinbao video task APIs

## Install

```bash
npx skills add https://github.com/98624017/xinbao-api-skill --skill xinbao-api
```

Or install all skills from this repository:

```bash
npx skills add https://github.com/98624017/xinbao-api-skill
```

## Update

Update an installed copy with:

```bash
npx skills update xinbao-api
```

Version history is tracked in `VERSION`, `CHANGELOG.md`, and Git tags such as `v0.1.0`.

## Example Prompts

- 帮我用心宝 API 接入 GPT Image 异步生图，并用 batch-get 轮询多个任务。
- 生成一个调用 `gpt-image-2-oai` 的 curl，请求里带 `quality` 和 `size`。
- 心宝 Gemini 异步生图可以用哪些 Base URL？轮询应该怎么处理？
- 帮我写 Sora / Veo / 豆包视频任务提交和轮询示例。
- 心宝 ComfyUI workflow 的 `nodeInfoList` 应该怎么传？

## Notes

Image generation endpoints:

- Dedicated async endpoint: `https://async.xinbao-ai.com`
- Main synchronous image endpoint: `https://api.xinbaoai.com`

Async image generation should use `https://async.xinbao-ai.com`. For polling and result retrieval, prefer `polling_url` and `content_url` returned by the submit response.
