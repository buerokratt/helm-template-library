# Values API reference

This is the public `.Values` contract for version 1.0.0. Values are read from the **consumer chart's root context** when an include is called. “Optional” means a field may be omitted; listed defaults are implemented by templates.

Fields called Kubernetes-native are passed through with `toYaml`. Use the structure of the named Kubernetes API field; this library intentionally does not duplicate that API.

## Template includes

| Include | Output | Activation |
|---|---|---|
| `template-library.deployment` | Deployment | `workload.kind: Deployment`, workload enabled |
| `template-library.statefulset` | StatefulSet | `workload.kind: StatefulSet`, workload enabled |
| `template-library.daemonset` | DaemonSet | `workload.kind: DaemonSet`, workload enabled |
| `template-library.service` | Services | one per `services` entry |
| `template-library.serviceAccount` | ServiceAccount | `serviceAccount.create: true` |
| `template-library.role`, `template-library.roleBinding` | Role and RoleBinding | `rbac.enabled: true` |
| `template-library.configmap` | ConfigMap | `configMap.enabled: true` |
| `template-library.pvc` | PVCs | `pvc.enabled: true` |
| `template-library.ingress` | Ingresses | `ingress.enabled: true` |
| `template-library.job` | Jobs | `job.enabled: true` |
| `template-library.cronjob` | CronJobs | `cronJob.enabled: true` |
| `template-library.networkPolicy` | NetworkPolicies | `networkPolicies.enabled: true` |
| `template-library.autoscaling` | HPA | `autoscaling.enabled: true` |
| `template-library.podDisruptionBudget` | PDB | `podDisruptionBudget.enabled: true` |

An include must exist in the consumer's `templates/` for its values to do anything. Includes can be called unconditionally because activation checks happen inside the library.

## Naming and workload

| Path | Type | Requirement/default | Notes |
|---|---|---|---|
| `nameOverride` | string | optional; chart name | container name, labels |
| `fullnameOverride` | string | optional; release/chart-derived name | primary resource names |
| `workload.kind` | string | required when a controller evaluates; `Deployment`, `StatefulSet`, or `DaemonSet` | controller and HPA target |
| `workload.enabled` | boolean | optional; `true` | disables the selected controller when false |
| `workload.name` | string | optional; generated fullname | StatefulSet/DaemonSet and HPA; Deployment uses fullname |
| `workload.selectorLabels` | map | required, non-empty when a workload/default selector renders | copied exactly into controller selector and pod labels |

Names must be lowercase DNS-1123 names. Treat selector labels as immutable; `podLabels` can add labels but cannot change selector values.

```yaml
workload:
  kind: Deployment
  selectorLabels:
    app: my-service
```

With `workload.enabled: false`, a non-ExternalName Service needs `selector`, and each NetworkPolicy needs `podSelector`.

## Image

| Path | Type | Requirement/default |
|---|---|---|
| `image.repository` | string | required for a rendered main container unless a batch entry supplies its image |
| `image.name` | string | required |
| `image.tag` | string | optional if consumer `Chart.appVersion` exists or digest is used; otherwise required |
| `image.digest` | string | optional; `sha256:` plus 64 hex characters; takes precedence over tag |
| `image.pullPolicy` | string | optional; `IfNotPresent` |

```yaml
image:
  repository: registry.example.com/team
  name: my-service
  tag: "1.0.0"
  pullPolicy: IfNotPresent
```

References are `repository/name:tag`, or `repository/name@digest`.

## Long-running workload

These root values configure the primary Deployment, StatefulSet, or DaemonSet container/pod unless noted.

