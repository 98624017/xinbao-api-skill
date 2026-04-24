#!/usr/bin/env bash
set -euo pipefail

: "${XINBAO_API_KEY:?Set XINBAO_API_KEY first}"

MAIN_BASE="${MAIN_BASE:-https://api.xinbao-ai.com}"
ASYNC_BASE="${ASYNC_BASE:-https://async.xinbao-ai.com}"

auth_header() {
  printf 'Authorization: Bearer %s' "$XINBAO_API_KEY"
}

chat_completion() {
  curl -sS "${MAIN_BASE}/v1/chat/completions" \
    -H "$(auth_header)" \
    -H 'Content-Type: application/json' \
    -d '{
      "model": "gemini-3-pro-preview-c",
      "messages": [
        {
          "role": "user",
          "content": [
            { "type": "text", "text": "请只回复 OK" }
          ]
        }
      ],
      "max_tokens": 16,
      "temperature": 0.1
    }'
}

sync_image_generate() {
  curl -sS "${MAIN_BASE}/v1beta/models/gemini-3-pro-image-preview:generateContent" \
    -H "$(auth_header)" \
    -H 'Content-Type: application/json' \
    -d '{
      "contents": [
        {
          "role": "user",
          "parts": [
            { "text": "生成一张简洁的产品海报，背景干净，光线自然。" }
          ]
        }
      ],
      "generationConfig": {
        "responseModalities": ["IMAGE"]
      }
    }'
}

async_image_submit() {
  curl -sS "${ASYNC_BASE}/v1beta/models/gemini-3-pro-image-preview:generateContent" \
    -H "$(auth_header)" \
    -H 'Content-Type: application/json' \
    -d '{
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
    }'
}

async_gpt_image_submit() {
  curl -sS "${ASYNC_BASE}/v1/images/generations" \
    -H "$(auth_header)" \
    -H 'Content-Type: application/json' \
    -d '{
      "model": "gpt-image-2",
      "prompt": "生成一张黄色香蕉产品图，白底，简洁棚拍风格。",
      "image": [
        "https://placehold.co/600x400/png"
      ],
      "size": "1536x1024",
      "quality": "high",
      "response_format": "url"
    }'
}

async_gpt_image_oai_submit() {
  curl -sS "${ASYNC_BASE}/v1/images/generations" \
    -H "$(auth_header)" \
    -H 'Content-Type: application/json' \
    -d '{
      "model": "gpt-image-2-oai",
      "prompt": "创建图片，图中鞋子的专业商业拍摄，背景干净，材质细节清晰。",
      "quality": "medium",
      "response_format": "url",
      "size": "2048x1152",
      "image": [
        "https://img.cdn1.vip/i/69a3fd7a9d39a_1772354938.webp"
      ]
    }'
}

async_image_poll() {
  local task_id="${1:?usage: async_image_poll <task_id>}"
  curl -sS "${ASYNC_BASE}/v1/tasks/${task_id}" \
    -H "$(auth_header)"
}

async_image_batch_get() {
  if [[ "$#" -lt 1 ]]; then
    echo "usage: async_image_batch_get <task_id> [task_id ...]" >&2
    return 1
  fi

  local first=1
  local payload='{"ids":['
  local task_id
  for task_id in "$@"; do
    if [[ "${first}" -eq 0 ]]; then
      payload+=','
    fi
    payload+="\"${task_id}\""
    first=0
  done
  payload+=']}'

  curl -sS "${ASYNC_BASE}/v1/tasks/batch-get" \
    -H "$(auth_header)" \
    -H 'Content-Type: application/json' \
    -d "${payload}"
}

sora_video_create() {
  curl -sS "${MAIN_BASE}/v1/videos" \
    -H "$(auth_header)" \
    -H 'Content-Type: application/json' \
    -d '{
      "model": "sora_video2-portrait",
      "prompt": "让这张图动起来：微风吹动、镜头轻微推近、整体自然稳定。",
      "image": "https://example.com/reference.jpg"
    }'
}

