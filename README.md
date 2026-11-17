# 💻 vscode-server-dockerized

A browser-based **VS Code Insiders** workspace with Terraform, packaged as an Ubuntu 24.04 container and a Helm chart. It runs the upstream `code-insiders serve-web` command on port **8000**.

> **An authenticated HTTPS reverse proxy is required.** VS Code runs with `--without-connection-token`; the backend has no web login. Block direct client access to port 8000. A private network alone is not authentication.

## 📦 What is included

- A multi-stage [Dockerfile](Dockerfile) with the VS Code Insiders CLI, Terraform, Git, shell utilities and password-based sudo.
- [Root initialization followed by a non-root editor process](entrypoint.sh), with configurable username, UID and GID.
- A [Helm chart](charts/README.md) with a Deployment, ClusterIP Service and an always-present ingress NetworkPolicy that denies ingress by default.
- GitHub Actions for startup regressions, image scanning and publication, SBOM/provenance generation, image signing, chart releases and GHCR retention.

## 🐳 Run with Docker

Prepare an authenticated reverse proxy first. If you need password-based sudo, provision a nonempty, single-line `sudo-password` file through your secret manager; never commit it. Otherwise, omit `USER_PASSWORD_FILE` and its secret mount below.

Create a writable `workspace` directory before using the bind mount. Build and run:

```bash
docker build -t vscode-server-dockerized .

docker run --rm -p 127.0.0.1:8000:8000 \
  -e USERNAME=vscode \
  -e PUID=1000 \
  -e PGID=1000 \
  -e USER_PASSWORD_FILE=/run/secrets/sudo-password \
  -v "$PWD/sudo-password:/run/secrets/sudo-password:ro" \
  -v vscode-home:/home/vscode \
  -v "$PWD/workspace:/home/vscode/workspace" \
  vscode-server-dockerized
```

Point a host-based authenticated proxy at `http://127.0.0.1:8000` and access the editor through its HTTPS endpoint. The sudo password is **not** a web login. For a containerized proxy, use a private Docker network instead of publishing the backend port to clients.

To use the published image instead of building locally, replace the final image name with `ghcr.io/dmuix/vscode-server-dockerized:latest`. The publish workflow targets **`linux/amd64`**. The Dockerfile also handles `arm64` downloads, but CI does not test or publish that architecture.

## 🔧 Configuration and persistence

| Environment variable | Default | Purpose |
| --- | --- | --- |
| `USERNAME` | `vscode` | Non-root Linux account name; `root` and invalid names are rejected. |
| `PUID` | `1000` | Positive, non-root numeric UID. |
| `PGID` | `1000` | Positive, non-root numeric GID. |
| `USER_PASSWORD_FILE` | Unset | Optional readable, nonempty, single-line sudo password file. Omit if password-based sudo is not needed. |
| `DEBUG` | `false` | Trace non-secret startup/account setup; password processing is excluded. Also available as a build argument for build diagnostics. |

Persist **`/home/<USERNAME>`** for user data. The entrypoint explicitly stores server and CLI state under `.vscode/server-data` and `.vscode/cli-data` in that home directory. Update mount paths if you change `USERNAME`, and make bind-mounted files writable by the selected UID/GID; do not assume arbitrary host files will be re-owned automatically.

The image contains the CLI; the web editor is downloaded on demand. TCP health probes avoid triggering that download. The entrypoint passes `--accept-server-license-terms` when starting the service.

For local builds, `--build-arg UPSTREAM_VERSION=<40-character-commit>` selects a specific Insiders commit; otherwise the latest commit for the architecture is resolved. Terraform follows its latest upstream release at build time, so local builds are not fully version-pinned.

## ☸️ Kubernetes

Use the [chart guide](charts/README.md) for Helm installation, Secret creation and trusted-proxy policy examples. The [default values](charts/values.yaml) and [templates](charts/templates) define the deployment contract:

- The chart requires an existing Secret with `username` and `password` keys by default; `password` is for sudo. The name and keys are configurable under `user`. Unlike the chart, the image can run without a password file. No connection-token Secret is needed.
- The Service defaults to `ClusterIP` on port `8000`. Supply your own authenticated HTTPS proxy and routing; the chart does not create an Ingress or manage web authentication.
- `networkPolicy.ingress: []` denies ingress by default. Explicitly allow only trusted proxy peers. A compatible CNI must enforce NetworkPolicy; this ingress-only policy does not restrict egress, and Kubernetes node/probe exceptions still apply.
- Persistence is not configured by default. Supply home/workspace storage through `volumes` and `volumeMounts`, and configure `imagePullSecrets` if the registry requires authentication.

