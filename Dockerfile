# Step 1: Official CUDA 12.4.1 base
FROM nvidia/cuda:12.4.1-cudnn-devel-ubuntu22.04

# Step 2: Install system dependencies, including python3.12 from deadsnakes PPA
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    software-properties-common git wget curl \
    && add-apt-repository ppa:deadsnakes/ppa \
    && apt-get update && apt-get install -y --no-install-recommends \
    python3.12 python3.12-dev python3.12-venv \
    && rm -rf /var/lib/apt/lists/*

# Step 3: Install pip & upgrade it for Python3.12
RUN python3.12 -m ensurepip && \
    python3.12 -m pip install --upgrade pip

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