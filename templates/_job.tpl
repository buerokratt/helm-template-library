{{- define "template-library.job" -}}
{{- $root := .Values.job | default dict -}}
{{- if (get $root "enabled") }}
{{- range $name, $job := (get $root "jobs" | default dict) }}
{{- printf "\n---\n" }}
apiVersion: batch/v1
kind: Job
metadata:
  name: {{ default (include "template-library.resourceName" (dict "root" $ "suffix" $name "maxLength" 63)) (get $job "name") }}
  labels:
    {{- include "template-library.mergedLabels" (dict "root" $ "custom" (get $job "labels" | default dict)) | nindent 4 }}
  {{- with (get $job "annotations") }}
  annotations:
    {{- include "template-library.stringMap" . | nindent 4 }}
  {{- end }}
spec:
  backoffLimit: {{ default 2 (get $job "backoffLimit") }}
  {{- with (get $job "activeDeadlineSeconds") }}
  activeDeadlineSeconds: {{ . }}
  {{- end }}
  {{- if hasKey $job "ttlSecondsAfterFinished" }}
  ttlSecondsAfterFinished: {{ get $job "ttlSecondsAfterFinished" }}
  {{- end }}
  template:
    metadata:
      labels:
        {{- include "template-library.labels" $ | nindent 8 }}
      {{- with (get $job "podAnnotations") }}
      annotations:
        {{- include "template-library.stringMap" . | nindent 8 }}
      {{- end }}
    spec:
      restartPolicy: {{ default "Never" (get $job "restartPolicy") }}
      serviceAccountName: {{ default (include "template-library.serviceAccountName" $) (get $job "serviceAccountName") }}
      {{- with (get $job "initContainers") }}
      initContainers:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      containers:
        - name: {{ default $name (get $job "containerName") }}
          {{- $image := get $job "image" | default $.Values.image | default dict }}
          image: {{ include "template-library.imageReference" (dict "image" $image "appVersion" $.Chart.AppVersion "path" (printf "job.jobs.%s.image" $name)) | quote }}
          imagePullPolicy: {{ default "IfNotPresent" (get $image "pullPolicy") }}
          {{- range $key := list "command" "args" "envFrom" "env" "resources" "securityContext" "volumeMounts" }}
          {{- with (get $job $key) }}
          {{ $key }}:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- end }}
        {{- range (get $job "additionalContainers") | default list }}
        - {{- toYaml . | nindent 10 }}
        {{- end }}
      {{- range $key := list "imagePullSecrets" "volumes" "affinity" "nodeSelector" "tolerations" "topologySpreadConstraints" }}
      {{- with (get $job $key) }}
      {{ $key }}:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- end }}
{{- end }}
{{- end }}
{{- end -}}
