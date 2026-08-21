{{- define "template-library.podDisruptionBudget" -}}
{{- $pdb := .Values.podDisruptionBudget | default dict -}}
{{- if (get $pdb "enabled") }}
{{- if eq (include "template-library.workloadEnabled" .) "false" -}}
{{- fail "podDisruptionBudget.enabled requires an enabled workload" -}}
{{- end -}}
{{- if and (hasKey $pdb "minAvailable") (hasKey $pdb "maxUnavailable") -}}
{{- fail "podDisruptionBudget.minAvailable and maxUnavailable are mutually exclusive" -}}
{{- end -}}
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: {{ include "template-library.fullname" . }}
  labels:
    {{- include "template-library.labels" . | nindent 4 }}
  {{- with (get $pdb "annotations") }}
  annotations:
    {{- include "template-library.stringMap" . | nindent 4 }}
  {{- end }}
spec:
  {{- if hasKey $pdb "minAvailable" }}
  minAvailable: {{ include "template-library.pdbAvailability" (dict "value" (get $pdb "minAvailable") "path" "podDisruptionBudget.minAvailable") }}
  {{- else if hasKey $pdb "maxUnavailable" }}
  maxUnavailable: {{ include "template-library.pdbAvailability" (dict "value" (get $pdb "maxUnavailable") "path" "podDisruptionBudget.maxUnavailable") }}
  {{- else }}
  maxUnavailable: 1
  {{- end }}
  selector:
    {{- if hasKey $pdb "selector" }}
    {{- toYaml (get $pdb "selector") | nindent 4 }}
    {{- else }}
    matchLabels:
      {{- include "template-library.selectorLabels" . | nindent 6 }}
    {{- end }}
{{- end }}
{{- end -}}
