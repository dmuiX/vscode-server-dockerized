# Builder stage: install dependencies, fetch binaries, prepare artifacts
FROM ubuntu:24.04 AS builder

ARG DEBUG=false
ENV DEBUG=${DEBUG}
ENV DEBIAN_FRONTEND=noninteractive

SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

RUN if [ "$DEBUG" = "true" ]; then set -x ; fi && \
    apt-get update && apt-get install -y --no-install-recommends \
    curl jq wget tar ca-certificates gnupg2 software-properties-common \
    lsb-release apt-transport-https unzip && \
    apt-get clean && \
    apt-get autoclean && \
    apt-get autoremove --purge -y && \
    rm -rf /var/lib/apt/lists/*

# Install Terraform (fetch latest version dynamically)
RUN if [ "$DEBUG" = "true" ]; then set -x; fi && \
    TERRAFORM_VERSION=$(curl -sSL https://api.github.com/repos/hashicorp/terraform/releases/latest | jq -r '.tag_name' | sed 's/^v//') && \
    ARCH=$(dpkg --print-architecture) && \
    curl -fsSL "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_${ARCH}.zip" -o /tmp/terraform.zip && \
    unzip /tmp/terraform.zip -d /usr/local/bin && \
    rm /tmp/terraform.zip && \
    chmod +x /usr/local/bin/terraform

# Setup VSCode Insiders
ARG UPSTREAM_VERSION
RUN retry() { \
      n=0; \
      until [ $n -ge 5 ]; do \
        "$@" && return 0; \
        n=$((n+1)); \
        echo "Retry #$n for command: $*"; \
        sleep 3; \
      done; \
      return 1; \
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
    COMMIT_HASH=${UPSTREAM_VERSION:-$(retry curl -fsSL "https://update.code.visualstudio.com/api/commits/insider/${TARGET_API}" | jq -r '.[0]')} && \
    if ! printf '%s\n' "$COMMIT_HASH" | grep -Eq '^[a-f0-9]{40}$'; then echo "ERROR: Invalid VSCode Insiders commit" >&2; exit 1; fi && \
    echo "Fetching VSCode Insiders commit \"$COMMIT_HASH\"" && \
    retry curl -fsSL "https://update.code.visualstudio.com/commit:$COMMIT_HASH/${TARGET_DL}/insider" -o /tmp/vscode-cli.tar.gz && \
    tar xzf /tmp/vscode-cli.tar.gz -C /opt && \
    rm /tmp/vscode-cli.tar.gz
    
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
FROM ubuntu:24.04 AS runtime_stage

ARG GITHUB_REPOSITORY=unknown

LABEL org.opencontainers.image.title="VSCode Server Dockerized" \
      org.opencontainers.image.description="VSCode Insiders server with Terraform" \
      org.opencontainers.image.source="https://github.com/${GITHUB_REPOSITORY}" \
      org.opencontainers.image.licenses="MIT"

ARG DEBUG=false
ENV DEBUG=${DEBUG}
ENV DEBIAN_FRONTEND=noninteractive

SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

# Install runtime dependencies only and clean up
RUN if [ "$DEBUG" = "true" ]; then set -x; fi && \
    apt-get update && apt-get upgrade -y --no-install-recommends && apt-get install -y --no-install-recommends \
    ca-certificates curl zsh vim sudo bat inetutils-ping dnsutils ncat nmap gosu git && \
    apt-get clean && \
    apt-get autoclean && \
    apt-get autoremove --purge -y && \
    rm -rf /var/lib/apt/lists/* /usr/share/doc/* /usr/share/man/* /usr/share/locales/*

# Copy binaries and VSCode code folder from builder stage
COPY --from=builder /usr/local/bin/terraform /usr/local/bin/terraform
COPY --from=builder /opt/code-insiders /opt/code-insiders
COPY entrypoint.sh /entrypoint.sh

RUN if [ "$DEBUG" = "true" ]; then set -x; fi && \
    chmod +x /usr/local/bin/terraform /opt/code-insiders /entrypoint.sh && \
    chown -R root:root /opt/code-insiders /entrypoint.sh

# Action-update migration: Hadolint 2.15 adds DL3066; UID 0 retains root behavior.
USER 0
# Will set to / anyways with this is explicit !
WORKDIR / 

# Action-update migration: Hadolint 2.15 applies DL3025 to healthchecks.
# Check the internal listener without triggering the editor's on-demand download.
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD ["/bin/bash", "-euo", "pipefail", "-c", "true > /dev/tcp/127.0.0.1/8000"]

 # Just Information tells the User the Application is using Port 8000
EXPOSE 8000

ENTRYPOINT [ "/entrypoint.sh" ]
