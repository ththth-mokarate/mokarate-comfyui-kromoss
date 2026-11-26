# Mokarate Kromoss runtime image for SaladCloud.
#
# Merged from Salad's own Dockerfiles (SaladTechnologies/comfyui-api):
#   docker/comfyui.dockerfile (stage 1: ComfyUI on PyTorch)
#   docker/api.dockerfile     (stage 2: comfyui-api wrapper binary)
# Only the versions changed: ComfyUI 0.35.0 -> 0.46.0, api 1.19.0 -> 1.19.2
# (the version in Salad's current image). Torch 2.13.0 / CUDA 13.0 kept
# exactly as Salad's image.
#
# Why 0.46.0: MOSS-Image (and its fine-tune Kromoss) needs ComfyUI >= 0.42.1
# natively (merged Oct 16 2026; v0.42.1 fixes MOSS template crashes).
# Salad's newest comfyui-api image is still 0.35.0, so we build our own.
#
# Runtime-only: no model weights are baked in. The Kromoss files are
# /downloaded into the running container on first start (test step).

ARG base=runtime
ARG pytorch_version=2.13.0
ARG cuda_version=13.0
ARG comfy_version=0.46.0
ARG api_version=1.19.2

FROM pytorch/pytorch:${pytorch_version}-cuda${cuda_version}-cudnn9-${base} AS comfyui

ENV DEBIAN_FRONTEND=noninteractive

ENV PIP_PREFER_BINARY=1

# PyTorch's newer images use Ubuntu's externally managed system Python.
ENV PIP_BREAK_SYSTEM_PACKAGES=1

ENV UV_BREAK_SYSTEM_PACKAGES=1

ENV CMAKE_BUILD_PARALLEL_LEVEL=8

RUN apt-get update && apt-get upgrade -y && apt-get install -y \
  curl \
  git \
  unzip \
  wget \
  && apt clean -y && rm -rf /var/lib/apt/lists/*

# Install comfy-cli, which makes it easy to install custom nodes and other comfy specific functionality.
SHELL ["/bin/bash", "-c"]

RUN pip install --no-cache-dir --upgrade pip
RUN pip install --no-cache-dir uv
RUN uv pip install --no-cache-dir --system "comfy-cli==1.5.1" "huggingface_hub[cli]"

WORKDIR /opt

ARG comfy_version=0.46.0

RUN git clone --depth 1 --branch v${comfy_version} https://github.com/comfyanonymous/ComfyUI.git

WORKDIR /opt/ComfyUI

ARG cuda_version=13.0
ARG torchaudio_version=2.11.0

# Preserve the base image's Torch/CUDA versions when installing dependencies.
# TorchAudio 2.11 supports PyTorch 2.11 and later through its stable ABI.
RUN python -c 'import importlib.metadata as m; print("\n".join(f"{p}=={m.version(p)}" for p in ("torch", "torchvision")))' > /opt/pytorch-constraints.txt
RUN uv pip install --no-cache-dir --system -c /opt/pytorch-constraints.txt "torchaudio==${torchaudio_version}" --index-url https://download.pytorch.org/whl/cu${cuda_version//./}
RUN python -c 'import importlib.metadata as m; print("torchaudio==" + m.version("torchaudio"))' >> /opt/pytorch-constraints.txt
RUN uv pip install --no-cache-dir --system -c /opt/pytorch-constraints.txt -r requirements.txt

ENV COMFY_HOME=/opt/ComfyUI

RUN comfy --skip-prompt tracking disable
RUN comfy --skip-prompt set-default ${COMFY_HOME}

RUN git clone https://github.com/Comfy-Org/ComfyUI-Manager.git ./custom_nodes/ComfyUI-Manager
RUN uv pip install --system --no-cache-dir -c /opt/pytorch-constraints.txt -r ./custom_nodes/ComfyUI-Manager/requirements.txt

ENV MODEL_DIR=${COMFY_HOME}/models
ENV OUTPUT_DIR=${COMFY_HOME}/output
ENV INPUT_DIR=${COMFY_HOME}/input

ENV CMD="comfy --workspace ${COMFY_HOME} launch -- --listen *"
ENV BASE=""

CMD ["bash", "-c", "comfy --workspace ${COMFY_HOME} launch -- --listen '*'"]

FROM comfyui AS api

ENV WORKFLOW_DIR=/workflows
ENV STARTUP_CHECK_MAX_TRIES=30

ARG api_version=1.19.2

ADD https://github.com/SaladTechnologies/comfyui-api/releases/download/${api_version}/comfyui-api .

RUN chmod +x comfyui-api

LABEL com.mokarate.comfy-version="0.46.0"
LABEL com.mokarate.comfyui-api-version="1.19.2"

CMD ["./comfyui-api"]
