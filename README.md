# mokarate-comfyui-kromoss

ComfyUI 0.46.0 + comfyui-api 1.19.2 **runtime** image for SaladCloud GPU
generation, built for the Kromoss (MOSS-Image) test.

Why a custom image: MOSS-Image needs ComfyUI >= 0.42.1 natively (merged
Oct 16 2026; v0.42.1 fixes MOSS template crashes), and Salad's newest
comfyui-api image is still ComfyUI 0.35.0, which cannot run it. The
Dockerfile merges Salad's own Dockerfiles
(SaladTechnologies/comfyui-api: `docker/comfyui.dockerfile` +
`docker/api.dockerfile`); only the versions changed — ComfyUI 0.35.0 ->
0.46.0, api 1.19.0 -> 1.19.2. Torch 2.13.0 / CUDA 13.0 are kept exactly
as in Salad's image.

Runtime-only: no model weights are baked in. The Kromoss files
(`diffusion_models/kromoss_int8_convrot.safetensors`,
`text_encoders/qwen3.5_9b_w4a8_gptq.safetensors`,
`vae/flux2-vae_small.safetensors`, `8-steps-dmd2-lora.safetensors`) are
/downloaded into the running container on first start, the same way the
old FLUX group works.

Built by GitHub Actions (`.github/workflows/build.yml`): plain
`docker build` + push to GHCR, then verification — manifest/config
(labels, Cmd, WorkingDir, MODEL_DIR, size < 35 GB compressed), plus a
`docker run` check from inside the image that the ComfyUI checkout is
exactly the v0.46.0 tag and that the `moss_image` CLIP type exists.

Result: `ghcr.io/ththth-mokarate/mokarate-comfyui-kromoss:runtime`

Salad group parameters for the test (mirroring `image-and-video-chroma`):
replicas 2, priority high, autostart false, readiness probe GET /ready
(initial_delay_seconds 300), port 3000, gateway auth on, no command
override (the image's own `CMD ["./comfyui-api"]` starts the API).
