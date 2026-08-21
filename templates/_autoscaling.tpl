{{- define "template-library.autoscaling" -}}
{{- $autoscaling := .Values.autoscaling | default dict -}}
{{- if (get $autoscaling "enabled") }}
{{- if eq (include "template-library.workloadEnabled" .) "false" -}}{{- fail "autoscaling.enabled requires an enabled workload" -}}{{- end -}}
{{- $kind := include "template-library.workloadKind" . -}}
{{- if eq $kind "DaemonSet" -}}{{- fail "autoscaling does not support DaemonSet targets" -}}{{- end -}}
{{- $minValue := 1 -}}
{{- if hasKey $autoscaling "minReplicas" -}}{{- $minValue = get $autoscaling "minReplicas" -}}{{- end -}}
{{- $minReplicas := include "template-library.integerInRange" (dict "value" $minValue "min" 1 "max" 2147483647 "path" "autoscaling.minReplicas") | int64 -}}
{{- $maxReplicas := include "template-library.integerInRange" (dict "value" (required "autoscaling.maxReplicas is required when autoscaling is enabled" (get $autoscaling "maxReplicas")) "min" 1 "max" 2147483647 "path" "autoscaling.maxReplicas") | int64 -}}
{{- if lt $maxReplicas $minReplicas -}}
{{- fail "autoscaling.maxReplicas must be greater than or equal to autoscaling.minReplicas" -}}
{{- end -}}
{{- $hasCPU := hasKey $autoscaling "targetCpuUtilizationPercentage" -}}
{{- $hasMemory := hasKey $autoscaling "targetMemoryUtilizationPercentage" -}}
{{- $cpuTarget := 0 -}}
{{- $memoryTarget := 0 -}}
{{- if $hasCPU -}}{{- $cpuTarget = include "template-library.integerInRange" (dict "value" (get $autoscaling "targetCpuUtilizationPercentage") "min" 1 "max" 2147483647 "path" "autoscaling.targetCpuUtilizationPercentage") | int64 -}}{{- end -}}
{{- if $hasMemory -}}{{- $memoryTarget = include "template-library.integerInRange" (dict "value" (get $autoscaling "targetMemoryUtilizationPercentage") "min" 1 "max" 2147483647 "path" "autoscaling.targetMemoryUtilizationPercentage") | int64 -}}{{- end -}}
{{- if not (or $hasCPU $hasMemory) -}}
{{- fail "autoscaling requires targetCpuUtilizationPercentage and/or targetMemoryUtilizationPercentage" -}}
{{- end -}}
{{- $resources := .Values.resources | default dict -}}
{{- $requests := get $resources "requests" | default dict -}}
{{- if and $hasCPU (not (get $requests "cpu")) -}}
{{- fail "autoscaling.targetCpuUtilizationPercentage requires resources.requests.cpu" -}}
{{- end -}}
{{- if and $hasMemory (not (get $requests "memory")) -}}
{{- fail "autoscaling.targetMemoryUtilizationPercentage requires resources.requests.memory" -}}
{{- end -}}
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: {{ include "template-library.fullname" . }}
  labels:
    {{- include "template-library.labels" . | nindent 4 }}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: {{ default $kind (get $autoscaling "targetKind") }}
    name: {{ default (include "template-library.workloadName" .) (get $autoscaling "targetName") }}
  minReplicas: {{ $minReplicas }}
  maxReplicas: {{ $maxReplicas }}
  metrics:
    {{- if $hasCPU }}
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: {{ $cpuTarget }}
    {{- end }}
    {{- if $hasMemory }}
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: {{ $memoryTarget }}
    {{- end }}
  {{- with (get $autoscaling "behavior") }}
  behavior:
    {{- toYaml . | nindent 4 }}
  {{- end }}
{{- end }}
{{- end -}}
