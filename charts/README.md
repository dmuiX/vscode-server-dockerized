# vscode-server

A Helm chart to deploy [vscode-server-dockerized](https://github.com/dmuiX/vscode-server-dockerized) on Kubernetes.

## Prerequisites

- Kubernetes 1.19+
- Helm 3.x

## Installation

Prepare the credentials and trusted ingress policy described below before installing. The defaults deny ingress and require a connection token; the hardened chart must be used with the hardened image.

```bash
helm repo add vscode-server-dockerized https://dmuiX.github.io/vscode-server-dockerized
helm repo update
helm install vscode-server vscode-server-dockerized/vscode-server -f trusted-ingress.yaml
```

## Authentication

The chart expects a Secret containing the username, sudo password and a separate random web connection token. Prepare `sudo-password` and `connection-token` files through your secret manager; never commit them. The token must contain at least 32 letters, digits, underscores or hyphens.

```bash
kubectl create secret generic vscode-server-credentials \
  --from-literal=username=vscode \
  --from-file=password=./sudo-password \
  --from-file=connection-token=./connection-token
```

The secret name and keys are configurable via `values.yaml`:

```yaml
user:
  existingSecret: vscode-server-credentials
  userKey: username
  passwordKey: password
  connectionTokenKey: connection-token
```

The password and token are mounted read-only at `/etc/vscode-secrets/password` and `/etc/vscode-secrets/connection-token`. The username is injected as `USERNAME`. Missing credentials prevent startup. Web authentication uses the token, not the sudo password. Open the HTTPS endpoint with `?tkn=<connection-token>` privately; never put token values in Helm values, probe URLs, or shared logs.

## Network isolation

Ingress NetworkPolicy is enabled with no allowed peers by default. A compatible CNI must enforce it. Save an allow rule for your actual ingress controller as `trusted-ingress.yaml`, for example:

```yaml
networkPolicy:
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: ingress-nginx
          podSelector:
            matchLabels:
              app.kubernetes.io/name: ingress-nginx
              app.kubernetes.io/component: controller
      ports:
        - protocol: TCP
          port: vscode-server
```

Both selectors must match. Adapt them to your controller, terminate TLS there and retain token authentication. Egress remains available for normal development; this policy does not isolate outbound traffic. Kubernetes node/probe traffic has NetworkPolicy exceptions, so policy is not a substitute for authentication. Configure extra trusted peers explicitly when needed.

`helm test` now expects HTTP 403 without credentials. To run it with ingress policy enabled, explicitly permit the same-namespace test pod labeled `app.kubernetes.io/component: connection-test` on the `vscode-server` port for the duration of the test; the default deny policy intentionally does not grant it access.

## Important Notes

- **Root initialization and sudo are intentional**: The entrypoint initializes accounts as root, then runs VS Code as UID 1000 by default. UID/GID 0 and root usernames are rejected. Password-based sudo remains available; `allowPrivilegeEscalation: false` would prevent it. Never use privileged mode, host namespaces, Docker-socket mounts or sensitive host mounts.
- **Upgrade preparation**: Add `connection-token` to the existing credentials Secret and configure trusted ingress before rolling out the hardened chart/image. Probe overrides must not use unauthenticated HTTP success checks; defaults use TCP. Do not combine the new chart with an old unauthenticated image.
- **imagePullSecrets**: If pulling from a private registry (e.g. GHCR), you must configure `imagePullSecrets` in your values.

## Values

| Parameter | Description | Default |
| --- | --- | --- |
| `replicaCount` | Number of replicas | `1` |
| `image.repository` | Container image repository | `ghcr.io/dmuiX/vscode-server-dockerized` |
| `image.tag` | Image tag (defaults to chart `appVersion`) | `""` |
| `image.pullPolicy` | Image pull policy | `IfNotPresent` |
| `imagePullSecrets` | Registry pull secrets | `[]` |
| `user.existingSecret` | Name of the credentials secret | `vscode-server-credentials` |
| `user.userKey` | Key in secret for the username | `username` |
| `user.passwordKey` | Key in secret for the sudo password | `password` |
| `user.connectionTokenKey` | Key in secret for the separate web token | `connection-token` |
| `networkPolicy.enabled` | Render ingress NetworkPolicy (requires CNI enforcement) | `true` |
| `networkPolicy.ingress` | Explicit trusted ingress rules; empty denies ingress | `[]` |
| `service.type` | Kubernetes service type | `ClusterIP` |
| `service.port` | Service port | `8000` |
| `resources.requests.cpu` | CPU request | `100m` |
| `resources.requests.memory` | Memory request | `128Mi` |
| `volumes` | Additional volumes | `[]` |
| `volumeMounts` | Additional volume mounts | `[]` |
| `nodeSelector` | Node selector | `{}` |
| `tolerations` | Tolerations | `[]` |
| `affinity` | Affinity rules | `{}` |

## Naming

Everything is called `vscode-server-dockerized` for consistency:

| Thing | Name | Where it's set |
| --- | --- | --- |
| GitHub repo | `vscode-server-dockerized` | GitHub |
| Docker image | `ghcr.io/dmuix/vscode-server-dockerized` | Dockerfile / GHCR |
| Helm repo alias | `vscode-server-dockerized` | `helm repo add` (your choice) |
| Helm chart name | `vscode-server` | `charts/Chart.yaml` |
| Helm release name | `vscode-server` | `helm install` / HelmRelease (your choice) |

## Learnings

Hosting a Helm chart repo privately via `raw.githubusercontent.com` was painful:

- Requires creating and managing multiple secrets (registry pull secrets, Flux `secretRef`, Renovate host rules)
- Renovate cannot authenticate against `raw.githubusercontent.com` for private repos (sends `Authorization` header, but GitHub expects a signed token URL) — results in silent 404s
- Manual `helm package` + `helm repo index` committed to `main` is fragile and clutters the repo with `.tgz` artifacts

The solution: make the chart repo public and use [helm/chart-releaser-action](https://github.com/helm/chart-releaser-action). It automates packaging, GitHub Releases, and `gh-pages` index management — no manual steps needed.

- most awful thing was to get the secrets right
i needed a github pullsecret in form of a dockerconfig but also a github credentials for the helmrelease kind of mixed up both
- and to get the helmrelease repo address correct
And this secret here
    user:
      existingSecret: vscode-server-credentials
      userKey: username
      passwordKey: password
