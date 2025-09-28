#!/bin/bash
set -e

# Change the password if the password file exists
if [[ -n "$USER_PASSWORD_FILE" && -f "$USER_PASSWORD_FILE" ]]; then
  NEWPW=$(cat "$USER_PASSWORD_FILE")
  expect -c "
    set timeout 10
    spawn passwd
    expect \"Current password:\"
    send \"vscode\r\"
    expect \"New password:\"
    send \"$NEWPW\r\"
    expect \"Retype new password:\"
    send \"$NEWPW\r\"
    expect eof
  "
fi

exec su vscode -c '/opt/code \
    serve-web \
    --without-connection-token \
    --accept-server-license-terms \
    --host 0.0.0.0 \
    --port 8000 \
    --server-data-dir /home/vscode/.vscode/server-data \
    --cli-data-dir /home/vscode/.vscode/cli-data'
