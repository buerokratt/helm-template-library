{{- define "template-library.role" -}}
{{- $rbac := .Values.rbac | default dict -}}
{{- if (get $rbac "enabled") }}
{{- $_ := include "template-library.assertOptionalKind" (dict "parent" $rbac "key" "rules" "kind" "slice" "path" "rbac.rules") }}
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: {{ include "template-library.fullname" . }}
  labels:
    {{- include "template-library.mergedLabels" (dict "root" . "custom" (get $rbac "labels" | default dict)) | nindent 4 }}
  {{- with (get $rbac "annotations") }}
  annotations:
    {{- include "template-library.stringMap" . | nindent 4 }}
  {{- end }}
rules:
{{- with (get $rbac "rules") }}
{{ toYaml . | nindent 2 }}
{{- else }} []
{{- end }}
{{- end }}
{{- end -}}
