# Builder stage: install dependencies, fetch binaries, prepare artifacts
FROM ubuntu:24.04 AS builder

ARG DEBUG=false
ENV DEBUG=${DEBUG}
ENV DEBIAN_FRONTEND=noninteractive

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN if [ "$DEBUG" = "true" ]; then set -x ; fi && \
    apt-get update && apt-get install -y --no-install-recommends \
    curl jq wget tar ca-certificates gnupg2 software-properties-common \
    lsb-release apt-transport-https

# Install Terraform repo and terraform binary
RUN if [ "$DEBUG" = "true" ]; then set -x; fi && \
    curl -fsSL https://apt.releases.hashicorp.com/gpg | apt-key add - && \
    apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main" && \
    apt-get update && apt-get install -y --no-install-recommends terraform

# Fetch latest doctl version
RUN if [ "$DEBUG" = "true" ]; then set -x; fi && \
    DOCTL_VERSION=$(curl -fsSL https://api.github.com/repos/digitalocean/doctl/releases/latest | jq -r '.tag_name' | sed 's/^v//') && \
    echo "Installing doctl version \"$DOCTL_VERSION\"" && \
    curl -fsSL "https://github.com/digitalocean/doctl/releases/download/v${DOCTL_VERSION}/doctl-${DOCTL_VERSION}-linux-amd64.tar.gz" | tar -xzC /usr/local/bin && \
    chmod +x /usr/local/bin/doctl

# Setup VSCode Insiders
RUN if [ "$DEBUG" = "true" ]; then set -x; fi && \
    ARCH=$(dpkg --print-architecture) && \
    case "$ARCH" in \
      amd64) TARGET_API='linux-x64' ; TARGET_DL='cli-linux-x64' ;; \
      arm64) TARGET_API='linux-arm64' ; TARGET_DL='cli-linux-arm64' ;; \
      *) echo "Unsupported architecture: \"$ARCH\"" && exit 1 ;; \
    esac && \
    echo "Detected architecture: \"$ARCH\"" && \
    COMMIT_HASH=$(curl -fsSL "https://update.code.visualstudio.com/api/commits/insider/${TARGET_API}" | jq -r '.[0]') && \
    echo "Fetching VSCode Insiders commit \"$COMMIT_HASH\"" && \
    curl -fsSL "https://update.code.visualstudio.com/commit:$COMMIT_HASH/${TARGET_DL}/insider" | tar xvz -C /opt && \
    chmod +x /opt/code /entrypoint.sh

# -------------------------------------------------------------------------
# Commented out stable VSCode install code for reference:
# 
# RUN set -o pipefail && \
#      if [ "$DEBUG" = "true" ]; then set -x; fi && \
#     CODE_VERSION="latest" && \
#     ARCH=$(dpkg --print-architecture) && \
#     echo "ARCH: $ARCH" && \
#     case "$ARCH" in \
#       amd64) TARGET='cli-linux-x64' ;; \
#       arm64) TARGET='cli-linux-arm64' ;; \
#     esac && \
#     wget -qO- https://update.code.visualstudio.com/${CODE_VERSION}/${TARGET}/stable | tar xvz -C /opt && \
#     chmod -x /opt/code /entrypoint.sh && \
#     chown -R root:root /opt/code /entrypoint.sh
# -------------------------------------------------------------------------

# Runtime stage: minimal image with only needed binaries and libs
FROM ubuntu:24.04 as runtime_stage

ARG USER_PASSWORD_FILE
ENV USER_PASSWORD_FILE=${USER_PASSWORD_FILE:-/run/secrets/user_password}

ENV DEBIAN_FRONTEND=noninteractive

# Install runtime dependencies only
RUN if [ "$DEBUG" = "true" ]; then set -x; fi && \
    apt-get update && apt-get upgrade -y --no-install-recommends && apt-get install -y --no-install-recommends \
    ca-certificates curl zsh vim sudo bat inetutils-ping dnsutils ncat nmap && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Copy binaries and VSCode code folder from builder stage
COPY --from=builder /usr/local/bin/doctl /usr/local/bin/doctl
COPY --from=builder /usr/bin/terraform /usr/bin/terraform
COPY --from=builder /opt/code /opt/code
COPY --from=builder /entrypoint.sh /entrypoint.sh

RUN if [ "$DEBUG" = "true" ]; then set -x; fi && \
    chmod +x /usr/local/bin/doctl /usr/bin/terraform /opt/code /entrypoint.sh && \
    chown -R root:root /opt/code /entrypoint.sh

# Add user and permissions setup as before
RUN if [ "$DEBUG" = "true" ]; then set -x; fi && \
    useradd -ms /bin/zsh vscode && \
    usermod -aG sudo vscode && \
    groupmod -n vscode vscode && \
    usermod -g users vscode && \
    usermod -d /home/vscode -m vscode && \
    chown -R vscode:vscode /home/vscode

USER vscode

WORKDIR /home/vscode

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD curl -f http://localhost:8000/health || exit 1

EXPOSE 8000

ENTRYPOINT [ "/entrypoint.sh" ]