veo_video_create() {
  curl -sS "${MAIN_BASE}/v1/videos" \
    -H "$(auth_header)" \
    -H 'Content-Type: application/json' \
    -d '{
      "model": "veo_3_1",
      "prompt": "生成一段 16:9 的产品短视频：镜头环绕、光线柔和、背景简洁，风格偏真实。",
      "aspect_ratio": "16:9",
      "images": [
        "https://example.com/veo_ref_1.jpg",
        "https://example.com/veo_ref_2.jpg",
        "https://example.com/veo_ref_3.jpg"
      ]
    }'
}

doubao_video_create() {
  curl -sS "${MAIN_BASE}/v1/videos" \
    -H "$(auth_header)" \
    -H 'Content-Type: application/json' \
    -d '{
      "model": "doubao-seedance-1-5-pro-251215",
      "prompt": "生成一段产品广告短视频 -ratio=16:9 -resolution=720p -generate_audio=true -camera_fixed=false",
      "seconds": "8",
      "input_reference": "[\"https://example.com/first.jpg\",\"https://example.com/last.jpg\"]"
    }'
}

video_poll() {
  local task_id="${1:?usage: video_poll <task_id>}"
  curl -sS "${MAIN_BASE}/v1/videos/${task_id}" \
    -H "$(auth_header)"
}

comfyui_task_create() {
  curl -sS "${MAIN_BASE}/v1/videos" \
    -H "$(auth_header)" \
    -H 'Content-Type: application/json' \
    -d '{
      "model": "gqfd",
      "prompt": ".",
      "nodeInfoList": [
        {
          "nodeId": "308",
          "fieldName": "image",
          "fieldValue": "https://o.uguu.se/tZuuEUzB.jpg",
          "description": "upload image"
        },
        {
          "nodeId": "306",
          "fieldName": "value",
          "fieldValue": "false",
          "description": "enable 8k"
        }
      ]
    }'
}

case "${1:-}" in
  chat) chat_completion ;;
  sync-image) sync_image_generate ;;
  async-image-submit) async_image_submit ;;
  async-gpt-image-submit) async_gpt_image_submit ;;
  async-gpt-image-oai-submit) async_gpt_image_oai_submit ;;
  async-image-poll) async_image_poll "${2:-}" ;;
  async-image-batch-get) shift; async_image_batch_get "$@" ;;
  sora-video) sora_video_create ;;
  veo-video) veo_video_create ;;
  doubao-video) doubao_video_create ;;
  video-poll) video_poll "${2:-}" ;;
  comfyui) comfyui_task_create ;;
  *)
    cat <<'EOF'
Usage:
  XINBAO_API_KEY=... ./scripts/xinbao_curl_examples.sh chat
  XINBAO_API_KEY=... ./scripts/xinbao_curl_examples.sh sync-image
  XINBAO_API_KEY=... ./scripts/xinbao_curl_examples.sh async-image-submit
  XINBAO_API_KEY=... ./scripts/xinbao_curl_examples.sh async-gpt-image-submit
  XINBAO_API_KEY=... ./scripts/xinbao_curl_examples.sh async-gpt-image-oai-submit
  XINBAO_API_KEY=... ./scripts/xinbao_curl_examples.sh async-image-poll <task_id>
  XINBAO_API_KEY=... ./scripts/xinbao_curl_examples.sh async-image-batch-get <task_id> [task_id ...]
  XINBAO_API_KEY=... ./scripts/xinbao_curl_examples.sh sora-video
  XINBAO_API_KEY=... ./scripts/xinbao_curl_examples.sh veo-video
  XINBAO_API_KEY=... ./scripts/xinbao_curl_examples.sh doubao-video
  XINBAO_API_KEY=... ./scripts/xinbao_curl_examples.sh video-poll <task_id>
  XINBAO_API_KEY=... ./scripts/xinbao_curl_examples.sh comfyui
EOF
    ;;
esac
