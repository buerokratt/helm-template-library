{{- define "template-library.cronjob" -}}
{{- $cronRoot := .Values.cronJob | default dict -}}
{{- if (get $cronRoot "enabled") }}
{{- $_ := include "template-library.assertKind" (dict "value" (get $cronRoot "jobs") "kind" "map" "path" "cronJob.jobs") }}
{{- $serviceAccount := .Values.serviceAccount | default dict -}}
{{- range $name, $job := (get $cronRoot "jobs" | default dict) }}
{{- $podSecurityContext := $.Values.podSecurityContext -}}
{{- $podSecuritySet := hasKey $.Values "podSecurityContext" -}}
{{- if hasKey $job "podSecurityContext" -}}{{- $podSecurityContext = get $job "podSecurityContext" -}}{{- $podSecuritySet = true -}}{{- end -}}
{{- $containerSecurityContext := $.Values.securityContext -}}
{{- $containerSecuritySet := hasKey $.Values "securityContext" -}}
{{- if hasKey $job "securityContext" -}}{{- $containerSecurityContext = get $job "securityContext" -}}{{- $containerSecuritySet = true -}}{{- end -}}
{{- if $podSecuritySet -}}{{- $_ := include "template-library.assertKind" (dict "value" $podSecurityContext "kind" "map" "path" (printf "cronJob.jobs.%s.podSecurityContext" $name)) -}}{{- end -}}
{{- if $containerSecuritySet -}}{{- $_ := include "template-library.assertKind" (dict "value" $containerSecurityContext "kind" "map" "path" (printf "cronJob.jobs.%s.securityContext" $name)) -}}{{- end -}}
{{- $_ := include "template-library.assertOptionalKind" (dict "parent" $job "key" "env" "kind" "slice" "path" (printf "cronJob.jobs.%s.env" $name)) }}
{{- $_ := include "template-library.assertOptionalKind" (dict "parent" $job "key" "envFrom" "kind" "slice" "path" (printf "cronJob.jobs.%s.envFrom" $name)) }}
{{- $_ := include "template-library.assertOptionalKind" (dict "parent" $job "key" "initContainers" "kind" "slice" "path" (printf "cronJob.jobs.%s.initContainers" $name)) }}
{{- $_ := include "template-library.assertOptionalKind" (dict "parent" $job "key" "podLabels" "kind" "map" "path" (printf "cronJob.jobs.%s.podLabels" $name)) }}
{{- $image := get $job "image" | default dict -}}
{{- $globalImage := $.Values.image | default dict -}}
{{- $effectiveImage := mergeOverwrite (deepCopy $globalImage) $image -}}
{{- if and (hasKey $image "tag") (not (hasKey $image "digest")) -}}{{- $_ := unset $effectiveImage "digest" -}}{{- end -}}
{{- $imageReference := include "template-library.imageReference" (dict "image" $effectiveImage "appVersion" $.Chart.AppVersion "path" (printf "cronJob.jobs.%s.image" $name)) -}}
{{- $jobServiceAccountName := include "template-library.serviceAccountName" $ -}}
{{- if hasKey $job "serviceAccountName" -}}
  {{- $jobServiceAccountName = include "template-library.validateDNSName" (dict "value" (required (printf "cronJob.jobs.%s.serviceAccountName cannot be empty" $name) (get $job "serviceAccountName")) "path" (printf "cronJob.jobs.%s.serviceAccountName" $name)) -}}
{{- end -}}
{{- $jobAutomount := get $serviceAccount "automountServiceAccountToken" -}}
{{- $jobAutomountSet := hasKey $serviceAccount "automountServiceAccountToken" -}}
{{- if hasKey $job "automountServiceAccountToken" -}}{{- $jobAutomount = get $job "automountServiceAccountToken" -}}{{- $jobAutomountSet = true -}}{{- end -}}
{{- if and $jobAutomountSet (not (kindIs "bool" $jobAutomount)) -}}{{- fail (printf "cronJob.jobs.%s.automountServiceAccountToken must be a boolean" $name) -}}{{- end -}}
{{- $restartPolicy := default "Never" (get $job "restartPolicy") -}}
{{- if not (or (eq $restartPolicy "Never") (eq $restartPolicy "OnFailure")) -}}{{- fail (printf "cronJob.jobs.%s.restartPolicy must be Never or OnFailure" $name) -}}{{- end -}}
{{- $concurrencyPolicy := default "Forbid" (get $job "concurrencyPolicy") -}}
{{- if not (or (eq $concurrencyPolicy "Allow") (eq $concurrencyPolicy "Forbid") (eq $concurrencyPolicy "Replace")) -}}{{- fail (printf "cronJob.jobs.%s.concurrencyPolicy must be Allow, Forbid, or Replace" $name) -}}{{- end -}}
{{- printf "\n---\n" }}
apiVersion: batch/v1
kind: CronJob
metadata:
  name: {{ include "template-library.resourceName" (dict "root" $ "suffix" $name "maxLength" 52) }}
  labels:
    {{- include "template-library.mergedLabels" (dict "root" $ "custom" (get $job "labels" | default dict)) | nindent 4 }}
  {{- with (get $job "annotations") }}
  annotations:
    {{- include "template-library.stringMap" . | nindent 4 }}
  {{- end }}
