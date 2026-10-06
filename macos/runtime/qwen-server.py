"""Local OpenAI-compatible Qwen ASR endpoint for Listenote Daily."""

import os

import mlx.core as mx
import mlx_qwen3_asr.server as server
import uvicorn


# Keep MLX allocations below the configured memory budget in long sessions.
mx.set_cache_limit(0)

port = int(os.environ.get("QWEN_PORT", "18765"))
model = os.environ.get("QWEN_MODEL", "moona3k/mlx-qwen3-asr-0.6b-8bit")
app = server.create_app(server.ServerConfig(
    host="127.0.0.1", port=port, api_keys=["listenote-local"], model=model,
))
uvicorn.run(app, host="127.0.0.1", port=port, log_level="warning")
