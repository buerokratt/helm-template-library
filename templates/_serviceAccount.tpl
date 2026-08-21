{{- define "template-library.serviceAccount" -}}
{{- $serviceAccount := .Values.serviceAccount | default dict -}}
{{- if (get $serviceAccount "create") }}
{{- $_ := include "template-library.assertOptionalBool" (dict "parent" $serviceAccount "key" "automountServiceAccountToken" "path" "serviceAccount.automountServiceAccountToken") }}
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ include "template-library.serviceAccountName" . }}
  labels:
    {{- include "template-library.mergedLabels" (dict "root" . "custom" (get $serviceAccount "labels" | default dict)) | nindent 4 }}
  {{- with (get $serviceAccount "annotations") }}
  annotations:
    {{- include "template-library.stringMap" . | nindent 4 }}
  {{- end }}
{{- if hasKey $serviceAccount "automountServiceAccountToken" }}
automountServiceAccountToken: {{ get $serviceAccount "automountServiceAccountToken" }}
{{- end }}
{{- end }}
{{- end -}}
