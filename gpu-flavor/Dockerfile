FROM khulnasoft/ml-workspace:latest AS base

ARG ARG_WORKSPACE_FLAVOR="gpu"
ENV WORKSPACE_FLAVOR=$ARG_WORKSPACE_FLAVOR

USER root

### NVIDIA CUDA BASE ###
# https://gitlab.com/nvidia/container-images/cuda/-/blob/master/dist/11.2.2/ubuntu20.04-x86_64/base/Dockerfile
# Update NVIDIA GPG key
RUN sudo apt-get update && sudo apt-get install -y --no-install-recommends gnupg2 curl && \
    curl -fsSL https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/x86_64/3bf863cc.pub | gpg --dearmor -o /usr/share/keyrings/nvidia-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/nvidia-archive-keyring.gpg] https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/x86_64 /" > /etc/apt/sources.list.d/cuda.list && \
    echo "deb [signed-by=/usr/share/keyrings/nvidia-archive-keyring.gpg] https://developer.download.nvidia.com/compute/machine-learning/repos/ubuntu2004/x86_64 /" > /etc/apt/sources.list.d/nvidia-ml.list && \
    apt-get update && apt-get install -y --no-install-recommends \
    cuda-cudart-11-2 \
    cuda-compat-11-2 && \
    ln -s cuda-11.2 /usr/local/cuda && \
    rm -rf /var/lib/apt/lists/* && \
    apt-get clean && \
    rm -rf $HOME/.cache/* && \
    rm -rf /tmp/*

ENV CUDA_VERSION 11.2.2
#ENV CUDA_PKG_VERSION 11-2=$CUDA_VERSION-1
#ENV CUDART_VERSION 11-2=$CUDA_VERSION46-1

# For libraries in the cuda-compat-* package: https://docs.nvidia.com/cuda/eula/index.html#attachment-a

# Required for nvidia-docker v1
RUN echo "/usr/local/nvidia/lib" >> /etc/ld.so.conf.d/nvidia.conf \
    && echo "/usr/local/nvidia/lib64" >> /etc/ld.so.conf.d/nvidia.conf

ENV PATH /usr/local/nvidia/bin:/usr/local/cuda/bin:${PATH}
ENV LD_LIBRARY_PATH /usr/local/nvidia/lib:/usr/local/nvidia/lib64

# nvidia-container-runtime
# https://github.com/NVIDIA/nvidia-container-runtime#environment-variables-oci-spec
# nvidia-container-runtime
ENV NVIDIA_VISIBLE_DEVICES all
ENV NVIDIA_DRIVER_CAPABILITIES compute,utility
ENV NVIDIA_REQUIRE_CUDA "cuda>=11.2 brand=tesla,driver>=418,driver<419 brand=tesla,driver>=440,driver<441 driver>=450"

### CUDA RUNTIME ###
# https://gitlab.com/nvidia/container-images/cuda/-/blob/master/dist/11.2.2/ubuntu20.04-x86_64/runtime/Dockerfile

ENV NCCL_VERSION 2.8.4

RUN apt-get update && apt-get install -y --no-install-recommends \
    cuda-libraries-11-2=11.2.2-1 \
    libnpp-11-2=11.3.2.152-1 \
    cuda-nvtx-11-2=11.2.152-1 \
    libcublas-11-2=11.4.1.1043-1 \
    libcusparse-11-2=11.4.1.1152-1 \
    libnccl2=$NCCL_VERSION-1+cuda11.2 \
    && rm -rf /var/lib/apt/lists/* \
    # Cleanup - cannot use cleanup script here, otherwise too much is removed
    && apt-get clean \
    && rm -rf $HOME/.cache/* \
    && rm -rf /tmp/* \
    && rm -rf /var/lib/apt/lists/*

RUN apt-mark hold libcublas-11-2 libnccl2

### END CUDA RUNTIME ###

### CUDA DEVEL ###
# https://gitlab.com/nvidia/container-images/cuda/-/blob/master/dist/11.2.2/ubuntu20.04-x86_64/devel/Dockerfile
RUN apt-get update && apt-get install -y --no-install-recommends \
    libtinfo5 libncursesw5 \
    cuda-cudart-dev-11-2=11.2.152-1 \
    cuda-command-line-tools-11-2=11.2.2-1 \
    cuda-minimal-build-11-2=11.2.2-1 \
    cuda-libraries-dev-11-2=11.2.2-1 \
    cuda-nvml-dev-11-2=11.2.152-1 \
    libnpp-dev-11-2=11.3.2.152-1 \
    libnccl-dev=2.8.4-1+cuda11.2 \
    libcublas-dev-11-2=11.4.1.1043-1 \
    libcusparse-dev-11-2=11.4.1.1152-1 && \
    # Cleanup - cannot use cleanup script here, otherwise too much is removed
    apt-get clean && \
    rm -rf $HOME/.cache/* && \
    rm -rf /tmp/* && \
    rm -rf /var/lib/apt/lists/*

# apt from auto upgrading the cublas package. See https://gitlab.com/nvidia/container-images/cuda/-/issues/88
RUN apt-mark hold libcublas-dev-11-2 libnccl-dev
ENV LIBRARY_PATH /usr/local/cuda/lib64/stubs

### END CUDA DEVEL ###

### CUDANN8 DEVEL ###
# https://gitlab.com/nvidia/container-images/cuda/-/blob/master/dist/11.2.2/ubuntu20.04-x86_64/devel/cudnn8/Dockerfile

ENV CUDNN_VERSION 8.1.1.33
LABEL com.nvidia.cudnn.version="${CUDNN_VERSION}"

RUN apt-get update && apt-get install -y --no-install-recommends \
    libcudnn8=$CUDNN_VERSION-1+cuda11.2 \
    libcudnn8-dev=$CUDNN_VERSION-1+cuda11.2 \
    && apt-mark hold libcudnn8 && \
    # Cleanup
    apt-get clean && \
    rm -rf /root/.cache/* && \
    rm -rf /tmp/* && \
    rm -rf /var/lib/apt/lists/*

### END CUDANN8 ###

# Link Cupti:
ENV LD_LIBRARY_PATH ${LD_LIBRARY_PATH}:/usr/local/cuda/extras/CUPTI/lib64

### GPU DATA SCIENCE LIBRARIES ###

# Install pytorch gpu
# uninstall cpu only packages via conda
RUN conda remove --force -y pytorch cpuonly && \
    conda install cudatoolkit=11.2 -c pytorch -c nvidia && \
    pip install --no-cache-dir torch==1.9.0+cu111 torchvision==0.10.0+cu111 torchaudio==0.9.0 -f https://download.pytorch.org/whl/torch_stable.html && \
# Install cupy: https://cupy.chainer.org/
pip install --no-cache-dir cupy-cuda112==9.6.0 && \
# Install pycuda: https://pypi.org/project/pycuda
pip install --no-cache-dir pycuda==2021.1 && \
# Install gpu utils libs
pip install --no-cache-dir gpustat==0.6.0 py3nvml==0.2.6 gputil==1.4.0 && \
# Install scikit-cuda: https://scikit-cuda.readthedocs.io/en/latest/install.html
pip install --no-cache-dir scikit-cuda==0.5.3 && \
# Install tensorflow gpu
pip uninstall -y tensorflow tensorflow-cpu intel-tensorflow && \
pip install --no-cache-dir tensorflow-gpu==2.5.0 && \
# Install ONNX GPU Runtime
pip uninstall -y onnxruntime && \
pip install --no-cache-dir onnxruntime-gpu==1.8.0 onnxruntime-training==1.8.0 && \
# Install faiss gpu - TODO: to large?
# conda remove --force -y faiss-cpu && \
# conda install -y faiss-gpu -c pytorch && \
# Update mxnet to gpu edition
pip uninstall -y mxnet-mkl && \
# cuda111 -> >= 11.1
pip install --upgrade --no-cache-dir mxnet-cu112==1.8.0 && \
# install jax: https://github.com/google/jax#pip-installation
pip install --upgrade --force-reinstall jax[cuda111]==0.2.12 -f https://storage.googleapis.com/jax-releases/jax_releases.html && \
# Install pygpu - Required for theano: http://deeplearning.net/software/libgpuarray/
conda install -y pygpu && \
# Install lightgbm
# Install pytorch gpu
# uninstall cpu only packages via conda