# vscode-server

A Helm chart to deploy [vscode-server-dockerized](https://github.com/dmuiX/vscode-server-dockerized) on Kubernetes.

## Prerequisites

- Kubernetes 1.19+
- Helm 3.x

## Installation

Prepare the username/password Secret and trusted ingress policy described below before installing. Ingress is denied by default. Web authentication belongs to your reverse proxy; the container runs with `--without-connection-token` and requires no token Secret.

```bash
helm repo add vscode-server-dockerized https://dmuiX.github.io/vscode-server-dockerized
helm repo update
helm install vscode-server vscode-server-dockerized/vscode-server -f trusted-ingress.yaml
```

## Authentication

The chart expects a Secret containing the username and sudo password. Prepare `sudo-password` through your secret manager; never commit it. This password is for sudo inside the container, not web authentication.

```bash
kubectl create secret generic vscode-server-credentials \
  --from-literal=username=vscode \
  --from-file=password=./sudo-password
```

The secret name and keys are configurable via `values.yaml`:

```yaml
user:
  existingSecret: vscode-server-credentials
  userKey: username
  passwordKey: password
```

The password is mounted read-only at `/etc/vscode-secrets/password`; the username is injected as `USERNAME`. No connection-token file or key is required. VS Code intentionally uses `--without-connection-token`: enforce web authentication and HTTPS at the reverse proxy and block direct access to the backend Service/port.

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

Both selectors must match. Adapt them to your controller, enforce authentication there and terminate TLS there. Egress remains available for normal development; this policy does not isolate outbound traffic. Kubernetes node/probe traffic has NetworkPolicy exceptions, so policy is not a substitute for authentication. Configure extra trusted peers explicitly when needed.

`helm test` checks internal HTTP access without a token; it does not test the proxy's authentication. To run it with ingress policy enabled, explicitly permit the same-namespace test pod labeled `app.kubernetes.io/component: connection-test` on the `vscode-server` port for the duration of the test; the default deny policy intentionally does not grant it access.

## Important Notes

- **Root initialization and sudo are intentional**: The entrypoint initializes accounts as root, then runs VS Code as UID 1000 by default. UID/GID 0 and root usernames are rejected. Password-based sudo remains available; `allowPrivilegeEscalation: false` would prevent it. Never use privileged mode, host namespaces, Docker-socket mounts or sensitive host mounts.
- **Upgrade preparation**: Keep the existing username/password Secret; no connection-token key is needed. Configure trusted ingress peers for the authenticated reverse proxy and verify that direct backend access is blocked. Internal probes use TCP and do not test proxy authentication.
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
