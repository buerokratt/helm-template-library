{{- define "template-library.pvc" -}}
{{- $pvcRoot := .Values.pvc | default dict -}}
{{- if (get $pvcRoot "enabled") }}
{{- $_ := include "template-library.assertKind" (dict "value" (get $pvcRoot "claims") "kind" "map" "path" "pvc.claims") }}
{{- range $name, $pvc := (get $pvcRoot "claims" | default dict) }}
{{- printf "\n---\n" }}
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: {{ include "template-library.resourceName" (dict "root" $ "suffix" $name "maxLength" 63) }}
  labels:
    {{- include "template-library.mergedLabels" (dict "root" $ "custom" (get $pvc "labels" | default dict)) | nindent 4 }}
  {{- with (get $pvc "annotations") }}
  annotations:
    {{- include "template-library.stringMap" . | nindent 4 }}
  {{- end }}
spec:
  {{- if hasKey $pvc "storageClass" }}
  storageClassName: {{ get $pvc "storageClass" | quote }}
  {{- end }}
  accessModes:
    {{- toYaml (default (list "ReadWriteOnce") (get $pvc "accessModes")) | nindent 4 }}
  {{- with (get $pvc "volumeMode") }}
  volumeMode: {{ . }}
  {{- end }}
  resources:
    requests:
      storage: {{ required (printf "pvc.claims.%s.size is required" $name) (get $pvc "size") | quote }}
  {{- with (get $pvc "selector") }}
  selector:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with (get $pvc "dataSource") }}
  dataSource:
    {{- toYaml . | nindent 4 }}
  {{- end }}
{{- end }}
{{- end }}
{{- end -}}
