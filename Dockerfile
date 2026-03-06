FROM nvidia/cuda:13.0.0-runtime-ubuntu24.04

ARG PYTHON_VERSION=3.12
ARG REFORGE_VERSION=newmain_newforge
ARG TORCH_VERSION=2.6.0
ARG APP_USER=runpod
ARG APP_UID=1000
ARG APP_GID=1000

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    XPU_TARGET=NVIDIA_GPU

ENV APP_USER=${APP_USER} \
    APP_UID=${APP_UID} \
    APP_GID=${APP_GID}

ENV VENV_DIR=/opt/venv
ENV REFORGE_VENV=/opt/venv/stable-diffusion-webui
ENV JUPYTER_VENV=/opt/venv/jupyter
ENV TORCH_VERSION=${TORCH_VERSION}
ENV PATH="${REFORGE_VENV}/bin:${JUPYTER_VENV}/bin:${PATH}"

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    ffmpeg \
    git \
    libgl1 \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    python${PYTHON_VERSION} \
    python${PYTHON_VERSION}-venv \
    sudo \
    tzdata \
    wget \
    && rm -rf /var/lib/apt/lists/*

RUN python${PYTHON_VERSION} -m ensurepip --upgrade && \
    python${PYTHON_VERSION} -m pip install --no-cache-dir --upgrade pip setuptools wheel

RUN ln -sf "/usr/bin/python${PYTHON_VERSION}" /usr/local/bin/python3 && \
    ln -sf "/usr/bin/python${PYTHON_VERSION}" /usr/local/bin/python

RUN python${PYTHON_VERSION} -m venv "${REFORGE_VENV}" && \
    python${PYTHON_VERSION} -m venv "${JUPYTER_VENV}"

RUN groupadd --gid "${APP_GID}" "${APP_USER}" && \
    useradd --uid "${APP_UID}" --gid "${APP_GID}" --create-home --shell /bin/bash "${APP_USER}" && \
    mkdir -p /workspace && \
    chown -R "${APP_UID}:${APP_GID}" /workspace /opt/venv

WORKDIR /workspace

RUN "${JUPYTER_VENV}/bin/pip" install --no-cache-dir jupyterlab notebook numpy pandas

RUN git clone --depth 1 --branch "${REFORGE_VERSION}" \
    https://github.com/Panchovix/stable-diffusion-webui-reForge.git \
    /workspace/stable-diffusion-webui

RUN chown -R "${APP_UID}:${APP_GID}" /workspace /opt/venv

WORKDIR /workspace/stable-diffusion-webui


RUN printf '\n%s\n' \
    'install_dir="/workspace"' \
    'venv_dir="/opt/venv/stable-diffusion-webui"' \
    'export COMMANDLINE_ARGS="--listen --host 0.0.0.0"' \
    'export TORCH_COMMAND="pip install torch=='"${TORCH_VERSION}"' --extra-index-url https://download.pytorch.org/whl/cu124"' \
    'export REQS_FILE="requirements_versions.txt"' \
    >> /workspace/stable-diffusion-webui/webui-user.sh

COPY <<'EOF' /start.sh
#!/bin/bash
set -euo pipefail
umask 002

APP_USER="${APP_USER:-runpod}"
APP_UID="${APP_UID:-1000}"

# Some runtimes force UID 0 at startup. Re-exec as app user so webui.sh doesn't abort.
if [ "$(id -u)" -eq 0 ] && [ "${1:-}" != "--as-user" ]; then
    if ! id -u "${APP_USER}" >/dev/null 2>&1; then
        useradd --uid "${APP_UID}" --create-home --shell /bin/bash "${APP_USER}" || true
    fi
    chown -R "${APP_USER}:${APP_USER}" /workspace /opt/venv
    exec sudo -E -H -u "${APP_USER}" /start.sh --as-user
fi

echo "Starting ReForge setup"
echo "Python: $("${REFORGE_VENV}/bin/python" --version)"

if command -v nvidia-smi >/dev/null 2>&1; then
    export XPU_TARGET=NVIDIA_GPU
elif [ -d "/dev/dri" ]; then
    export XPU_TARGET=AMD_GPU
else
    export XPU_TARGET=CPU
fi

"${JUPYTER_VENV}/bin/jupyter" lab --ip 0.0.0.0 --port 8888 --no-browser &

cd /workspace/stable-diffusion-webui
exec ./webui.sh
EOF

RUN chmod +x /start.sh

RUN chown "${APP_UID}:${APP_GID}" /start.sh

EXPOSE 7860 8888

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -fsS http://localhost:7860/ || exit 1

USER ${APP_UID}:${APP_GID}

CMD ["/start.sh"]
