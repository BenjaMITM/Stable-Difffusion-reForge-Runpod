#!/bin/bash
set -e

# if sd-webui-reforge is not in /workspace, clone it
if [ ! -d /workspace/stable-diffusion-webui-reforge ]; then
    echo "Cloning stable-diffusion-webui-reforge into /workspace ..."
    git clone --depth=1 https://github.com/Panchovix/stable-diffusion-webui-reForge.git \
              /workspace/stable-diffusion-webui-reforge
fi

# Move into the directory
cd /workspace/stable-diffusion-webui-reforge

# Ensure that dependencies are up to date
python3.12 -m pip install -r requirements.txt

# Launch the WebUI. Adjust args as needed
exec python3.12 webui.py --listen --port 7860