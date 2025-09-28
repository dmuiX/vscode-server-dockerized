# Builder stage: install dependencies, fetch binaries, prepare artifacts
FROM ubuntu:24.04 AS builder

ARG DEBUG=false
ENV DEBUG=${DEBUG}
ENV DEBIAN_FRONTEND=noninteractive

SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

RUN if [ "$DEBUG" = "true" ]; then set -x ; fi && \
    apt-get update && apt-get install -y --no-install-recommends \
    curl jq wget tar ca-certificates gnupg2 software-properties-common \
    lsb-release apt-transport-https

# Install Terraform repo and terraform binary
RUN if [ "$DEBUG" = "true" ]; then set -x; fi && \
    install -m 0755 -d /etc/apt/keyrings && \
    curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /etc/apt/keyrings/hashicorp.gpg && \
    chmod a+r /etc/apt/keyrings/hashicorp.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/hashicorp.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list > /dev/null && \
    apt-get update && apt-get install -y --no-install-recommends terraform

# Fetch latest doctl version
RUN if [ "$DEBUG" = "true" ]; then set -x; fi && \
    DOCTL_VERSION=$(curl -fsSL https://api.github.com/repos/digitalocean/doctl/releases/latest | jq -r '.tag_name' | sed 's/^v//') && \
    echo "Installing doctl version \"$DOCTL_VERSION\"" && \
    curl -fsSL "https://github.com/digitalocean/doctl/releases/download/v${DOCTL_VERSION}/doctl-${DOCTL_VERSION}-linux-amd64.tar.gz" | tar -xzC /usr/local/bin

# Setup VSCode Insiders
RUN retry() { \
      n=0; \
      until [ $n -ge 5 ]; do \
        "$@" && break; \
        n=$((n+1)); \
        echo "Retry #$n for command: $*"; \
        sleep 3; \
      done; \
    }; \
    \
    if [ "$DEBUG" = "true" ]; then set -x; fi && \
    ARCH=$(dpkg --print-architecture) && \
    case "$ARCH" in \
      amd64) TARGET_API='linux-x64' ; TARGET_DL='cli-linux-x64' ;; \
      arm64) TARGET_API='linux-arm64' ; TARGET_DL='cli-linux-arm64' ;; \
      *) echo "Unsupported architecture: \"$ARCH\"" && exit 1 ;; \
    esac && \
    echo "Detected architecture: \"$ARCH\"" && \
    COMMIT_HASH=$(retry curl -kfsSL "https://update.code.visualstudio.com/api/commits/insider/${TARGET_API}" | jq -r '.[0]') && \
    if [ -z "$COMMIT_HASH" ]; then echo "ERROR: Failed to fetch commit hash for VSCode Insiders"; exit 1; fi && \
    echo "Fetching VSCode Insiders commit \"$COMMIT_HASH\"" && \
    retry curl -kfsSL "https://update.code.visualstudio.com/commit:$COMMIT_HASH/${TARGET_DL}/insider" | tar xvz -C /opt
    
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

# --- New: Define ARGs for user configuration ---
ARG USERNAME
ARG PUID
ARG PGID
ARG USER_PASSWORD_FILE

ENV USERNAME=${USERNAME:vscode}
ENV PUID=${PUID:1000}
ENV PGID=${PGID:1000}
ENV USER_PASSWORD_FILE=${USER_PASSWORD_FILE:-/run/secrets/user_password}
ENV DEBIAN_FRONTEND=noninteractive

SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

# Install runtime dependencies only and clean up
RUN if [ "$DEBUG" = "true" ]; then set -x; fi && \
    apt-get update && apt-get upgrade -y --no-install-recommends && apt-get install -y --no-install-recommends \
    ca-certificates curl zsh vim sudo bat inetutils-ping dnsutils ncat nmap && \
    apt-get clean && \
    apt-get autoclean && \
    apt-get autoremove --purge -y && \
    rm -rf /var/lib/apt/lists/* /usr/share/doc/* /usr/share/man/* /usr/share/locales/*

# Copy binaries and VSCode code folder from builder stage
COPY --from=builder /usr/local/bin/doctl /usr/local/bin/doctl
COPY --from=builder /usr/bin/terraform /usr/bin/terraform
COPY --from=builder /opt/code-insiders /opt/code-insiders
COPY entrypoint.sh /entrypoint.sh

RUN if [ "$DEBUG" = "true" ]; then set -x; fi && \
    chmod +x /usr/local/bin/doctl /usr/bin/terraform /opt/code-insiders /entrypoint.sh && \
    chown -R root:root /opt/code-insiders /entrypoint.sh

# --- New: Modify the default 'ubuntu' user ---
# Rename the user and group, set UID/GID, and move the home directory
RUN if [ "$DEBUG" = "true" ]; then set -x; fi && \
    groupmod -n ${USERNAME} -g ${PGID} ubuntu && \
    usermod -l ${USERNAME} -u ${PUID} -d /home/${USERNAME} -m ubuntu && \
    usermod -aG sudo ${USERNAME} && \
    echo "${USERNAME}:${USERNAME}" | chpasswd

USER ${USERNAME}
WORKDIR /home/${USERNAME}

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD curl -f http://localhost:8000/health || exit 1

EXPOSE 8000

ENTRYPOINT [ "/entrypoint.sh" ]
