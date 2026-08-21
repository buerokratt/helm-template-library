{{- define "template-library.serviceEntry" -}}
{{- $root := .root -}}
{{- $entry := .entry -}}
{{- $name := required "services[].name is required" (get $entry "name") -}}
{{- $type := default "ClusterIP" (get $entry "type") -}}
{{- if not (has $type (list "ClusterIP" "NodePort" "LoadBalancer" "ExternalName")) -}}{{- fail (printf "service %s has invalid type %s" $name $type) -}}{{- end -}}
{{- if and (ne $type "ExternalName") (eq (include "template-library.workloadEnabled" $root) "false") (not (hasKey $entry "selector")) -}}{{- fail (printf "service %s requires an enabled workload or an explicit selector" $name) -}}{{- end -}}
apiVersion: v1
kind: Service
metadata:
  name: {{ include "template-library.validateDNSName" (dict "value" $name "path" "services[].name") }}
  labels:
    {{- include "template-library.mergedLabels" (dict "root" $root "custom" (get $entry "labels" | default dict)) | nindent 4 }}
  {{- with (get $entry "annotations") }}
  annotations:
    {{- include "template-library.stringMap" . | nindent 4 }}
  {{- end }}
spec:
  type: {{ $type }}
  {{- if eq $type "ExternalName" }}
  externalName: {{ required "externalName is required for ExternalName services" (get $entry "externalName") | quote }}
  {{- else }}
  {{- if hasKey $entry "clusterIP" }}
  clusterIP: {{ get $entry "clusterIP" | quote }}
  {{- end }}
  {{- with (get $entry "clusterIPs") }}
  clusterIPs:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- if hasKey $entry "publishNotReadyAddresses" }}
  publishNotReadyAddresses: {{ get $entry "publishNotReadyAddresses" }}
  {{- end }}
  ports:
    {{- range $portName, $port := (required (printf "services.%s.ports is required" .key) (get $entry "ports")) }}
    - name: {{ include "template-library.validatePortName" (dict "value" $portName "path" "service port name") | quote }}
      port: {{ required (printf "service port %s.port is required" $portName) (get $port "port") }}
      protocol: {{ default "TCP" (get $port "protocol") }}
      targetPort: {{ default (get $port "port") (get $port "targetPort") }}
      {{- with (get $port "appProtocol") }}
      appProtocol: {{ . | quote }}
      {{- end }}
      {{- with (get $port "nodePort") }}
      nodePort: {{ . }}
      {{- end }}
    {{- end }}
  selector:
    {{- if hasKey $entry "selector" }}
    {{- toYaml (get $entry "selector") | nindent 4 }}
    {{- else }}
    {{- include "template-library.selectorLabels" $root | nindent 4 }}
    {{- end }}
  {{- end }}
{{- end -}}

{{- define "template-library.service" -}}
{{- range $key, $entry := (.Values.services | default dict) }}
{{- printf "\n---\n" }}
{{- include "template-library.serviceEntry" (dict "root" $ "entry" $entry "key" $key) }}
{{- end }}
{{- end -}}