| Path | Type | Requirement/default | Destination |
|---|---|---|---|
| `replicaCount` | integer | optional; `1`, range 0–2147483647; Deployment/StatefulSet; omitted with HPA | `spec.replicas` |
| `annotations` | map | optional; Deployment only | controller annotations |
| `podLabels`, `podAnnotations` | map | optional | pod metadata |
| `command`, `args` | array | optional | main container |
| `containerPorts` | array | optional | container `ports` |
| `env`, `envFrom` | array | optional | main container |
| `livenessProbe`, `readinessProbe`, `startupProbe` | map | optional | main container |
| `lifecycle`, `resources`, `securityContext` | map | optional; no security default | main container |
| `volumeMounts` | array | optional | main container |
| `additionalContainers` | array | optional; unchanged | pod containers |
| `initContainers` | array | optional; Deployment adds `IfNotPresent` if pull policy absent; other controllers pass through | pod init containers |
| `podSecurityContext` | map | optional; no security default | pod security context |
| `imagePullSecrets`, `volumes`, `topologySpreadConstraints`, `tolerations`, `hostAliases` | array | optional | corresponding PodSpec field |
| `affinity`, `nodeSelector` | map | optional | corresponding PodSpec field |
| `dnsConfig` | map | optional; Deployment only | PodSpec DNS config |
| `dnsPolicy` | string | optional; Deployment only | PodSpec DNS policy |

```yaml
containerPorts:
  - name: http
    containerPort: 8080
env:
  - name: LOG_LEVEL
    value: info
resources:
  requests: {cpu: 100m, memory: 128Mi}
readinessProbe:
  httpGet: {path: /ready, port: http}
```

Controller-specific values:

| Path | Type | Requirement/default |
|---|---|---|
| `deployment.strategy` | map | optional; Kubernetes-native |
| `deployment.revisionHistoryLimit` | integer | optional/omitted; range 0–2147483647 |
| `statefulSet.serviceName` | string | required for StatefulSet |
| `statefulSet.podManagementPolicy` | string | optional; `OrderedReady` |
| `statefulSet.updateStrategy` | map | optional; `{type: RollingUpdate}` |
| `statefulSet.revisionHistoryLimit` | integer | optional/omitted; range 0–2147483647 |
| `statefulSet.persistentVolumeClaimRetentionPolicy` | map | optional; Kubernetes-native |
| `statefulSet.volumeClaimTemplates` | array | optional; Kubernetes-native |
| `daemonSet.updateStrategy` | map | optional/omitted; Kubernetes-native |
| `daemonSet.revisionHistoryLimit` | integer | optional/omitted; range 0–2147483647 |

## Services

`services` is a map. Its keys identify entries; each `name` is the actual Kubernetes Service name.

```yaml
services:
  http:
    name: my-service
    type: ClusterIP
    ports:
      http:
        port: 80
        targetPort: 8080
```

| Entry field | Type | Requirement/default |
|---|---|---|
| `name` | string | required; DNS-1123 |
| `type` | string | optional; `ClusterIP`; also `NodePort`, `LoadBalancer`, `ExternalName` |
| `labels`, `annotations` | map | optional |
| `selector` | map | optional; `workload.selectorLabels`; required with disabled workload except ExternalName |
| `externalName` | string | required for ExternalName |
| `clusterIP` | string | optional |
| `clusterIPs` | array | optional |
| `publishNotReadyAddresses` | boolean | optional |
| `ports` | map | required for non-ExternalName |
| `ports.<id>.port` | integer | required |
| `ports.<id>.targetPort` | integer/string | optional; `port` |
| `ports.<id>.protocol` | string | optional; `TCP` |
| `ports.<id>.appProtocol` | string | optional |
| `ports.<id>.nodePort` | integer | optional |

Port keys become port names: lowercase IANA service names containing a letter, at most 15 characters.

## ServiceAccount and RBAC

| Path | Type | Requirement/default |
|---|---|---|
| `serviceAccount.create` | boolean | optional; `false` |
| `serviceAccount.name` | string | optional; generated when creating, otherwise `default` |
| `serviceAccount.automountServiceAccountToken` | boolean | optional/omitted; created account and workload pods |
| `serviceAccount.labels`, `.annotations` | map | optional |
| `rbac.enabled` | boolean | optional; `false` |
| `rbac.rules` | array | optional; `[]`; Kubernetes PolicyRules |
| `rbac.labels`, `.annotations` | map | optional; annotations apply to Role only |

RBAC refuses to bind the namespace `default` ServiceAccount. Create one or give `serviceAccount.name` a non-default name.

## ConfigMap

```yaml
configMap:
  enabled: true
  data: {LOG_LEVEL: info}
  yamlFiles:
    application.yaml: {featureEnabled: true}
  jsonFiles:
    settings.json: {retries: 3}
```

