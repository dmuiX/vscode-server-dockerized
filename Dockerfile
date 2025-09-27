FROM ubuntu:24.04

ARG USER_PASSWORD_FILE
ENV USER_PASSWORD_FILE=${USER_PASSWORD_FILE:-/run/secrets/user_password}

COPY entrypoint.sh /

RUN apt-get update && \
    export DEBIAN_FRONTEND=noninteractive && \
    apt-get upgrade -y && \
    
    # tools & required packages
    apt-get install -y --no-install-recommends git curl wget ca-certificates gnupg2 software-properties-common \ 
    inetutils-ping dnsutils ncat nmap zsh vim vim-airline vim-airline-themes vim-lastplace sudo bat && \
    
    # terraform
    curl -fsSL https://apt.releases.hashicorp.com/gpg | apt-key add - && \
    apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main" && \
    apt-get update && apt-get install terraform && \

    # digitalocean-cli
    curl -L https://github.com/digitalocean/doctl/releases/download/v${DOCTL_VERSION}/doctl-${DOCTL_VERSION}-linux-amd64.tar.gz | tar -xzC /usr/local/bin
    chmod +x /usr/local/bin/doctl
    doctl version

    # clean up
    apt-get autoremove --purge -y && apt-get autoclean -y && apt-get clean -y && rm -rf /var/lib/apt/lists/* && \
    
    # insiders version
    # fetch latest commit hash for insiders
    
    ARCH="$(dpkg --print-architecture)"
    echo "ARCH: $ARCH"
    
    # Map dpkg architecture to VS Code target strings
    case "$ARCH" in
      amd64) TARGET_API='linux-x64' ; TARGET_DL='cli-linux-x64' ;;
      arm64) TARGET_API='linux-arm64' ; TARGET_DL='cli-linux-arm64' ;;
      *) echo "Unsupported architecture" && exit 1 ;;
    esac
    
    # Fetch latest commit hash for Insiders from corrected API URL with proper target
    COMMIT_HASH=$(wget -qO- https://update.code.visualstudio.com/api/commits/insider/${TARGET_API} | jq -r '.[0]')
    
    echo "Using commit hash: $COMMIT_HASH for Insiders build"
    
    # Download the Insiders build tarball using the commit hash and target
    wget -qO- https://update.code.visualstudio.com/commit:$COMMIT_HASH/${TARGET_DL}/insider | tar xvz -C /opt && \
    chmod +x /opt/code /entrypoint.sh && \
    chown -R ubuntu: /opt/code /entrypoint.sh
    
    # stable
    # install visual studio code and set some permissions
    #CODE_VERSION="latest" && \
    #ARCH="$(dpkg --print-architecture)" && \
    #echo "ARCH: $ARCH" && \
    #case "$ARCH" in \
    #  amd64) export TARGET='cli-linux-x64' ;; \
    #  arm64) export TARGET='cli-linux-arm64' ;; \
    #esac && \
    ##wget -qO- https://update.code.visualstudio.com/${CODE_VERSION}/${TARGET}/stable | tar xvz -C /opt && \
    #chmod +x /opt/code /entrypoint.sh && \
    #chown -R ubuntu: /opt/code /entrypoint.sh && \

    # add user and change the home directory to this user
    touch /home/ubuntu/.zshrc && \
    chown ubuntu:ubuntu /home/ubuntu/.zshrc && \
    chsh -s /usr/bin/zsh ubuntu && \
    
    usermod -aG sudo ubuntu && \
    groupmod -n vscode ubuntu && \
    usermod -l vscode ubuntu && \
    usermod -g users vscode && \
    usermod -d /home/vscode -m vscode
    
# until here everything runs as root! therefore also every file created belongs to root until here if not changed!

USER vscode

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
    curl -fsSL -o /home/vscode/.vimrc https://raw.githubusercontent.com/dmuiX/dotnet-files-linux/refs/heads/main/.vimrc && \
    curl -fsSL -o /home/vscode/.zshrc https://raw.githubusercontent.com/dmuiX/dotnet-files-linux/refs/heads/main/.zshrc && \
    curl -fsSL -o /home/vscode/.p10k https://raw.githubusercontent.com/dmuiX/dotnet-files-linux/refs/heads/main/.p10k

USER root

# Set working directory
WORKDIR /home/vscode

# entrypoint ~/ not working! and also /home/vscode/ not working
ENTRYPOINT [ "/entrypoint.sh" ]

HEALTHCHECK NONE

# expose port
EXPOSE 8000
