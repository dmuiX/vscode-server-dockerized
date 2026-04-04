# vscode-server

A Helm chart to deploy [vscode-server-dockerized](https://github.com/dmuiX/vscode-server-dockerized) on Kubernetes.

## Prerequisites

- Kubernetes 1.19+
- Helm 3.x

## Installation

```bash
helm repo add vscode-server-dockerized https://dmuiX.github.io/vscode-server-dockerized
helm repo update
helm install vscode-server vscode-server-dockerized/vscode-server
```

## Authentication

The chart expects a Kubernetes Secret containing user credentials. Create it before installing:

```bash
kubectl create secret generic credentials \
  --from-literal=username=myuser \
  --from-literal=password=mypassword
```

The secret name and keys are configurable via `values.yaml`:

```yaml
user:
  existingSecret: credentials
  userKey: username
  passwordKey: password
```

The password is mounted as a file at `/run/secrets/password` (as expected by the container entrypoint).
The username is injected as the `USERNAME` environment variable.

## Important Notes

- **Root required**: The container must run as root because the entrypoint changes UID, groups, username and password at startup. It then drops privileges and runs as UID 1000.
- **imagePullSecrets**: If pulling from a private registry (e.g. GHCR), you must configure `imagePullSecrets` in your values.

## Values

| Parameter | Description | Default |
| --- | --- | --- |
| `replicaCount` | Number of replicas | `1` |
| `image.repository` | Container image repository | `ghcr.io/dmuiX/vscode-server-dockerized` |
| `image.tag` | Image tag (defaults to chart `appVersion`) | `""` |
| `image.pullPolicy` | Image pull policy | `IfNotPresent` |
| `imagePullSecrets` | Registry pull secrets | `[]` |
| `user.existingSecret` | Name of the credentials secret | `credentials` |
| `user.userKey` | Key in secret for the username | `username` |
| `user.passwordKey` | Key in secret for the password | `password` |
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