| Path | Type | Requirement/default |
|---|---|---|
| `configMap.enabled` | boolean | optional; `false` |
| `configMap.labels`, `.annotations` | map | optional |
| `configMap.data` | scalar-value map | optional; converted to strings |
| `configMap.yamlFiles`, `.jsonFiles` | map | optional; values serialized into named keys |
| `global.configOverrides.data`, `.yamlFiles`, `.jsonFiles` | map | optional; recursively replace existing local keys only |

A key may occur in only one data group. Global overrides cannot introduce keys. Enabling the ConfigMap adds an effective-data checksum annotation to a Deployment.

## Ingress

```yaml
ingress:
  enabled: true
  className: nginx
  ingresses:
    public:
      hosts:
        - host: app.example.com
          paths:
            - {path: /, pathType: Prefix, backendService: my-service, port: http}
      tls:
        - secretName: app-tls
```

| Path under `ingress` | Type | Requirement/default |
|---|---|---|
| `enabled` | boolean | optional; `false` |
| `className` | string | optional; entry default |
| `tlsEnabled` | boolean | optional; overrides global value; effective default `true` |
| `ingresses` | map | required map when enabled (may be empty) |
| `ingresses.<id>.className` | string | optional; root class |
| `ingresses.<id>.labels`, `.annotations` | map | optional |
| `ingresses.<id>.hostOverride` | templated string | optional; replaces entry hosts |
| `ingresses.<id>.hosts` | array | required, non-empty |
| `hosts[].host` | templated string | required unless host override/global domain applies |
| `hosts[].useGlobalDomain` | boolean | optional; uses global domain |
| `hosts[].paths` | array | required, non-empty |
| `paths[].path` | string | optional; `/` |
| `paths[].pathType` | string | optional; `Prefix`; also `Exact`, `ImplementationSpecific` |
| `paths[].backendService` | string | optional; generated fullname |
| `paths[].port` | integer/string | required; numeric 1–65535; string becomes named port |
| `ingresses.<id>.tls` | array | optional; only emitted when TLS enabled |
| `tls[].hosts` | templated string array | optional; entry hosts |
| `tls[].secretName` | templated string | optional |
| `global.portalSubDomain`, `global.baseDomain` | string | both required for `useGlobalDomain: true`; joined with `.` |
| `global.ingress.tlsEnabled` | boolean | optional; global TLS switch |

## PersistentVolumeClaims

`pvc.enabled` defaults to false and `pvc.claims` must be a map when enabled. Names become `<fullname>-<claim-key>`.

```yaml
pvc:
  enabled: true
  claims:
    data:
      size: 10Gi
      accessModes: [ReadWriteOnce]
```

| Claim field | Type | Requirement/default |
|---|---|---|
| `size` | string | required |
| `storageClass` | string | optional; explicit `""` requests no class |
| `accessModes` | array | optional; `[ReadWriteOnce]` |
| `volumeMode` | string | optional |
| `selector`, `dataSource` | map | optional; Kubernetes-native |
| `labels`, `annotations` | map | optional |

## Jobs

`job.enabled` defaults to false; every `job.jobs` map entry renders one Job.

| Entry field | Type | Requirement/default |
|---|---|---|
| `name` | string | optional; `<fullname>-<entry-key>` |
| `image` | map | optional; replaces root image; same image fields |
| `containerName` | string | optional; entry key |
| `backoffLimit` | integer | optional; `2` |
| `activeDeadlineSeconds`, `ttlSecondsAfterFinished` | integer | optional |
| `restartPolicy` | string | optional; `Never` |
| `serviceAccountName` | string | optional; root resolved account |
| `labels`, `annotations`, `podAnnotations` | map | optional |
| `command`, `args`, `env`, `envFrom`, `resources`, `securityContext`, `volumeMounts` | Kubernetes container fields | optional |
| `initContainers`, `additionalContainers`, `imagePullSecrets`, `volumes`, `affinity`, `nodeSelector`, `tolerations`, `topologySpreadConstraints` | Kubernetes pod fields | optional |

Most Job fields are passed through without explicit range/enum checks; Kubernetes validates them.

## CronJobs

`cronJob.enabled` defaults to false; `cronJob.jobs` must be a map. Entries inherit root image, resources, security contexts, pull secrets, and ServiceAccount.

