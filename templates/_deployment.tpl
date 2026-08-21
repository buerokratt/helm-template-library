{{- define "template-library.deployment" -}}
{{- $deployment := .Values.deployment | default dict -}}
{{- if and (ne (include "template-library.workloadEnabled" .) "false") (eq (include "template-library.workloadKind" .) "Deployment") }}
{{- $autoscaling := .Values.autoscaling | default dict -}}
{{- $serviceAccount := .Values.serviceAccount | default dict -}}
{{- $podAnnotations := include "template-library.stringMap" (.Values.podAnnotations | default dict) | fromYaml | default dict -}}
{{- $configMap := .Values.configMap | default dict -}}
{{- $_ := include "template-library.assertKind" (dict "value" .Values.initContainers "kind" "slice" "path" "initContainers") }}
{{- $_ := include "template-library.assertKind" (dict "value" .Values.env "kind" "slice" "path" "env") }}
{{- $_ := include "template-library.assertKind" (dict "value" .Values.envFrom "kind" "slice" "path" "envFrom") }}
{{- $_ := include "template-library.assertKind" (dict "value" .Values.containerPorts "kind" "slice" "path" "containerPorts") }}
{{- $_ := include "template-library.assertKind" (dict "value" .Values.podLabels "kind" "map" "path" "podLabels") }}
{{- $_ := include "template-library.assertOptionalKind" (dict "parent" .Values "key" "podSecurityContext" "kind" "map" "path" "podSecurityContext") }}
{{- $_ := include "template-library.assertOptionalKind" (dict "parent" .Values "key" "securityContext" "kind" "map" "path" "securityContext") }}
{{- $_ := include "template-library.assertOptionalBool" (dict "parent" $serviceAccount "key" "automountServiceAccountToken" "path" "serviceAccount.automountServiceAccountToken") }}
{{- if (get $configMap "enabled") -}}
  {{- $_ := set $podAnnotations "checksum/config" (include "template-library.configMapData" . | sha256sum) -}}
{{- end -}}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "template-library.fullname" . }}
  labels:
    {{- include "template-library.labels" . | nindent 4 }}
  {{- with .Values.annotations }}
  annotations:
    {{- include "template-library.stringMap" . | nindent 4 }}
  {{- end }}
spec:
  {{- with (get $deployment "strategy") }}
  strategy:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- if not (get $autoscaling "enabled") }}
  {{- if hasKey .Values "replicaCount" }}
  replicas: {{ include "template-library.integerInRange" (dict "value" .Values.replicaCount "min" 0 "max" 2147483647 "path" "replicaCount") }}
  {{- else }}
  replicas: 1
  {{- end }}
  {{- end }}
  {{- if hasKey $deployment "revisionHistoryLimit" }}
  revisionHistoryLimit: {{ include "template-library.integerInRange" (dict "value" (get $deployment "revisionHistoryLimit") "min" 0 "max" 2147483647 "path" "deployment.revisionHistoryLimit") }}
  {{- end }}
  selector:
    matchLabels:
      {{- include "template-library.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      {{- with $podAnnotations }}
      annotations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      labels:
        {{- include "template-library.mergedPodLabels" (dict "root" . "custom" (.Values.podLabels | default dict)) | nindent 8 }}
    spec:
      serviceAccountName: {{ include "template-library.serviceAccountName" . }}
      {{- if hasKey $serviceAccount "automountServiceAccountToken" }}
      automountServiceAccountToken: {{ get $serviceAccount "automountServiceAccountToken" }}
      {{- end }}
      {{- if hasKey .Values "podSecurityContext" }}
      securityContext:
        {{- toYaml .Values.podSecurityContext | nindent 8 }}
      {{- end }}
      {{- with .Values.hostAliases }}
      hostAliases:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.volumes }}
      volumes:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.initContainers }}
      initContainers:
        {{- range . }}
        {{- $init := deepCopy . -}}
        {{- if not (hasKey $init "imagePullPolicy") -}}
          {{- $_ := set $init "imagePullPolicy" "IfNotPresent" -}}
        {{- end }}
        - {{ toYaml $init | nindent 10 | trim }}
        {{- end }}
      {{- end }}
      containers:
        - name: {{ include "template-library.name" . }}
          {{- $image := .Values.image | default dict }}
          image: {{ include "template-library.imageReference" (dict "image" $image "appVersion" .Chart.AppVersion "path" "image") | quote }}
          imagePullPolicy: {{ default "IfNotPresent" (get $image "pullPolicy") }}
          {{- with .Values.command }}
          command:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- with .Values.args }}
          args:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- with .Values.containerPorts }}
          ports:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- with .Values.envFrom }}
          envFrom:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- with .Values.env }}
          env:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- with .Values.livenessProbe }}
          livenessProbe:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- with .Values.readinessProbe }}
          readinessProbe:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- with .Values.startupProbe }}
          startupProbe:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- with .Values.lifecycle }}
          lifecycle:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- with .Values.resources }}
          resources:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- if hasKey .Values "securityContext" }}
          securityContext:
            {{- toYaml .Values.securityContext | nindent 12 }}
          {{- end }}
          {{- with .Values.volumeMounts }}
          volumeMounts:
            {{- toYaml . | nindent 12 }}
          {{- end }}
        {{- range .Values.additionalContainers | default list }}
        - {{- toYaml . | nindent 10 }}
        {{- end }}
      {{- with .Values.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.affinity }}
      affinity:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.topologySpreadConstraints }}
      topologySpreadConstraints:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.dnsConfig }}
      dnsConfig:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.dnsPolicy }}
      dnsPolicy: {{ . }}
      {{- end }}
{{- end }}
{{- end -}}
