# kics-scan disable=67fd0c4a-68cf-46d7-8c41-bc9fba7e40ae,965a08d7-ef86-4f14-8792-4a3b2098937e

FROM ubuntu:24.04

ARG VERSION="1.98.1"
ARG USER_PASSWORD_FILE
ENV USER_PASSWORD_FILE=${USER_PASSWORD_FILE:-/run/secrets/user_password}

COPY entrypoint.sh /

# hadolint ignore=DL3008
RUN apt-get update && \
    export DEBIAN_FRONTEND=noninteractive && \
    apt-get upgrade -y && \
    
    # tools & required packages
    apt-get install -y --no-install-recommends git curl wget ca-certificates software-properties-common inetutils-ping dnsutils ncat nmap zsh vim vim-airline vim-airline-themes vim-lastplace sudo && \
    
    # clean up
    apt-get autoremove --purge -y && apt-get autoclean -y && apt-get clean -y && rm -rf /var/lib/apt/lists/* && \
    
    # install visual studio code
    # DEBUG
    VERSION="1.98.1" && \
    ARCH="$(dpkg --print-architecture)" && \
    echo "ARCH: $ARCH" && \
    case "$ARCH" in \
      amd64) export TARGET='cli-linux-x64' ;; \
      arm64) export TARGET='cli-linux-arm64' ;; \
    esac && \
    wget -qO- https://update.code.visualstudio.com/${VERSION}/${TARGET}/stable | tar xvz -C /opt && \
    chmod +x /opt/code /entrypoint.sh && \
    chown -R ubuntu: /opt/code && \

    # add user
    touch /home/ubuntu/.zshrc && \
    chown ubuntu:ubuntu /home/ubuntu/.zshrc && \
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
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/themes/powerlevel10k && \
    curl -fsSL https://raw.githubusercontent.com/dmuiX/dotnet-files-linux/refs/heads/main/.vimrc?token=GHSAT0AAAAAADAG7ML6KJDQN3GCDSNTYBHQZ6QZNHA > /home/vscode/.vimrc && \
    curl -fsSL https://raw.githubusercontent.com/dmuiX/dotnet-files-linux/refs/heads/main/.zshrc?token=GHSAT0AAAAAADAG7ML64RXPAO22XCTT4ENOZ6QZOMA > /home/vscode/.zshrc
    
# entrypoint
ENTRYPOINT [ "/entrypoint.sh" ]

HEALTHCHECK NONE

# expose port
EXPOSE 8000
