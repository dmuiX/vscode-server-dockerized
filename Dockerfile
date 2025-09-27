FROM ubuntu:24.04

ARG USER_PASSWORD_FILE
ENV USER_PASSWORD_FILE=${USER_PASSWORD_FILE:-/run/secrets/user_password}

COPY entrypoint.sh /

# Install utilities and dependencies, include jq for JSON parsing
RUN apt-get update && \
    export DEBIAN_FRONTEND=noninteractive && \
    apt-get upgrade -y && \
    apt-get install -y --no-install-recommends git curl wget ca-certificates gnupg2 software-properties-common jq inetutils-ping dnsutils ncat nmap zsh vim sudo bat && \
    
    # terraform repo setup
    curl -fsSL https://apt.releases.hashicorp.com/gpg | apt-key add - && \
    apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main" && \
    apt-get update && apt-get install -y terraform && \
    
    # Fetch latest DOCTL version dynamically and install
    DOCTL_VERSION=$(curl -s https://api.github.com/repos/digitalocean/doctl/releases/latest | jq -r '.tag_name' | sed 's/^v//') && \
    curl -L https://github.com/digitalocean/doctl/releases/download/v${DOCTL_VERSION}/doctl-${DOCTL_VERSION}-linux-amd64.tar.gz | tar -xzC /usr/local/bin && \
    chmod +x /usr/local/bin/doctl && \
    doctl version && \
    
    # Map architecture and install VS Code Insiders
    ARCH=$(dpkg --print-architecture) && \
    echo "ARCH: $ARCH" && \
    case "$ARCH" in \
      amd64) TARGET_API='linux-x64' ; TARGET_DL='cli-linux-x64' ;; \
      arm64) TARGET_API='linux-arm64' ; TARGET_DL='cli-linux-arm64' ;; \
      *) echo "Unsupported architecture: $ARCH" && exit 1 ;; \
    esac && \
    COMMIT_HASH=$(wget -qO- https://update.code.visualstudio.com/api/commits/insider/${TARGET_API} | jq -r '.[0]') && \
    echo "Using commit hash: $COMMIT_HASH for Insiders build" && \
    wget -qO- https://update.code.visualstudio.com/commit:$COMMIT_HASH/${TARGET_DL}/insider | tar xvz -C /opt && \
    chmod +x /opt/code /entrypoint.sh && \
    chown -R root:root /opt/code /entrypoint.sh && \

    # stable
    # install visual studio code and set some permissions
    # CODE_VERSION="latest" && \
    # ARCH="$(dpkg --print-architecture)" && \
    # echo "ARCH: $ARCH" && \
    # case "$ARCH" in \
    #   amd64) export TARGET='cli-linux-x64' ;; \
    #   arm64) export TARGET='cli-linux-arm64' ;; \
    # esac && \
    # wget -qO- https://update.code.visualstudio.com/${CODE_VERSION}/${TARGET}/stable | tar xvz -C /opt && \
    # chmod -x /opt/code /entrypoint.sh && \
    # chown -R ubuntu: /opt/code /entrypoint.sh && \
    
    # Cleanup apt cache
    apt-get autoremove --purge -y && \
    apt-get autoclean -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

# User and permissions setup
RUN useradd -ms /bin/zsh vscode && \
    usermod -aG sudo vscode && \
    groupmod -n vscode vscode && \
    usermod -g users vscode && \
    usermod -d /home/vscode -m vscode && \
    chown -R vscode:vscode /home/vscode

USER vscode

# Additional user-specific installations can happen here (atuin, oh-my-zsh, etc.)

WORKDIR /home/vscode

ENTRYPOINT [ "/entrypoint.sh" ]
# Add this near the end of your Dockerfile before EXPOSE

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD curl -f http://localhost:8000/health || exit 1

EXPOSE 8000
