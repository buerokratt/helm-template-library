{{- define "template-library.roleBinding" -}}
{{- $rbac := .Values.rbac | default dict -}}
{{- if (get $rbac "enabled") }}
{{- $serviceAccountName := include "template-library.serviceAccountName" . -}}
{{- if eq $serviceAccountName "default" -}}
{{- fail "rbac.enabled requires serviceAccount.create=true or an explicit serviceAccount.name; refusing to bind permissions to the namespace default ServiceAccount" -}}
{{- end -}}
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: {{ include "template-library.fullname" . }}
  labels:
    {{- include "template-library.mergedLabels" (dict "root" . "custom" (get $rbac "labels" | default dict)) | nindent 4 }}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: {{ include "template-library.fullname" . }}
subjects:
  - kind: ServiceAccount
    name: {{ $serviceAccountName }}
    namespace: {{ .Release.Namespace | quote }}
{{- end }}
{{- end -}}
