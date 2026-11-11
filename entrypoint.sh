#!/bin/bash
# Never trace credentials, even when DEBUG=true or Bash inherits tracing flags.
set +x
set +v
set -euo pipefail
umask 077

# 1. Set default values
USERNAME=${USERNAME:-vscode}
PUID=${PUID:-1000}
PGID=${PGID:-1000}

# Validate before any account changes. UID/GID 0 would bypass privilege dropping.
if [[ ! "$PUID" =~ ^[1-9][0-9]*$ || ! "$PGID" =~ ^[1-9][0-9]*$ ]]; then
    echo "PUID and PGID must be positive, non-root numeric IDs." >&2
    exit 1
fi
if [[ ! "$USERNAME" =~ ^[a-z_][a-z0-9_-]{0,31}$ || "$USERNAME" == root ]]; then
    echo "USERNAME must be a non-root Linux account name (up to 32 characters)." >&2
    exit 1
fi
if [[ -z "${CONNECTION_TOKEN_FILE:-}" || ! -r "$CONNECTION_TOKEN_FILE" || ! -s "$CONNECTION_TOKEN_FILE" ]]; then
    echo "CONNECTION_TOKEN_FILE must reference a readable, nonempty token file." >&2
    exit 1
fi
TOKEN=$(< "$CONNECTION_TOKEN_FILE")
if [[ ! "$TOKEN" =~ ^[a-zA-Z0-9_-]{32,}$ ]]; then
    echo "The connection token must contain at least 32 letters, digits, underscores or hyphens." >&2
    exit 1
fi
unset TOKEN

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


# Fail closed if an existing named account does not match the requested UID.
if [[ "$(id -u "$USERNAME")" != "$PUID" ]]; then
    echo "The account UID does not match PUID; refusing to start." >&2
    exit 1
fi
if ! gosu "$USERNAME" test -r "$CONNECTION_TOKEN_FILE"; then
    echo "The connection token file must be readable by the runtime user." >&2
    exit 1
fi

# 5. Set the optional sudo password without shell tracing or credential logging.
if [[ -n "${USER_PASSWORD_FILE:-}" ]]; then
  if [[ ! -r "$USER_PASSWORD_FILE" || ! -s "$USER_PASSWORD_FILE" ]]; then
    echo "USER_PASSWORD_FILE must reference a readable, nonempty password file." >&2
    exit 1
  fi
  NEWPW=$(< "$USER_PASSWORD_FILE")
  if [[ -z "$NEWPW" || "$NEWPW" == *$'\n'* || "$NEWPW" == *$'\r'* ]]; then
    echo "The sudo password must be a nonempty single line." >&2
    exit 1
  fi
  printf '%s:%s\n' "$USERNAME" "$NEWPW" | chpasswd
  unset NEWPW
fi
install -d -m 0700 -o "$PUID" -g "$PGID" "/home/$USERNAME/.vscode"

# 6. Log final state and execute main application
echo "
Container starting with:
User:  $(id -u "${USERNAME}") (${USERNAME})
Group: $(id -g "${USERNAME}")
Home:  /home/${USERNAME}
"

exec gosu "${USERNAME}" /opt/code-insiders \
    serve-web \
    --connection-token-file "$CONNECTION_TOKEN_FILE" \
    --accept-server-license-terms \
    --host 0.0.0.0 \
    --port 8000 \
    --server-data-dir "/home/${USERNAME}/.vscode/server-data" \
    --cli-data-dir "/home/${USERNAME}/.vscode/cli-data" \
    --log-to-file "/home/${USERNAME}/.vscode/serve-web.log" \
    > /dev/null
# The CLI prints a token-bearing URL to stdout even with --log off. Suppress
# stdout; --log-to-file retains diagnostics without that startup URL.
