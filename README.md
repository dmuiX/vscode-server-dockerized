# vscode-server-dockerized

VS Code Server (Insiders) in a minimal Ubuntu image with Terraform included.
The container runs `code-insiders serve-web` on port `8000`.

## Features

- ✅ VS Code Insiders server (web)
- ✅ Terraform preinstalled
- ✅ Non-root runtime with configurable UID/GID
- ✅ Simple, no-build-step image (plain Dockerfile)

## Quick Start 🚀

Build locally:

```bash
docker build -t vscode-server-dockerized .
```

Provide a randomly generated connection token (at least 32 letters, digits, `_` or `-`) in `connection-token`, and your sudo password in `sudo-password`, using your secret manager. Neither file belongs in Git. Both files must be readable by the configured runtime UID/GID; never make credentials world-readable on the host just to fix a permission error.

Run with read-only credential mounts and a loopback-only port:

```bash
docker run --rm -p 127.0.0.1:8000:8000 \
  -e USERNAME=vscode \
  -e PUID=1000 \
  -e PGID=1000 \
  -e CONNECTION_TOKEN_FILE=/run/secrets/connection-token \
  -e USER_PASSWORD_FILE=/run/secrets/sudo-password \
  -v "$PWD/connection-token:/run/secrets/connection-token:ro" \
  -v "$PWD/sudo-password:/run/secrets/sudo-password:ro" \
  -v vscode-home:/home/vscode \
  vscode-server-dockerized
```

Open `http://127.0.0.1:8000/?tkn=<connection-token>` in your browser, substituting the token privately. The sudo password and the web connection token are separate credentials. Use HTTPS when accessing the server remotely, and do not share token-bearing URLs.

## Configuration ⚙️

Environment variables:

- `USERNAME` (default: `vscode`)
- `PUID` (default: `1000`): Positive numeric UID; UID 0 is rejected
- `PGID` (default: `1000`): Positive numeric GID; GID 0 is rejected
- `CONNECTION_TOKEN_FILE` (required): Runtime-user-readable file containing a random token of at least 32 letters, digits, underscores or hyphens; missing/invalid tokens prevent startup
- `USER_PASSWORD_FILE` (optional): Readable, nonempty single-line sudo password file; omit only if password-based sudo is not needed
- `DEBUG` (default: `false`): Enables build diagnostics and startup account/group traces; tracing stays disabled while reading or processing tokens and passwords

## Volumes 📦

Recommended:

- `/home/<USERNAME>` for user data (extensions, settings, etc.)

Example:

```bash
docker run --rm -p 127.0.0.1:8000:8000 \
  -e CONNECTION_TOKEN_FILE=/run/secrets/connection-token \
  -e USER_PASSWORD_FILE=/run/secrets/sudo-password \
  -v "$PWD/connection-token:/run/secrets/connection-token:ro" \
  -v "$PWD/sudo-password:/run/secrets/sudo-password:ro" \
  -v "$PWD/workspace:/home/vscode/workspace" \
  -v vscode-home:/home/vscode \
  vscode-server-dockerized
```

## Security Notes 🔒

- Built-in connection-token authentication is mandatory. Protect remote access with TLS; use a dedicated random token, not your sudo password.
- The entrypoint starts as root to initialize accounts, then uses `gosu` to run VS Code as the configured non-root UID. **Password-based sudo remains intentionally available.** Do not set `no-new-privileges`/`allowPrivilegeEscalation: false` if you need sudo.
- Do not use privileged mode, host namespaces, the Docker socket, or sensitive host mounts. Container root is not a safe boundary around resources explicitly shared with it.
- With `DEBUG=true`, account/group initialization and non-secret setup are traced. Token validation and the entire password-processing block always run with tracing off; tracing resumes only after credential variables are unset. VS Code CLI stdout is suppressed because upstream prints the connection token there; application diagnostics are written to `/home/<USERNAME>/.vscode/serve-web.log`, with stderr still available through container logs.
- The Docker healthcheck expects HTTP 403 for an unauthenticated request. It checks the authentication listener, not a complete authenticated editor session. Helm probes use TCP to avoid embedding credentials.
- The Helm chart enables ingress NetworkPolicy with no allowed peers by default; configure trusted ingress peers explicitly. Enforcement requires a compatible CNI. Development egress remains available.
- Downloads use TLS verification. Claude Code and its remote shell installer are not included in the image.
- Trivy blocks publication on fixable HIGH/CRITICAL findings. Unfixed findings remain excluded; this is a vulnerability gate, not proof that an image is vulnerability-free.

### Upgrading an existing deployment

Before rolling out the hardened image/chart, add the separate connection-token Secret key and configure trusted ingress peers. Rotate sudo passwords previously used with `DEBUG=true`, and restrict access to historical container logs; this change does not erase already leaked credentials. Keep the existing username/password key names. Otherwise startup or network access will fail closed. Do not roll back to an unauthenticated image merely to restore access; prepare credentials and policy first.

### Local regression tests

```bash
python3 -m unittest discover -s tests -v
bash -n entrypoint.sh
shellcheck -S warning entrypoint.sh
```

Tests use synthetic credentials and stub account-management/application commands; they never change host accounts.

## CI / GHCR 🛠️

📦 The Docker publish workflow builds and pushes the image to GHCR.
🧹 After a successful publish, a cleanup workflow removes old versions while keeping the most recent images and their SBOM/provenance artifacts.
📊 The `pages-build-deployment` workflow is auto-generated by GitHub — it triggers whenever the `gh-pages` branch is updated and deploys the Helm chart index to GitHub Pages. This is not a custom workflow.

NECESSARY:

ghcr classic token
fine grained still dont have package scope

## Project Instructions (Codex/Copilot) 🤖

This repo includes guidance for automated assistants:

- 📘 `AGENTS.md` is used by Codex for contribution rules and coding conventions.
- 🧭 `.github/copilot-instructions.md` is used by GitHub Copilot for editing guidance.
