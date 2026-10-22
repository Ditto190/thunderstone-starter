# Portable Linux env for validate/edit. My Machines worker + Computer Use stay on the Grok VM.
FROM mcr.microsoft.com/devcontainers/base:bookworm

ARG NODE_MAJOR=22
ENV DEBIAN_FRONTEND=noninteractive
ENV SKIP_CURSOR_INSTALL=1

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    bash \
    tmux \
    git \
    curl \
    ca-certificates \
    unzip \
    zip \
    jq \
    ripgrep \
    fzf \
    python3 \
    rclone \
    shellcheck \
    build-essential \
    tar \
    xz-utils \
    util-linux \
    gnupg \
  && curl -fsSL "https://deb.nodesource.com/setup_${NODE_MAJOR}.x" | bash - \
  && apt-get install -y --no-install-recommends nodejs \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /workspaces/thunderstone-starter
