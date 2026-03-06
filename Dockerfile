# Step 1: Official CUDA 12.4.1 base
FROM --platform=linux/amd64 nvidia/cuda:12.4.1-cudnn-devel-ubuntu24.04

ARG PYTHON_VERSION=3.12
ARG PYTORCH_VERSION=2.10.0
ARG REFORGE_VERSION=newmain_newforge

# Step 2: Install system dependencies, including python3.12 from deadsnakes PPA
ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PYTHON_VERSION=${PYTHON_VERSION} \
    PYTORCH_VERSION=${PYTORCH_VERSION} \
    XPU_TARGET=NVIDIA_GPU

ENV VENV_DIR=/opt/venv
ENV REFORGE_VENV=$VENV_DIR/stable-diffusion-webui
ENV JUPYTER_VENV=$VENV_DIR/jupyter
ENV PATH="$REFORGE_VENV/bin:$JUPYTER_VENV/bin:$PATH"

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    python${PYTHON_VERSION} \
    python${PYTHON_VERSION}-venv \
    python3-pip \ 
    wget \
    curl \
    libgl1-mesa-glx \
    libglib2.0-0 \
    ffmpeg \
    libsm6 \
    libxext6 \
    tree \
    && rm -rf /var/lib/apt/lists/*

# Create virtual envs
RUN python${PYTHON_VERSION} -m venv $COMFYUI_VENV && \
    python${PYTHON_VERSION} -m venv $JUPYTER_VENV

WORKDIR /workspace

# Install JupyterLab in its own virtual environment
RUN . $JUPYTER_VENV/bin/activate && \
    pip install --no-cache-dir jupyterlab notebook numpy pandas && \
    jupyter notebook --generate-config && \
    echo "c.NotebookApp.token = ''" >> ~/.jupyter/jupyter_notebook_config.py && \
    echo "c.NotebookApp.password = ''" >> ~/.jupyter/jupyter_notebook_config.py && \
    deactivate

# Setup ReForge
### Will this be an issue declaring it rather than git cloning it to create hte directory
WORKDIR /workspace/stable-diffusion-webui

RUN . $REFORGE_VENV/bin/activate && \
    git clone https://github.com/Panchovix/stable-diffusion-webui-reForge.git --branch newmain_newforge /workspace/stable-diffusion-webui && \
    cd /workspace/stable-diffusion-webui && \
    if [ "$REFORGE_VERSION" != "newmain_newforge" ]; then git checkout $REFORGE_VERSION; fi && \
    pip install --no-cache-dir -r requirements.txt && \
    pip install --no-cache-dir -r requirements_versions.txt && \
    pip install --no-cache-dir torch==${PYTORCH_VERSION} torchvision torchaudio --index-url https://download.pytorch.org/whl/cu130 && \
    deactivate

# --- after cloning stable-diffusion-webui into /workspace/stable-diffusion-webui ---

# Make these args/envs exist at build time (ARG) and runtime (ENV) as you prefer
ARG TORCH_VERSION=2.6.0
ENV TORCH_VERSION=${TORCH_VERSION}

# Example: if you want this provided by Runpod at runtime, keep it as ENV only.
# If you know it at build time, use ARG + ENV similarly.
ENV REFORGE_VENV="venv"

RUN set -eux; \
  f="/workspace/stable-diffusion-webui/webui-user.sh"; \
  test -f "$f"; \
  sed -i -E 's|^[[:space:]]*#?[[:space:]]*export[[:space:]]+COMMANDLINE_ARGS=.*|export COMMANDLINE_ARGS="--listen --host 0.0.0.0"|' "$f"
  \
  # 1) install_dir="/workspace" (uncomment or replace any existing install_dir= line)
  sed -i -E 's|^[[:space:]]*#?[[:space:]]*install_dir=.*|install_dir="/workspace"|' "$f"; \
  \
  # 2) venv_dir="$REFORGE_VENV" (uncomment or replace)
  sed -i -E 's|^[[:space:]]*#?[[:space:]]*venv_dir=.*|venv_dir="'"$REFORGE_VENV"'"|' "$f"; \
  \
  # 3) export TORCH_COMMAND=... (uncomment or replace)
  sed -i -E 's|^[[:space:]]*#?[[:space:]]*export[[:space:]]+TORCH_COMMAND=.*|export TORCH_COMMAND="pip install torch=='"$TORCH_VERSION"' --extra-index-url https://download.pytorch.org/whl/cu130"|' "$f"; \
  \
  # 4) export REQS_FILE="requirements_versions.txt" (uncomment or replace)
  sed -i -E 's|^[[:space:]]*#?[[:space:]]*export[[:space:]]+REQS_FILE=.*|export REQS_FILE="requirements_versions.txt"|' "$f"; \
  \
  # show the final relevant lines for build logs
  grep -nE '^(install_dir=|venv_dir=|export TORCH_COMMAND=|export REQS_FILE=)' "$f"

# Create a startup script 
COPY <<'EOF' /start.sh
#!/bin/bash
set -eo pipefail
umask 002

echo "Starting ReForge Setup..."
echo "Python Version: $(python3 --version)"

# Check GPU Availability
if command -v nvidia-smi &> /dev/null; then
    echo "NVIDIA GPU Detected"
    echo "CUDA Version $(nvcc --version 2>/dev/null || echo 'NVCC not found')"
    echo "GPU Information: $(nvidia-smi)"
    export XPU_TARGET=NVIDIA_GPU
elif [ -d "/dev/dri" ]; then
    echo "AMD GPU detected"
    export XPU_TARGET=AMD_GPU
else
    echo "No GPU Detected, using CPU"
    export XPU_TARGET=CPU
fi

# Start JupyterLab
echo "Starting JupyterLab..."
. $JUPYTER_VENV/bin/activate
jupyter lab --ip 0.0.0.0 --port 8888 --no-browser --allow-root & 
deactivate

echo "Starting Reforge"
. $REFORGE_VENV/bin/activate
exec webui.sh
EOF

RUN chmod +x /start.sh

# Step 6: Expose the Web UI Port
EXPOSE 7860 8888

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:7860 || exit 1

CMD "/start..sh"