spec:
  schedule: {{ required (printf "cronJob.jobs.%s.schedule is required" $name) (get $job "schedule") | quote }}
  {{- with (get $job "timeZone") }}
  timeZone: {{ . | quote }}
  {{- end }}
  concurrencyPolicy: {{ $concurrencyPolicy }}
  {{- if hasKey $job "suspend" }}
  suspend: {{ get $job "suspend" }}
  {{- end }}
  {{- if hasKey $job "startingDeadlineSeconds" }}
  startingDeadlineSeconds: {{ include "template-library.integerInRange" (dict "value" (get $job "startingDeadlineSeconds") "min" 0 "max" 2147483647 "path" (printf "cronJob.jobs.%s.startingDeadlineSeconds" $name)) }}
  {{- end }}
  {{- if hasKey $job "successfulJobsHistoryLimit" }}
  successfulJobsHistoryLimit: {{ include "template-library.integerInRange" (dict "value" (get $job "successfulJobsHistoryLimit") "min" 0 "max" 2147483647 "path" (printf "cronJob.jobs.%s.successfulJobsHistoryLimit" $name)) }}
  {{- else }}
  successfulJobsHistoryLimit: 2
  {{- end }}
  {{- if hasKey $job "failedJobsHistoryLimit" }}
  failedJobsHistoryLimit: {{ include "template-library.integerInRange" (dict "value" (get $job "failedJobsHistoryLimit") "min" 0 "max" 2147483647 "path" (printf "cronJob.jobs.%s.failedJobsHistoryLimit" $name)) }}
  {{- else }}
  failedJobsHistoryLimit: 1
  {{- end }}
  jobTemplate:
    spec:
      {{- if hasKey $job "backoffLimit" }}
      backoffLimit: {{ include "template-library.integerInRange" (dict "value" (get $job "backoffLimit") "min" 0 "max" 2147483647 "path" (printf "cronJob.jobs.%s.backoffLimit" $name)) }}
      {{- else }}
      backoffLimit: 2
      {{- end }}
      {{- if hasKey $job "activeDeadlineSeconds" }}
      activeDeadlineSeconds: {{ include "template-library.integerInRange" (dict "value" (get $job "activeDeadlineSeconds") "min" 1 "max" 2147483647 "path" (printf "cronJob.jobs.%s.activeDeadlineSeconds" $name)) }}
      {{- end }}
      {{- if hasKey $job "ttlSecondsAfterFinished" }}
      ttlSecondsAfterFinished: {{ include "template-library.integerInRange" (dict "value" (get $job "ttlSecondsAfterFinished") "min" 0 "max" 2147483647 "path" (printf "cronJob.jobs.%s.ttlSecondsAfterFinished" $name)) }}
      {{- end }}
      template:
        metadata:
          {{- with (get $job "podAnnotations") }}
          annotations:
            {{- include "template-library.stringMap" . | nindent 12 }}
          {{- end }}
          labels:
            {{- include "template-library.mergedCronJobPodLabels" (dict "root" $ "name" $name "custom" (get $job "podLabels" | default dict)) | nindent 12 }}
        spec:
          restartPolicy: {{ $restartPolicy }}
          serviceAccountName: {{ $jobServiceAccountName }}
          {{- if $jobAutomountSet }}
          automountServiceAccountToken: {{ $jobAutomount }}
          {{- end }}
          {{- if $podSecuritySet }}
          securityContext:
            {{- toYaml $podSecurityContext | nindent 12 }}
          {{- end }}
          {{- with (get $job "volumes") }}
          volumes:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- with (get $job "hostAliases") }}
          hostAliases:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- with (get $job "initContainers") }}
          initContainers:
            {{- range . }}
            {{- $init := deepCopy . -}}
            {{- if not (hasKey $init "imagePullPolicy") -}}
              {{- $_ := set $init "imagePullPolicy" "IfNotPresent" -}}
            {{- end }}
            - {{ toYaml $init | nindent 14 | trim }}
            {{- end }}
          {{- end }}
          containers:
            - name: {{ include "template-library.name" $ }}
              image: {{ $imageReference | quote }}
              imagePullPolicy: {{ default (default "IfNotPresent" (get $globalImage "pullPolicy")) (get $image "pullPolicy") }}
              {{- with (get $job "command") }}
              command:
                {{- toYaml . | nindent 16 }}
              {{- end }}
              {{- with (get $job "args") }}
              args:
                {{- toYaml . | nindent 16 }}
              {{- end }}
              {{- with (get $job "envFrom") }}
              envFrom:
                {{- toYaml . | nindent 16 }}
              {{- end }}
              {{- with (get $job "env") }}
              env:
                {{- toYaml . | nindent 16 }}
              {{- end }}
              {{- $resources := get $job "resources" | default $.Values.resources }}
              {{- with $resources }}
              resources:
                {{- toYaml . | nindent 16 }}
              {{- end }}
              {{- if $containerSecuritySet }}
              securityContext:
                {{- toYaml $containerSecurityContext | nindent 16 }}
              {{- end }}
              {{- with (get $job "volumeMounts") }}
              volumeMounts:
                {{- toYaml . | nindent 16 }}
              {{- end }}
          {{- with $.Values.imagePullSecrets }}
          imagePullSecrets:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- with (get $job "affinity") }}
          affinity:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- with (get $job "topologySpreadConstraints") }}
          topologySpreadConstraints:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- with (get $job "nodeSelector") }}
          nodeSelector:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- with (get $job "tolerations") }}
          tolerations:
            {{- toYaml . | nindent 12 }}
          {{- end }}
{{- end }}
{{- end }}
{{- end -}}
