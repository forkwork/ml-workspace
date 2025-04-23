# Improve error handling and output in the Dockerfile.
# This Dockerfile is used to build the Machine Learning Workspace image.
# It is based on Ubuntu 22.04 and uses the latest versions of Python, Node.js, and other dependencies.
# The image is configured to run JupyterLab, TensorFlow, PyTorch, and other data science tools.
# The image is also configured to run a VNC server and a web server to allow users to access the workspace over the web.

# Stage 1: Base dependencies - Common foundation for all stages
FROM ubuntu:22.04 AS base-deps

# Set shell to fail on errors for more robust scripts
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Version arguments for better maintenance
ARG PYTHON_VERSION="3.10.4"
ARG CONDA_VERSION="4.9.2"
ARG MINICONDA_VERSION="4.10.3"
ARG MINICONDA_MD5="122c8c9beb51e124ab32a0fa6426c656"
ARG NODE_VERSION="18.x"
ARG OPEN_RESTY_VERSION="1.19.3.2"
ARG TINI_VERSION="0.19.0"
ARG WORKSPACE_FLAVOR="full"
ARG VCS_REF="unknown"
ARG WORKSPACE_VERSION="unknown"
ARG BUILD_DATE="unknown"

# Common environment variables used across all stages
ENV DEBIAN_FRONTEND="noninteractive" \
    SHELL="/bin/bash" \
    HOME="/root" \
    NB_USER="root" \
    USER_GID=0 \
    RESOURCES_PATH="/resources" \
    SSL_RESOURCES_PATH="/resources/ssl" \
    WORKSPACE_HOME="/workspace" \
    XDG_CACHE_HOME="/root/.cache/" \
    XDG_RUNTIME_DIR="/tmp" \
    DISPLAY=":1" \
    TERM="xterm" \
    LANG="en_US.UTF-8" \
    LANGUAGE="en_US:en" \
    LC_ALL="en_US.UTF-8" \
    WORKSPACE_FLAVOR="${WORKSPACE_FLAVOR}" \
    WORKSPACE_VERSION="${WORKSPACE_VERSION}"
WORKDIR $HOME

# Copy utility scripts early to use throughout the build
COPY resources/scripts/clean-layer.sh resources/scripts/fix-permissions.sh /usr/bin/
RUN chmod a+rx /usr/bin/clean-layer.sh /usr/bin/fix-permissions.sh

# Create directories, install basic dependencies, and configure the environment
RUN set -euxo pipefail
RUN mkdir -p $RESOURCES_PATH $WORKSPACE_HOME $SSL_RESOURCES_PATH
RUN chmod a+rwx $RESOURCES_PATH $WORKSPACE_HOME $SSL_RESOURCES_PATH

RUN groupadd -r appuser
RUN useradd -r -g appuser -d /home/appuser -m appuser

RUN apt-get update
RUN apt-get install -y --no-install-recommends locales ca-certificates curl wget
RUN apt-get install -y --no-install-recommends apt-utils apt-transport-https gnupg2
RUN apt-get install -y --no-install-recommends software-properties-common
RUN apt-get install -y --no-install-recommends build-essential pkg-config lsof net-tools
RUN apt-get install -y --no-install-recommends openssh-client openssh-server sslh autossh
RUN apt-get install -y --no-install-recommends openssl iproute2 psmisc tmux dpkg-sig uuid-dev
RUN apt-get install -y --no-install-recommends xclip time libssl-dev xz-utils gawk swig
RUN apt-get install -y --no-install-recommends graphviz libgraphviz-dev screen nano
RUN apt-get install -y --no-install-recommends sqlite3 xmlstarlet parallel libspatialindex-dev
RUN apt-get install -y --no-install-recommends yara less tree bash-completion iputils-ping
RUN apt-get install -y --no-install-recommends socat jq rsync libsqlite3-dev git subversion
RUN apt-get install -y --no-install-recommends libzmq3-dev protobuf-compiler autoconf automake
RUN apt-get install -y --no-install-recommends libtool cmake zip gzip unzip bzip2 lzop
RUN apt-get install -y --no-install-recommends libarchive-tools zlib1g-dev libbz2-dev liblzma-dev

