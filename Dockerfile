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

RUN mkdir -p 
    

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3.12 python3.12-dev python3.12-venv python3-pip \
    && rm -rf /var/lib/apt/lists/*
ds

# Step 3: Install pip & upgrade it for Python3.12
RUN python3.12 -m ensurepip && \[[[[[[[[[[[    python3.12 -m pip install --upgrade pip

# Step 4: Copy our entrypoint script into the container
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Step 5: Set /workspace as the working directory
WORKDIR /workspace

# Step 6: Expose the Web UI Port
EXPOSE 7860

# Step 7: Set ENV Variables
ENV PYTHONUNBUFFERED=1

# Step 8: Run entrypoint script
ENTRYPOINT ["/entrypoint.sh"]
