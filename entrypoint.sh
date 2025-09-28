#!/bin/bash
set -euo pipefail
if [ "${DEBUG}" = "true" ]; then set -x; fi

# Change password if the file exists. Uses the USERNAME env var.
if [[ -n "${USER_PASSWORD_FILE}" && -f "${USER_PASSWORD_FILE}" ]]; then
  NEWPW=$(cat "${USER_PASSWORD_FILE}")
  expect -c "
    set timeout 10
    spawn passwd
    expect \"Current password:\"
    send \"${USERNAME}\r\"
    expect \"New password:\"
    send \"${NEWPW}\r\"
    expect \"Retype new password:\"
    send \"${NEWPW}\r\"
    expect eof
  "
fi

# Execute the server directly as the current user.
exec /opt/code-insiders \
    serve-web \
    --without-connection-token \
    --accept-server-license-terms \
    --host 0.0.0.0 \
    --port 8000 \
    --server-data-dir "/home/${USERNAME}/.vscode/server-data" \
    --cli-data-dir "/home/${USERNAME}/.vscode/cli-data"
