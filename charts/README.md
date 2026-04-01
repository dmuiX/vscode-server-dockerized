# vscode-server

A Helm chart to deploy [vscode-server-dockerized](https://github.com/dmuiX/vscode-server-dockerized) on Kubernetes.

## Prerequisites

- Kubernetes 1.19+
- Helm 3.x

## Installation

```bash
helm repo add vscode-server https://dmuiX.github.io/vscode-server-dockerized
helm repo update
helm install vscode-server vscode-server/vscode-server
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
