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

Run the service behind your authenticated reverse proxy. VS Code intentionally uses `--without-connection-token`; no connection-token file is required. Provide your sudo password in `sudo-password` using your secret manager, and do not commit it.

Run with read-only credential mounts and a loopback-only port:

```bash
docker run --rm -p 127.0.0.1:8000:8000 \
  -e USERNAME=vscode \
  -e PUID=1000 \
  -e PGID=1000 \
  -e USER_PASSWORD_FILE=/run/secrets/sudo-password \
  -v "$PWD/sudo-password:/run/secrets/sudo-password:ro" \
  -v vscode-home:/home/vscode \
  vscode-server-dockerized
```

Point your authenticated reverse proxy at `http://127.0.0.1:8000` and access the editor through the proxy's HTTPS endpoint. The sudo password is not a web login. For a containerized proxy, use a private Docker network instead of publishing the backend port to clients.

## Configuration ⚙️

Environment variables:

- `USERNAME` (default: `vscode`)
- `PUID` (default: `1000`): Positive numeric UID; UID 0 is rejected
- `PGID` (default: `1000`): Positive numeric GID; GID 0 is rejected
- `USER_PASSWORD_FILE` (optional): Readable, nonempty single-line sudo password file; omit only if password-based sudo is not needed
- `DEBUG` (default: `false`): Enables build diagnostics and startup account/group traces; tracing stays disabled while reading or processing the sudo password

## Volumes 📦

Recommended:

- `/home/<USERNAME>` for user data (extensions, settings, etc.)

Example:

```bash
docker run --rm -p 127.0.0.1:8000:8000 \
  -e USER_PASSWORD_FILE=/run/secrets/sudo-password \
  -v "$PWD/sudo-password:/run/secrets/sudo-password:ro" \
  -v "$PWD/workspace:/home/vscode/workspace" \
  -v vscode-home:/home/vscode \
  vscode-server-dockerized
```

## Security Notes 🔒

- VS Code starts with **`--without-connection-token` by default**. The authenticated reverse proxy is the web security boundary: enforce authentication and HTTPS there, and prevent clients from reaching port 8000 directly. A private network alone is not authentication.
- The entrypoint starts as root to initialize accounts, then uses `gosu` to run VS Code as the configured non-root UID. **Password-based sudo remains intentionally available.** Do not set `no-new-privileges`/`allowPrivilegeEscalation: false` if you need sudo.
- Do not use privileged mode, host namespaces, the Docker socket, or sensitive host mounts. Container root is not a safe boundary around resources explicitly shared with it.
- With `DEBUG=true`, account/group initialization and non-secret setup are traced. The entire password-processing block runs with tracing off; tracing resumes only after the password variable is unset. Application stdout and stderr remain visible through container logs.
- Docker and Helm probes check the internal TCP listener without triggering the editor's on-demand download. The publish smoke test separately checks HTTP access without a token. Neither check validates authentication at your external proxy.
- The Helm chart always includes ingress NetworkPolicy with no allowed peers by default; no enable switch or separate policy manifest is required. Configure trusted ingress peers explicitly. Enforcement requires a compatible CNI. Development egress remains available.
- Downloads use TLS verification. Claude Code and its remote shell installer are not included in the image.
- Trivy blocks publication on fixable HIGH/CRITICAL findings. Unfixed findings remain excluded; this is a vulnerability gate, not proof that an image is vulnerability-free.

### Upgrading an existing deployment

Before rolling out the hardened chart, configure trusted ingress peers for your authenticated reverse proxy and verify that direct backend access is blocked. Keep the existing username/password Secret keys; no connection-token key is needed. Rotate sudo passwords previously used with `DEBUG=true` and restrict historical container logs; this change does not erase already leaked credentials. Without trusted ingress rules, the default NetworkPolicy intentionally denies access.

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
