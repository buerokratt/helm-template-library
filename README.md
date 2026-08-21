# byk-helm-template-library

`byk-helm-template-library` is a Helm **library chart** containing reusable templates for common Kubernetes resources. It does not install resources by itself. A consumer chart declares the library as a dependency, calls the templates it needs, and supplies their configuration through the consumer chart's own `.Values`.

## Supported versions

- Helm `3.18.4` (release CI) and Helm 4 (developer smoke tests)
- Kubernetes `>=1.27.0-0`, as declared by `Chart.yaml`

## Add the dependency

Add the published OCI chart to the consumer's `Chart.yaml`:

```yaml
dependencies:
  - name: byk-helm-template-library
    version: 1.0.0
    repository: oci://ghcr.io/buerokratt
```

Then resolve and commit the exact dependency and `Chart.lock`:

```bash
helm dependency update
```

Pin an exact version rather than a range. For local development, the executable consumer at [`tests/consumer`](tests/consumer) uses `file://../..` instead of OCI.

## Include resources

Library charts expose named templates. Create `templates/resources.yaml` in the consumer and include the resources it owns:

```gotemplate
{{- include "template-library.deployment" . }}
{{- include "template-library.service" . }}
{{- include "template-library.ingress" . }}
```

The final `.` passes the consumer chart context. The library therefore reads the consumer's top-level values; values do **not** go under a `byk-helm-template-library:` key.

Each include is independent. Adding values for a resource does not render it unless its named template is also included. Most optional resource families also require their `enabled` flag. The complete include list is in the [Values API reference](docs/values.md#template-includes).

## Minimal Deployment and Service

The runnable [`tests/consumer/values.yaml`](tests/consumer/values.yaml) is the minimal example:

```yaml
workload:
  kind: Deployment
  selectorLabels:
    app: phase1-consumer

image:
  repository: registry.example.invalid
  name: phase1-consumer
  tag: "1.0.0"

services:
  http:
    name: phase1-consumer
    ports:
      http:
        port: 8080
```

`workload.selectorLabels` is deliberately explicit and immutable: the same map is copied to the controller selector and pod labels, and is the default selector for Services and other targeting resources. A pod label cannot override one of these labels.

See the [complete Values API](docs/values.md) for required fields, defaults, constraints, and Kubernetes-native pass-through structures. Additional runnable overlays are in [`tests/consumer/examples`](tests/consumer/examples).

## Render and validate

From a consumer chart directory:

```bash
helm dependency update
helm lint .
helm template my-release .
```

To try this repository's consumer and an example overlay:

```bash
helm dependency build tests/consumer
helm lint tests/consumer --strict
helm template example tests/consumer
helm template example tests/consumer -f tests/consumer/examples/web-app.yaml
```

Run the complete contract checks with `./scripts/test.sh`. The script lints the library and consumer, renders default and configured paths, checks intentional validation failures, and renders every example overlay.

## Security-sensitive fields

Security-sensitive Kubernetes fields have no library-imposed defaults. Omission means omission and leaves behavior to Kubernetes or admission policy. Set them deliberately when required:

```yaml
deployment:
  revisionHistoryLimit: 3
serviceAccount:
  automountServiceAccountToken: false
podSecurityContext:
  seccompProfile:
    type: RuntimeDefault
securityContext:
  allowPrivilegeEscalation: false
  capabilities:
    drop: [ALL]
```

Init and additional containers are rendered as supplied and receive no hidden security mutation.

## Release and rollback

Pushes do not publish. An authorized `v1.0.0` tag matching `Chart.yaml` runs tests, packages the chart, records a SHA-256 checksum, pushes to GHCR, and proves a clean OCI consumer can build, lint, and render. Roll back a consumer by reverting its exact dependency version and `Chart.lock`; never move or overwrite an existing tag.
