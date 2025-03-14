# Step 1: Official CUDA 12.4.1 base
FROM nvidia/cuda:12.4.1-cudnn-devel-ubuntu22.04

# Step 2: Install system dependencies, including python3.12 from deadsnakes PPA
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    software-properties-common \
    && add-apt-repository ppa:deadsnakes/ppa \
    && apt-get update && apt-get install -y --no-install-recommends \
    git \
    wget \
    python3.12 \
    python3.12-dev \
    python3.12-distutils \
    python3.12-venv \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Step 3: Install pip for Python 3.12 and upgrade it
RUN python3.12 -m ensurepip && \
    python3.12 -m pip install --upgrade pip

# Step 4: Create a working directory 
WORKDIR /app

# Step 5: Clone SD WebUI ReForge 
RUN git clone --depth=1 https://github.com/nschloe/stable-diffusion-webui-reforge.git .

# Step 6: Install Python dependencies with pip (Python 3.12)
RUN python3.12 -m pip install -r requirements.txt

# Step 7: Expose the Web UI Port
EXPOSE 7860

# Step 8: Set ENV Variables
ENV COMMANDLINE_ARGS="--listen --port 7860"
ENV PYTHONUNBUFFERED=1

# Step 9: Final command to run the WebUI
CMD ["python3.12", "webui.py"]