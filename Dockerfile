# kics-scan disable=67fd0c4a-68cf-46d7-8c41-bc9fba7e40ae,965a08d7-ef86-4f14-8792-4a3b2098937e

FROM ubuntu:24.04

ARG VERSION="1.98.1"

# hadolint ignore=DL3008
RUN apt-get update && \
    export DEBIAN_FRONTEND=noninteractive && \
    apt-get upgrade -y && \
    
    # tools & required packages
    apt-get install -y --no-install-recommends git curl wget ca-certificates software-properties-common inetutils-ping dnsutils ncat nmap zsh vim vim-airline vim-airline-themes vim-lastplace sudo && \
    
    # clean up
    apt-get autoremove --purge -y && apt-get autoclean -y && apt-get clean -y && rm -rf /var/lib/apt/lists/* && \
    
    # install visual studio code
    # DEBUG VERSION="1.97.2" && \
    ARCH="$(dpkg --print-architecture)" && \
    echo "ARCH: $ARCH" && \
    case "$ARCH" in \
      amd64) export TARGET='cli-linux-x64' ;; \
      arm64) export TARGET='cli-linux-arm64' ;; \
    esac && \
    wget -qO- https://update.code.visualstudio.com/${VERSION}/${TARGET}/stable | tar xvz -C /home/ubuntu && \
    chmod +x /home/ubuntu/code && \
    chown -R ubuntu: /home/ubuntu/code && \

    # add user
    chsh -s /usr/bin/zsh ubuntu && \
    usermod -aG sudo ubuntu && \
    usermod -l vscode ubuntu && \
    groupmod -n vscode ubuntu && \
    usermod -d /home/vscode -m vscode

USER 1000:1000

    # install atuin
RUN curl --proto '=https' --tlsv1.2 -LsSf https://setup.atuin.sh | sh && \
    # install oh-my-zsh and plugins
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended && \
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting && \
    git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions && \
    git clone https://github.com/zsh-users/zsh-completions ${ZSH_CUSTOM:-${ZSH:-~/.oh-my-zsh}/custom}/plugins/zsh-completions && \
    git clone https://github.com/thuandt/zsh-pipx.git ${ZSH_CUSTOM:-${ZSH:-~/.oh-my-zsh}/custom}/plugins/pipx && \
    git clone https://github.com/MichaelAquilina/zsh-autoswitch-virtualenv.git ${ZSH_CUSTOM:-${ZSH:-~/.oh-my-zsh}/custom}/plugins/autoswitch_virtualenv && \
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/themes/powerlevel10k

# entrypoint
ENTRYPOINT [ "/home/vscode/code", "serve-web", "--without-connection-token", "--accept-server-license-terms" ]

# default arguments
CMD [ "--host", "0.0.0.0", "--port", "8000", "--cli-data-dir", "/home/vscode/.vscode/cli-data", "--user-data-dir", "/home/vscode/user-data", "--server-data-dir", "/home/vscode/.vscode/server-data", "--extensions-dir", "/home/vscode/.vscode/extensions" ]

HEALTHCHECK NONE

# expose port
EXPOSE 8000