```yaml
cronJob:
  enabled: true
  jobs:
    cleanup:
      schedule: "0 2 * * *"
      command: ["/app/cleanup"]
```

| Entry field | Type | Requirement/default |
|---|---|---|
| `schedule` | string | required |
| `timeZone` | string | optional |
| `concurrencyPolicy` | string | optional; `Forbid`; also `Allow`, `Replace` |
| `suspend` | boolean | optional |
| `startingDeadlineSeconds` | integer | optional; min 0 |
| `successfulJobsHistoryLimit`, `failedJobsHistoryLimit` | integer | optional; `2` / `1`; min 0 |
| `backoffLimit` | integer | optional; `2`; min 0 |
| `activeDeadlineSeconds` | integer | optional; min 1 |
| `ttlSecondsAfterFinished` | integer | optional; min 0 |
| `restartPolicy` | string | optional; `Never` or `OnFailure` |
| `image` | map | optional; merged over root; local tag suppresses inherited digest |
| `serviceAccountName` | string | optional; root resolved value; non-empty DNS name when set |
| `automountServiceAccountToken` | boolean | optional; root account value |
| `podSecurityContext`, `securityContext`, `resources` | map | optional; root values |
| `labels`, `annotations`, `podLabels`, `podAnnotations` | map | optional |
| `command`, `args`, `env`, `envFrom`, `volumeMounts` | Kubernetes container fields | optional |
| `initContainers`, `volumes`, `hostAliases`, `affinity`, `topologySpreadConstraints`, `nodeSelector`, `tolerations` | Kubernetes pod fields | optional |

Root `imagePullSecrets` applies. CronJob init containers default missing pull policy to `IfNotPresent`.

## NetworkPolicies

`networkPolicies.enabled` defaults to false; `policies` must be an array. Each policy needs an explicit or rule-derived type.

| Policy field | Type | Requirement/default |
|---|---|---|
| `name` | string | required; name suffix |
| `podSelector` | map | optional; workload selector; required with disabled workload; `{}` selects all |
| `policyTypes` | array | optional; derived from rule presence; only `Ingress`/`Egress` |
| `ingress`, `egress` | array | optional; Kubernetes-native; explicit empty arrays preserved |
| `labels`, `annotations` | map | optional |

A defined rule direction must also appear in `policyTypes`.

## Autoscaling

| Path | Type | Requirement/default |
|---|---|---|
| `autoscaling.enabled` | boolean | optional; `false` |
| `autoscaling.minReplicas` | integer | optional; `1`; min 1 |
| `autoscaling.maxReplicas` | integer | required when enabled; min 1 and >= minimum |
| `autoscaling.targetCpuUtilizationPercentage` | integer | CPU and/or memory target required; min 1 |
| `autoscaling.targetMemoryUtilizationPercentage` | integer | CPU and/or memory target required; min 1 |
| `autoscaling.targetKind`, `.targetName` | string | optional; selected workload kind/name |
| `autoscaling.behavior` | map | optional; Kubernetes HPA behavior |

Requires enabled Deployment/StatefulSet; DaemonSet is rejected. CPU and memory targets respectively require `resources.requests.cpu` and `.memory`. Controller replicas are omitted.

## PodDisruptionBudget

| Path | Type | Requirement/default |
|---|---|---|
| `podDisruptionBudget.enabled` | boolean | optional; `false`; requires enabled workload |
| `podDisruptionBudget.minAvailable` | non-negative integer or `0%`–`100%` | optional |
| `podDisruptionBudget.maxUnavailable` | non-negative integer or `0%`–`100%` | optional; `1` if neither set |
| `podDisruptionBudget.selector` | map | optional; workload selector |
| `podDisruptionBudget.annotations` | map | optional |

The availability fields are mutually exclusive.

## Validation scope

Templates validate stable invariants: required image parts, explicit selectors, enums, ranges, conflicting ConfigMap keys, and cross-field dependencies. Kubernetes-native structures should also be checked against the target cluster.

A `values.schema.json` is intentionally absent. Helm validates a dependency schema against values under the dependency key, while these includes deliberately consume the caller's root `.Values`; a library-owned schema would validate the wrong location. Consumer charts can add a focused schema for the subset they expose.
