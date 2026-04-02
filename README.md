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

Run:

```bash
docker run --rm -p 8000:8000 \
  -e USERNAME=vscode \
  -e PUID=1000 \
  -e PGID=1000 \
  -v vscode-home:/home/vscode \
  vscode-server-dockerized
```

Then open:

```
http://localhost:8000
```

## Configuration ⚙️

Environment variables:

- `USERNAME` (default: `vscode`)
- `PUID` (default: `1000`)
- `PGID` (default: `1000`)
- `USER_PASSWORD_FILE` (optional): Path to a file inside the container containing the user password
- `DEBUG` (default: `false`): Enables shell debug output in Dockerfile and entrypoint

## Volumes 📦

Recommended:

- `/home/<USERNAME>` for user data (extensions, settings, etc.)

Example:

```bash
docker run --rm -p 8000:8000 \
  -v $(pwd):/home/vscode/workspace \
  -v vscode-home:/home/vscode \
  vscode-server-dockerized
```

## Security Notes 🔒

⚠️ The server is started with `--without-connection-token`, which means **no built-in auth**.
Only expose this service behind a trusted reverse proxy or in a private network.

🛡️ The image is scanned for CVEs in the upstream workflow. Findings are reported for visibility only and do not fail the build.

## CI / GHCR 🛠️

📦 The Docker publish workflow builds and pushes the image to GHCR.
🧹 After a successful publish, a cleanup workflow removes old versions while keeping the most recent images and their SBOM/provenance artifacts.

NECESSARY:

ghcr classic token
fine grained still dont have package scope

## Project Instructions (Codex/Copilot) 🤖

This repo includes guidance for automated assistants:

- 📘 `AGENTS.md` is used by Codex for contribution rules and coding conventions.
- 🧭 `.github/copilot-instructions.md` is used by GitHub Copilot for editing guidance.
