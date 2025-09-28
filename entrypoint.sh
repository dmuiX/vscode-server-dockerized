#!/bin/bash
set -euo pipefail
if [ "${DEBUG}" = "true" ]; then set -x; fi

# 1. Set default values
USERNAME=${USERNAME:-vscode}
PUID=${PUID:-1000}
PGID=${PGID:-1000}

# 2. Resolve Group ID conflicts and set the group
# Find the name of the group that currently owns the target GID, if any
EXISTING_GROUP_NAME=$(getent group "${PGID}" | cut -d: -f1 || true)

if [[ -n "${EXISTING_GROUP_NAME}" && "${EXISTING_GROUP_NAME}" != "${USERNAME}" ]]; then
    # If GID is taken by a different group, rename that group to the target username
    echo "GID ${PGID} is taken by group '${EXISTING_GROUP_NAME}'. Renaming it to '${USERNAME}'."
    groupmod -n "${USERNAME}" "${EXISTING_GROUP_NAME}"
elif [[ -z "${EXISTING_GROUP_NAME}" ]]; then
    # If GID is free, create the new group
    echo "GID ${PGID} is free. Creating group '${USERNAME}'."
    groupadd -g "${PGID}" "${USERNAME}"
fi

# 3. Resolve User ID conflicts and set the user
# Find the name of the user that currently owns the target UID, if any
EXISTING_USER_NAME=$(getent passwd "${PUID}" | cut -d: -f1 || true)

if [[ -n "${EXISTING_USER_NAME}" && "${EXISTING_USER_NAME}" != "${USERNAME}" ]]; then
    # If UID is taken by a different user, rename that user and move their home directory
    echo "UID ${PUID} is taken by user '${EXISTING_USER_NAME}'. Renaming them to '${USERNAME}'."
    usermod -l "${USERNAME}" -d "/home/${USERNAME}" -m "${EXISTING_USER_NAME}"
elif [[ -z "${EXISTING_USER_NAME}" ]]; then
    # If UID is free, create the new user
    echo "UID ${PUID} is free. Creating user '${USERNAME}'."
    useradd --shell /bin/bash --uid "${PUID}" --gid "${PGID}" --create-home "${USERNAME}"
fi

# 4. Final state enforcement
# Ensure the user has the correct primary group, just in case
usermod -g "${PGID}" "${USERNAME}"
# Add user to the sudo group to grant administrative privileges if needed
usermod -aG sudo "${USERNAME}"


# 5. Set password if a secret file is provided
if [[ -n "${USER_PASSWORD_FILE:-}" && -f "${USER_PASSWORD_FILE}" ]]; then
  NEWPW=$(cat "${USER_PASSWORD_FILE}")
  echo "${USERNAME}:${NEWPW}" | chpasswd
fi

# 6. Log final state and execute main application
echo "
Container starting with:
User:  $(id -u "${USERNAME}") (${USERNAME})
Group: $(id -g "${USERNAME}")
Home:  /home/${USERNAME}
"

exec gosu "${USERNAME}" /opt/code-insiders \
    serve-web \
    --without-connection-token \
    --accept-server-license-terms \
    --host 0.0.0.0 \
    --port 8000 \
    --server-data-dir "/home/${USERNAME}/.vscode/server-data" \
    --cli-data-dir "/home/${USERNAME}/.vscode/cli-data"
