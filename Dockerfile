# Stage 1: Build Environment Setup
FROM nvidia/cuda:11.7.1-devel-ubuntu22.04 AS builder

RUN apt-get update -y && apt-get install -y build-essential && rm -rf /var/lib/apt/lists/*

# Create a user
ENV APPUSER="appuser"
ENV HOME=/home/$APPUSER
RUN useradd -m -u 1000 $APPUSER
USER $APPUSER
WORKDIR $HOME

ENV ENV_NAME="diffdock"
ENV DIR_NAME="DiffDock"

# Setup uv
COPY --from=ghcr.io/astral-sh/uv:latest /uv /bin/uv

WORKDIR $HOME/$DIR_NAME
ADD uv.lock uv.lock
ADD pyproject.toml pyproject.toml

ENV CC=gcc CXX=g++
RUN uv sync --frozen --compile-bytecode --no-install-project

# Copy application code
COPY --chown=$APPUSER:$APPUSER . $HOME/$DIR_NAME

# Install dependencies
RUN uv sync --frozen --compile-bytecode

# Download models
# These should download automatically on first inference
# RUN curl -L -o diffdock_models_v1.1.zip "https://www.dropbox.com/scl/fi/drg90rst8uhd2633tyou0/diffdock_models.zip?rlkey=afzq4kuqor2jb8adah41ro2lz&dl=1" \
#     && mkdir -p $HOME/$DIR_NAME/workdir \
#     && unzip diffdock_models_v1.1.zip -d $HOME/$DIR_NAME/workdir


# Stage 2: Runtime Environment
FROM ubuntu:22.04

# Create user and setup environment
ENV APPUSER="appuser"
ENV HOME=/home/$APPUSER
RUN useradd -m -u 1000 $APPUSER
USER $APPUSER
WORKDIR $HOME

ENV ENV_NAME="diffdock"
ENV DIR_NAME="DiffDock"

# Copy uv and application code from the builder stage
COPY --from=ghcr.io/astral-sh/uv:latest /uv /bin/uv
COPY --from=builder --chown=$APPUSER:$APPUSER $HOME/$DIR_NAME $HOME/$DIR_NAME
WORKDIR $HOME/$DIR_NAME

RUN uv python install 3.10
RUN ln -sf $(uv python find 3.10) $HOME/$DIR_NAME/.venv/bin/python 

# Precompute series for SO(2) and SO(3) groups
RUN .venv/bin/python utils/precompute_series.py

# Expose ports for streamlit and gradio
EXPOSE 7860 8501

# Default command
CMD [".venv/bin/python", "utils/print_device.py"]
