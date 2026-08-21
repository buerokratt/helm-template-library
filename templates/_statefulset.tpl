{{- define "template-library.statefulset" -}}
{{- $cfg := .Values.statefulSet | default dict -}}
{{- if and (eq (include "template-library.workloadKind" .) "StatefulSet") (ne (include "template-library.workloadEnabled" .) "false") }}
{{- $sa := .Values.serviceAccount | default dict -}}
{{- $_ := include "template-library.assertOptionalKind" (dict "parent" .Values "key" "podSecurityContext" "kind" "map" "path" "podSecurityContext") }}
{{- $_ := include "template-library.assertOptionalKind" (dict "parent" .Values "key" "securityContext" "kind" "map" "path" "securityContext") }}
{{- $_ := include "template-library.assertOptionalBool" (dict "parent" $sa "key" "automountServiceAccountToken" "path" "serviceAccount.automountServiceAccountToken") }}
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: {{ include "template-library.workloadName" . }}
  labels:
    {{- include "template-library.labels" . | nindent 4 }}
spec:
  serviceName: {{ required "statefulSet.serviceName is required" (get $cfg "serviceName") }}
  {{- if not (get (.Values.autoscaling | default dict) "enabled") }}
  replicas: {{ default 1 .Values.replicaCount }}
  {{- end }}
  podManagementPolicy: {{ default "OrderedReady" (get $cfg "podManagementPolicy") }}
  updateStrategy:
    {{- toYaml (get $cfg "updateStrategy" | default (dict "type" "RollingUpdate")) | nindent 4 }}
  {{- if hasKey $cfg "revisionHistoryLimit" }}
  revisionHistoryLimit: {{ include "template-library.integerInRange" (dict "value" (get $cfg "revisionHistoryLimit") "min" 0 "max" 2147483647 "path" "statefulSet.revisionHistoryLimit") }}
  {{- end }}
  selector:
    matchLabels:
      {{- include "template-library.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      labels:
        {{- include "template-library.mergedPodLabels" (dict "root" . "custom" (.Values.podLabels | default dict)) | nindent 8 }}
      {{- with .Values.podAnnotations }}
      annotations:
        {{- include "template-library.stringMap" . | nindent 8 }}
      {{- end }}
    spec:
      serviceAccountName: {{ include "template-library.serviceAccountName" . }}
      {{- if hasKey $sa "automountServiceAccountToken" }}
      automountServiceAccountToken: {{ get $sa "automountServiceAccountToken" }}
      {{- end }}
      {{- if hasKey .Values "podSecurityContext" }}
      securityContext:
        {{- toYaml .Values.podSecurityContext | nindent 8 }}
      {{- end }}
      {{- with .Values.initContainers }}
      initContainers:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      containers:
        - name: {{ include "template-library.name" . }}
          image: {{ include "template-library.imageReference" (dict "image" (.Values.image | default dict) "appVersion" .Chart.AppVersion "path" "image") | quote }}
          imagePullPolicy: {{ default "IfNotPresent" (get (.Values.image | default dict) "pullPolicy") }}
          {{- with .Values.command }}
          command: {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- with .Values.args }}
          args: {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- range $key := list "containerPorts" "envFrom" "env" "livenessProbe" "readinessProbe" "startupProbe" "lifecycle" "resources" "volumeMounts" }}
          {{- with (get $.Values $key) }}
          {{ $key | replace "containerPorts" "ports" }}:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- end }}
          {{- if hasKey .Values "securityContext" }}
          securityContext:
            {{- toYaml .Values.securityContext | nindent 12 }}
          {{- end }}
        {{- range .Values.additionalContainers | default list }}
        - {{- toYaml . | nindent 10 }}
        {{- end }}
      {{- range $key := list "imagePullSecrets" "volumes" "affinity" "topologySpreadConstraints" "nodeSelector" "tolerations" "hostAliases" }}
      {{- with (get $.Values $key) }}
      {{ $key }}:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- end }}
  {{- with (get $cfg "persistentVolumeClaimRetentionPolicy") }}
  persistentVolumeClaimRetentionPolicy:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with (get $cfg "volumeClaimTemplates") }}
  volumeClaimTemplates:
    {{- toYaml . | nindent 4 }}
  {{- end }}
{{- end }}
{{- end -}}