Before upgrading an existing deployment, configure trusted proxy peers and verify that direct backend access is blocked. Keep the existing username/password Secret keys; no token key is required. With no trusted ingress rules, the default policy intentionally denies access.

## 🔒 Security model and caveats

- **Root at startup, non-root editor:** the entrypoint needs root to initialize accounts, then uses `gosu` to run VS Code as the requested UID. UID/GID 0 are rejected. Do not force a non-root container entrypoint with `--user` or `runAsNonRoot`.
- **Sudo is intentional:** password-based sudo remains available when configured. Do not set `no-new-privileges` / `allowPrivilegeEscalation: false` if you need sudo.
- **Protect the host:** do not use privileged mode, host namespaces, Docker-socket mounts or sensitive host mounts. Container root is not a safe boundary around resources explicitly shared with it.
- **Handle logs as operational data:** password processing runs with tracing off, and tracing resumes only after the password variable is unset. Application stdout/stderr remain visible in container logs. Rotate sudo passwords previously used with `DEBUG=true` and restrict historical logs; the current guards cannot erase older leaks.
- **Know what is downloaded:** VS Code and Terraform downloads use HTTPS with certificate verification. Claude Code and its remote shell installer are not included.

## 🚀 Delivery and validation

### Image and chart publication

The [Docker Publish workflow](.github/workflows/docker-publish.yml) runs on pushes to `main`, a daily schedule and manual dispatch. It checks the date/Insiders-commit image tag and chart release before deciding what to publish.

1. Lint the Dockerfile, build an `amd64` test image and run Trivy. **Fixable HIGH/CRITICAL OS and library findings block the release path**; unfixed findings are excluded.
2. Start the test container, wait for TCP health, request the internal HTTP endpoint without a token and check that synthetic sudo credentials are absent from its logs.
3. Build and push the release image with Buildx **SBOM and provenance**, then **Cosign-sign the image digest** using GitHub OIDC. Tags include `latest`, `YYYY.MM.DD` and `YYYY.MM.DD-<short-commit>`.
4. Update the chart's version and image reference, then use chart-releaser for GitHub Releases and the `gh-pages` chart index. Chart versions use a SemVer-compatible date plus `sha<short-commit>` suffix.

The [cleanup workflow](.github/workflows/cleanup-image-versions.yml) runs after a successful publish workflow or manually. It normally skips an unchanged `latest` digest and applies a three-image retention policy, with subject-digest/date rules to preserve related SBOM/provenance artifacts. Older versions are subject to deletion; archive anything you need to retain.

### What the checks cover—and what they do not

| Check | Scope and limits |
| --- | --- |
| [PR/main regression workflow](.github/workflows/security-checks.yml) | Shell syntax, ShellCheck and [Python startup tests](tests/test_security.py). Tests use synthetic credentials and stub account-management/application commands; they do not change host accounts or run a real editor. |
| Docker health check and Helm readiness/liveness probes | Internal TCP listener only; no editor download or external proxy authentication check. |
| Publish smoke test | Real container startup and internal HTTP access without a token. Tool version-print commands are best-effort, not assertions. It does not test the authenticated proxy. |
| [Helm connection test](charts/templates/tests/test-connection.yaml) | Optional internal HTTP request, not run by these CI workflows. Explicitly allow the same-namespace test pod labeled `app.kubernetes.io/component: connection-test` on the `vscode-server` port before running `helm test`; default ingress rules deny it. |

These workflows do **not** deploy a Kubernetes cluster or verify live CNI enforcement, persistent storage or user-facing authentication. The Trivy gate, SBOM/provenance and signature are delivery controls, not a claim that the image is vulnerability-free or that a deployment is secure.

To run the local startup regression checks:

```bash
python3 -m unittest discover -s tests -v
bash -n entrypoint.sh
shellcheck -S warning entrypoint.sh
```

Contribution guidance is in [AGENTS.md](AGENTS.md) and the [Copilot instructions](.github/copilot-instructions.md).