RUN sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
RUN locale-gen
RUN update-locale LANG=en_US.UTF-8

RUN add-apt-repository -y ppa:git-core/ppa
RUN apt-get update
RUN apt-get install -y --no-install-recommends git

RUN mkdir -p $HOME/.ssh/
RUN touch $HOME/.ssh/config
RUN chmod 700 $HOME/.ssh
RUN printenv >> $HOME/.ssh/environment
RUN mkdir -p /var/run/sshd
RUN chmod 400 /var/run/sshd

RUN curl -sL https://deb.nodesource.com/setup_18.x | bash -
RUN apt-get install -y --no-install-recommends nodejs
RUN npm install -g npm yarn typescript webpack node-gyp
RUN npm cache clean --force

RUN apt-get clean
RUN rm -rf /var/lib/apt/lists/*
RUN clean-layer.sh

# Add tini for proper signal handling
RUN set -euxo pipefail && \
    wget --no-verbose --retry-connrefused --waitretry=5 --timeout=30 \
        https://github.com/krallin/tini/releases/download/v${TINI_VERSION}/tini -O /tini && \
    chmod +x /tini

# Install OpenResty (nginx)
RUN set -euxo pipefail && \
    # Install OpenResty dependencies
    apt-get update && \
    apt-get purge -y nginx nginx-common && \
    apt-get install -y --no-install-recommends libssl-dev libpcre3 libpcre3-dev apache2-utils && \
    \
    # Build and install OpenResty
    mkdir -p /tmp/openresty && \
    cd /tmp/openresty && \
    wget --no-verbose --retry-connrefused --waitretry=5 --timeout=30 \
        https://openresty.org/download/openresty-${OPEN_RESTY_VERSION}.tar.gz -O ./openresty.tar.gz && \
    tar xfz ./openresty.tar.gz && \
    cd ./openresty-${OPEN_RESTY_VERSION}/ && \
    ./configure --with-http_stub_status_module --with-http_sub_module > /dev/null && \
    make -j"$(nproc)" > /dev/null && \
    make install > /dev/null && \
    \
    # Setup nginx logs and directories
    mkdir -p /var/log/nginx/ && \
    touch /var/log/nginx/upstream.log && \
    \
    # Clean up
    cd / && \
    rm -rf /tmp/openresty && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    clean-layer.sh

ENV PATH="/usr/local/openresty/nginx/sbin:$PATH" \
    PATH="/opt/node/bin:$PATH"

# Install pyenv for managing Python versions
RUN set -euxo pipefail && \
    apt-get update && \
    apt-get install -y --no-install-recommends libffi-dev && \
    git clone --depth 1 https://github.com/pyenv/pyenv.git $RESOURCES_PATH/.pyenv && \
    git clone --depth 1 https://github.com/pyenv/pyenv-virtualenv.git $RESOURCES_PATH/.pyenv/plugins/pyenv-virtualenv && \
    git clone --depth 1 https://github.com/pyenv/pyenv-doctor.git $RESOURCES_PATH/.pyenv/plugins/pyenv-doctor && \
    git clone --depth 1 https://github.com/pyenv/pyenv-update.git $RESOURCES_PATH/.pyenv/plugins/pyenv-update && \
    git clone --depth 1 https://github.com/pyenv/pyenv-which-ext.git $RESOURCES_PATH/.pyenv/plugins/pyenv-which-ext && \
    # Clean up
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    fix-permissions.sh $RESOURCES_PATH/.pyenv && \
    clean-layer.sh

ENV PATH="$RESOURCES_PATH/.pyenv/shims:$RESOURCES_PATH/.pyenv/bin:$PATH" \
    PYENV_ROOT="$RESOURCES_PATH/.pyenv"

# Install pipx for isolated application installations
RUN apt-get update && apt-get install -y python3 python3-pip
RUN set -euxo pipefail && \
    python3 -m pip install --upgrade pip && \
    pip3 install pipx && \
    python3 -m pipx ensurepath && \
    fix-permissions.sh $HOME/.local && true
