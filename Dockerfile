# kics-scan disable=67fd0c4a-68cf-46d7-8c41-bc9fba7e40ae,965a08d7-ef86-4f14-8792-4a3b2098937e

FROM ubuntu:24.04

# hadolint ignore=DL3008
RUN apt-get update && \
    export DEBIAN_FRONTEND=noninteractive && \
    # tools & required packages
    apt-get install -y --no-install-recommends git curl wget ca-certificates software-properties-common inetutils-ping dnsutils ncat nmap zsh vim vim-airline vim-lastplace && \
    # install atuin
    curl --proto '=https' --tlsv1.2 -LsSf https://setup.atuin.sh | sh && \
    # install oh-my-zsh and plugins
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" && \
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting && \
    git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions && \
    git clone https://github.com/zsh-users/zsh-completions ${ZSH_CUSTOM:-${ZSH:-~/.oh-my-zsh}/custom}/plugins/zsh-completions && \
    git clone https://github.com/thuandt/zsh-pipx.git ${ZSH_CUSTOM:-${ZSH:-~/.oh-my-zsh}/custom}/plugins/pipx && \
    git clone https://github.com/MichaelAquilina/zsh-autoswitch-virtualenv.git ${ZSH_CUSTOM:-${ZSH:-~/.oh-my-zsh}/custom}/plugins/autoswitch_virtualenv && \
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/themes/powerlevel10k && \
    # clean up
    && apt-get autoremove --purge -y && apt-get autoclean && apt-get clean apt-get clean -y && rm -rf /var/lib/apt/lists/*

ARG VERSION="1.97.2"

# install visual studio code
RUN <<EOF
  ARCH="$(dpkg --print-architecture)";

  echo "ARCH: $ARCH";

  case "$ARCH" in
    amd64) export TARGET='cli-linux-x64' ;;
    arm64) export TARGET='cli-linux-arm64' ;;
  esac;

  wget -qO- https://update.code.visualstudio.com/${VERSION}/${TARGET}/stable | tar xvz -C /home/vscode
  chmod +x /home/vscode/code
EOF

RUN groupadd --system --gid 1000 vscode && \
     useradd vscode --uid 1000 --gid 1000 --create-home --shell /usr/bin/zsh && \
     usermod -aG sudo vscode && \
     chown -R vscode: /home/vscode/code

USER 1000:1000

# entrypoint
ENTRYPOINT [ "code", "serve-web", "--without-connection-token", "--accept-server-license-terms" ]

# default arguments
CMD [ "--host", "0.0.0.0", "--port", "8000", "--cli-data-dir", "/home/vscode/.vscode/cli-data", "--user-data-dir", "/home/vscode/user-data", "--server-data-dir", "/home/vscode/.vscode/server-data", "--extensions-dir", "/home/vscode/.vscode/extensions" ]

HEALTHCHECK NONE

# expose port
EXPOSE 8000
