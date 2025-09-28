#!/bin/bash
set -euo pipefail
if [ "${DEBUG}" = "true" ]; then set -x; fi

# Default to "vscode" if USERNAME is not set
USERNAME=${USERNAME:-vscode}

# Default to 1000 if PUID/PGID are not set
PUID=${PUID:-1000}
PGID=${PGID:-1000}

# Check if the 'ubuntu' user exists before trying to modify it
if id ubuntu &>/dev/null; then
    # Modify the user and group IDs if they are different
    if [ "$(id -u ubuntu)" -ne "${PUID}" ] || [ "$(id -g ubuntu)" -ne "${PGID}" ]; then
        echo "Changing UID/GID of user 'ubuntu' to ${PUID}/${PGID}"
        groupmod -o -g "${PGID}" ubuntu
        usermod -o -u "${PUID}" ubuntu
    fi

    # Rename user and home directory if the target username is different
    if [ "${USERNAME}" != "ubuntu" ]; then
        echo "Renaming user 'ubuntu' to '${USERNAME}'"
        usermod -l "${USERNAME}" -d "/home/${USERNAME}" -m ubuntu
        groupmod -n "${USERNAME}" ubuntu
    fi
else
    # If the 'ubuntu' user does NOT exist, create the desired user from scratch
    echo "User 'ubuntu' not found. Creating user '${USERNAME}' with UID/GID ${PUID}/${PGID}."
    groupadd -g "${PGID}" "${USERNAME}"
    useradd -u "${PUID}" -g "${PGID}" -m -s /bin/bash "${USERNAME}"
fi

# Change password if the file exists
if [[ -n "${USER_PASSWORD_FILE:-}" && -f "${USER_PASSWORD_FILE}" ]]; then
  NEWPW=$(cat "${USER_PASSWORD_FILE}")
  echo "${USERNAME}:${NEWPW}" | chpasswd
fi

echo "
User: $(id -u "${USERNAME}")
Group: $(id -g "${USERNAME}")
Home: /home/${USERNAME}
"

# Drop privileges and execute the main application.
# `gosu` is a lightweight tool perfect for this. It's like `su` but handles signals properly.
# Using `exec gosu` replaces the root shell process with the final user process.
exec gosu "${USERNAME}" /opt/code-insiders \
    serve-web \
    --without-connection-token \
    --accept-server-license-terms \
    --host 0.0.0.0 \
    --port 8000 \
    --server-data-dir "/home/${USERNAME}/.vscode/server-data" \
    --cli-data-dir "/home/${USERNAME}/.vscode/cli-data"
