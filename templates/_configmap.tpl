{{/* Render the effective ConfigMap data so Deployment can checksum the exact same content. */}}
{{- define "template-library.configMapData" -}}
{{- $config := .Values.configMap | default dict -}}
{{- $global := .Values.global | default dict -}}
{{- $overrides := get $global "configOverrides" | default dict -}}
{{- $_ := include "template-library.assertOptionalKind" (dict "parent" $config "key" "data" "kind" "map" "path" "configMap.data") }}
{{- $_ := include "template-library.assertOptionalKind" (dict "parent" $config "key" "yamlFiles" "kind" "map" "path" "configMap.yamlFiles") }}
{{- $_ := include "template-library.assertOptionalKind" (dict "parent" $config "key" "jsonFiles" "kind" "map" "path" "configMap.jsonFiles") }}
{{- $_ := include "template-library.assertKind" (dict "value" $overrides "kind" "map" "path" "global.configOverrides") }}

{{- $localData := get $config "data" | default dict -}}
{{- $remoteData := get $overrides "data" | default dict -}}
{{- $data := include "template-library.mergeExistingKeys" (dict "local" $localData "override" $remoteData) | fromYaml -}}

{{- $localYamlFiles := get $config "yamlFiles" | default dict -}}
{{- $remoteYamlFiles := get $overrides "yamlFiles" | default dict -}}
{{- $yamlFiles := include "template-library.mergeExistingKeys" (dict "local" $localYamlFiles "override" $remoteYamlFiles) | fromYaml -}}

{{- $localJsonFiles := get $config "jsonFiles" | default dict -}}
{{- $remoteJsonFiles := get $overrides "jsonFiles" | default dict -}}
{{- $jsonFiles := include "template-library.mergeExistingKeys" (dict "local" $localJsonFiles "override" $remoteJsonFiles) | fromYaml -}}

{{- range $key, $value := $data }}
{{- if or (kindIs "map" $value) (kindIs "slice" $value) }}
{{- fail (printf "configMap.data.%s must be a scalar; use yamlFiles or jsonFiles for structured data" $key) }}
{{- end }}
{{ $key | quote }}: {{- if kindIs "invalid" $value }} ""{{- else }} {{ toString $value | quote }}{{- end }}
{{- end }}
{{- range $key, $value := $yamlFiles }}
{{- if hasKey $data $key }}{{- fail (printf "configMap key %s is defined in both data and yamlFiles" $key) }}{{- end }}
{{ $key | quote }}: |
{{ toYaml $value | nindent 2 }}
{{- end }}
{{- range $key, $value := $jsonFiles }}
{{- if or (hasKey $data $key) (hasKey $yamlFiles $key) }}{{- fail (printf "configMap key %s is defined in more than one of data/yamlFiles/jsonFiles" $key) }}{{- end }}
{{ $key | quote }}: |
{{ toPrettyJson $value | nindent 2 }}
{{- end }}
{{- end -}}

{{- define "template-library.configmap" -}}
{{- $config := .Values.configMap | default dict -}}
{{- if (get $config "enabled") }}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "template-library.fullname" . }}
  labels:
    {{- include "template-library.mergedLabels" (dict "root" . "custom" (get $config "labels" | default dict)) | nindent 4 }}
  {{- with (get $config "annotations") }}
  annotations:
    {{- include "template-library.stringMap" . | nindent 4 }}
  {{- end }}
{{- $renderedData := include "template-library.configMapData" . | trim }}
{{- if $renderedData }}
data:
{{ $renderedData | nindent 2 }}
{{- end }}
{{- end }}
{{- end -}}
