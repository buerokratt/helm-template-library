{{- define "template-library.ingress" -}}
{{- $ingressRoot := .Values.ingress | default dict -}}
{{- if (get $ingressRoot "enabled") -}}
{{- $_ := include "template-library.assertKind" (dict "value" (get $ingressRoot "ingresses") "kind" "map" "path" "ingress.ingresses") }}
{{- $global := .Values.global | default dict -}}
{{- $globalIngress := get $global "ingress" | default dict -}}
{{- $globalDomain := "" -}}
{{- if and (get $global "portalSubDomain") (get $global "baseDomain") -}}
  {{- $globalDomain = printf "%s.%s" (get $global "portalSubDomain") (get $global "baseDomain") -}}
{{- end -}}
{{- $tlsEnabled := true -}}
{{- if hasKey $globalIngress "tlsEnabled" -}}
  {{- $tlsEnabled = get $globalIngress "tlsEnabled" -}}
{{- end -}}
{{- if hasKey $ingressRoot "tlsEnabled" -}}
  {{- $tlsEnabled = get $ingressRoot "tlsEnabled" -}}
{{- end -}}
{{- $defaultClassName := get $ingressRoot "className" | default "" -}}
{{- range $name, $entry := (get $ingressRoot "ingresses" | default dict) -}}
{{- $hosts := get $entry "hosts" | default list -}}
{{- $_ := include "template-library.assertKind" (dict "value" $hosts "kind" "slice" "path" (printf "ingress.ingresses.%s.hosts" $name)) }}
{{- $_ := include "template-library.assertOptionalKind" (dict "parent" $entry "key" "tls" "kind" "slice" "path" (printf "ingress.ingresses.%s.tls" $name)) }}
{{- if not $hosts -}}
  {{- fail (printf "ingress.ingresses.%s.hosts must contain at least one host" $name) -}}
{{- end -}}
{{- printf "\n---\n" }}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ include "template-library.resourceName" (dict "root" $ "suffix" $name "maxLength" 63) }}
  labels:
    {{- include "template-library.mergedLabels" (dict "root" $ "custom" (get $entry "labels" | default dict)) | nindent 4 }}
  {{- with (get $entry "annotations") }}
  annotations:
    {{- include "template-library.stringMap" . | nindent 4 }}
  {{- end }}
spec:
  {{- $className := default $defaultClassName (get $entry "className") }}
  {{- if $className }}
  ingressClassName: {{ $className | quote }}
  {{- end }}
  rules:
    {{- range $host := $hosts }}
    {{- $effectiveHost := include "template-library.ingressHost" (dict "root" $ "entry" $entry "host" $host "globalDomain" $globalDomain) }}
    {{- $_ := include "template-library.assertKind" (dict "value" (get $host "paths") "kind" "slice" "path" (printf "ingress.ingresses.%s.hosts[].paths" $name)) }}
    - host: {{ $effectiveHost | quote }}
      http:
        paths:
          {{- range $path := (get $host "paths" | default list) }}
          {{- $port := required (printf "ingress.ingresses.%s host path.port is required" $name) (get $path "port") }}
          {{- $pathType := default "Prefix" (get $path "pathType") }}
          {{- if not (or (eq $pathType "Exact") (eq $pathType "Prefix") (eq $pathType "ImplementationSpecific")) }}
          {{- fail (printf "ingress.ingresses.%s pathType must be Exact, Prefix, or ImplementationSpecific" $name) }}
          {{- end }}
          - path: {{ default "/" (get $path "path") | quote }}
            pathType: {{ $pathType }}
            backend:
              service:
                name: {{ default (include "template-library.fullname" $) (get $path "backendService") }}
                port:
                  {{- if kindIs "string" $port }}
                  name: {{ $port | quote }}
                  {{- else }}
                  number: {{ include "template-library.integerInRange" (dict "value" $port "min" 1 "max" 65535 "path" (printf "ingress.ingresses.%s host path.port" $name)) }}
                  {{- end }}
          {{- else }}
          {{- fail (printf "ingress.ingresses.%s host must contain at least one path" $name) }}
          {{- end }}
    {{- end }}
  {{- if and $tlsEnabled (get $entry "tls") }}
  tls:
    {{- range $tls := (get $entry "tls") }}
    - hosts:
        {{- if (get $entry "hostOverride") }}
        - {{ include "template-library.ingressHost" (dict "root" $ "entry" $entry "host" (dict) "globalDomain" $globalDomain) | quote }}
        {{- else if (get $tls "hosts") }}
          {{- range $tlsHost := (get $tls "hosts") }}
        - {{ tpl $tlsHost $ | quote }}
          {{- end }}
        {{- else }}
          {{- range $host := $hosts }}
        - {{ include "template-library.ingressHost" (dict "root" $ "entry" $entry "host" $host "globalDomain" $globalDomain) | quote }}
          {{- end }}
        {{- end }}
      {{- with (get $tls "secretName") }}
      secretName: {{ tpl . $ | quote }}
      {{- end }}
    {{- end }}
  {{- end }}
{{- end }}
{{ end }}
{{- end -}}
