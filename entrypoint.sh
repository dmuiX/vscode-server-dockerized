#!/bin/bash
# Set password directly from file if specified
[[ -n "$USER_PASSWORD_FILE" && -f "$USER_PASSWORD_FILE" ]] || { echo "Error: Password file $USER_PASSWORD_FILE not found"; exit 1; }
usermod --password $(cat "$USER_PASSWORD_FILE" | openssl passwd -1 -stdin) vscode

/opt/code --user-data-dir /home/vscode/.vscode/user-data --extensions-dir /home/vscode/.vscode/extensions serve-web --without-connection-token --accept-server-license-terms --host 0.0.0.0 --port 8000 --cli-data-dir /home/vscode/.vscode/cli-data --server-data-dir /home/vscode/.vscode/server-data
