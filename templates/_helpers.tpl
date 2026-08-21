{{/*
Common naming and rendering helpers for the template library.
*/}}

{{- define "template-library.name" -}}
{{- $name := default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- include "template-library.validateDNSName" (dict "value" $name "path" "nameOverride/Chart.Name") -}}
{{- end -}}

{{- define "template-library.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- $fullname := .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- include "template-library.validateDNSName" (dict "value" $fullname "path" "fullnameOverride") -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- $fullname := .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- include "template-library.validateDNSName" (dict "value" $fullname "path" "Release.Name") -}}
{{- else -}}
{{- $fullname := printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- include "template-library.validateDNSName" (dict "value" $fullname "path" "generated fullname") -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "template-library.resourceName" -}}
{{- $root := .root -}}
{{- $suffix := required "template-library.resourceName requires suffix" .suffix -}}
{{- $maxLength := int (default 63 .maxLength) -}}
{{- $raw := printf "%s-%s" (include "template-library.fullname" $root) $suffix -}}
{{- if gt (len $raw) $maxLength -}}
  {{- $hash := sha256sum $raw | trunc 8 -}}
  {{- $prefixLength := int (sub $maxLength 9) -}}
  {{- $result := printf "%s-%s" ($raw | trunc $prefixLength | trimSuffix "-") $hash -}}
  {{- include "template-library.validateDNSName" (dict "value" $result "path" (printf "resource suffix %q" $suffix)) -}}
{{- else -}}
  {{- $result := $raw | trimSuffix "-" -}}
  {{- include "template-library.validateDNSName" (dict "value" $result "path" (printf "resource suffix %q" $suffix)) -}}
{{- end -}}
{{- end -}}

{{/* Validate a Kubernetes DNS-1123 subdomain name and return it unchanged. */}}
{{- define "template-library.validateDNSName" -}}
{{- $value := toString .value -}}
{{- if or (gt (len $value) 253) (not (regexMatch "^[a-z0-9]([-a-z0-9]*[a-z0-9])?(\\.[a-z0-9]([-a-z0-9]*[a-z0-9])?)*$" $value)) -}}
{{- fail (printf "%s must be a lowercase DNS-1123 name (got %q)" .path $value) -}}
{{- end -}}
{{- range $label := splitList "." $value -}}
  {{- if gt (len $label) 63 -}}{{- fail (printf "%s must have DNS labels of at most 63 characters (got %q)" $.path $value) -}}{{- end -}}
{{- end -}}
{{- $value -}}
{{- end -}}

{{- define "template-library.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "template-library.identityLabels" -}}
app.kubernetes.io/name: {{ include "template-library.name" . }}
app.kubernetes.io/instance: {{ .Release.Name | quote }}
{{- end -}}

{{/* Selector used by the long-running Deployment and resources that target it. */}}
{{- define "template-library.selectorLabels" -}}
{{- $workload := .Values.workload | default dict -}}
{{- $selectors := get $workload "selectorLabels" -}}
{{- if not (hasKey $workload "selectorLabels") -}}
  {{- fail "workload.selectorLabels is required and must state the workload selector explicitly" -}}
{{- end -}}
{{- include "template-library.assertKind" (dict "value" $selectors "kind" "map" "path" "workload.selectorLabels") -}}
{{- if eq (len $selectors) 0 -}}{{- fail "workload.selectorLabels must not be empty" -}}{{- end -}}
{{- range $key, $value := $selectors -}}
  {{- if or (eq (toString $key) "") (gt (len (toString $key)) 253) -}}{{- fail (printf "workload.selectorLabels contains invalid key %q" $key) -}}{{- end -}}
  {{- if gt (len (toString $value)) 63 -}}{{- fail (printf "workload.selectorLabels.%s must be at most 63 characters" $key) -}}{{- end -}}
{{- end -}}
{{- toYaml $selectors -}}
{{- end -}}

{{- define "template-library.cronJobSelectorLabels" -}}
{{- $root := .root -}}
{{- $name := .name -}}
{{ include "template-library.identityLabels" $root }}
app.kubernetes.io/component: {{ printf "cronjob-%s" $name | trunc 63 | trimSuffix "-" | quote }}
{{- end -}}

{{- define "template-library.labels" -}}
helm.sh/chart: {{ include "template-library.chart" . }}
{{ include "template-library.identityLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service | quote }}
{{- end -}}

{{/* Fail with a clear message when a value uses the wrong collection type. */}}
{{- define "template-library.assertKind" -}}
{{- $value := .value -}}
{{- $kind := .kind -}}
{{- if and (not (kindIs "invalid" $value)) (not (kindIs $kind $value)) -}}
{{- fail (printf "%s must be a %s (got %s)" .path $kind (kindOf $value)) -}}
{{- end -}}
{{- end -}}

{{/* Validate an optional dictionary member only when the member is present. */}}
{{- define "template-library.assertOptionalKind" -}}
{{- if hasKey .parent .key -}}
{{- include "template-library.assertKind" (dict "value" (get .parent .key) "kind" .kind "path" .path) -}}
{{- end -}}
{{- end -}}

{{/* Validate an optional boolean dictionary member. */}}
{{- define "template-library.assertOptionalBool" -}}
{{- if hasKey .parent .key -}}
{{- if not (kindIs "bool" (get .parent .key)) -}}
{{- fail (printf "%s must be a boolean (got %s)" .path (kindOf (get .parent .key))) -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/* Require a base-10 integer within an inclusive range and return it. */}}
{{- define "template-library.integerInRange" -}}
{{- $text := toString .value -}}
{{- if not (regexMatch "^-?[0-9]+$" $text) -}}
{{- fail (printf "%s must be an integer (got %q)" .path $text) -}}
{{- end -}}
{{- $value := int64 $text -}}
{{- if or (lt $value (int64 .min)) (gt $value (int64 .max)) -}}
{{- fail (printf "%s must be between %v and %v (got %v)" .path .min .max $value) -}}
{{- end -}}
{{- $value -}}
{{- end -}}

{{/* Validate a Service port name or named targetPort. */}}
{{- define "template-library.validatePortName" -}}
{{- $value := toString .value -}}
{{- if or (gt (len $value) 15) (not (regexMatch "^[a-z0-9]([-a-z0-9]*[a-z0-9])?$" $value)) (not (regexMatch "[a-z]" $value)) -}}
{{- fail (printf "%s must be a lowercase IANA service name of at most 15 characters (got %q)" .path $value) -}}
{{- end -}}
{{- $value -}}
{{- end -}}

{{/* Validate a PDB IntOrString as a non-negative integer or 0%-100% percentage. */}}
{{- define "template-library.pdbAvailability" -}}
{{- $path := .path -}}
{{- if kindIs "string" .value -}}
  {{- $text := toString .value -}}
  {{- if not (regexMatch "^([0-9]|[1-9][0-9]|100)%$" $text) -}}
    {{- fail (printf "%s must be a non-negative integer or a percentage from 0%% to 100%% (got %q)" $path $text) -}}
  {{- end -}}
  {{- $text -}}
{{- else -}}
  {{- include "template-library.integerInRange" (dict "value" .value "min" 0 "max" 2147483647 "path" $path) -}}
{{- end -}}
{{- end -}}

{{/* Resolve the explicitly selected controller managed by this chart. */}}
{{- define "template-library.workloadKind" -}}
{{- $workload := .Values.workload | default dict -}}
{{- $kind := required "workload.kind is required" (get $workload "kind") -}}
{{- if not (has $kind (list "Deployment" "StatefulSet" "DaemonSet")) -}}
{{- fail "workload.kind must be Deployment, StatefulSet, or DaemonSet" -}}
{{- end -}}
{{- $kind -}}
{{- end -}}

{{- define "template-library.workloadEnabled" -}}
{{- $workload := .Values.workload | default dict -}}
{{- if and (hasKey $workload "enabled") (not (get $workload "enabled")) -}}false{{- else -}}true{{- end -}}
{{- end -}}

{{- define "template-library.workloadName" -}}
{{- $workload := .Values.workload | default dict -}}
{{- default (include "template-library.fullname" .) (get $workload "name") -}}
{{- end -}}

{{/* Build an image reference, preferring an immutable digest when supplied. */}}
{{- define "template-library.imageReference" -}}
{{- $image := .image | default dict -}}
{{- $path := .path | default "image" -}}
{{- $repository := toString (required (printf "%s.repository is required" $path) (get $image "repository")) -}}
{{- $name := toString (required (printf "%s.name is required" $path) (get $image "name")) -}}
{{- $digest := toString (get $image "digest") -}}
{{- if $digest -}}
  {{- if not (regexMatch "^sha256:[a-fA-F0-9]{64}$" $digest) -}}
    {{- fail (printf "%s.digest must be a sha256 digest" $path) -}}
  {{- end -}}
  {{- printf "%s/%s@%s" $repository $name $digest -}}
{{- else -}}
  {{- $tag := toString (required (printf "%s.tag or Chart.appVersion is required when digest is not set" $path) (default .appVersion (get $image "tag"))) -}}
  {{- printf "%s/%s:%s" $repository $name $tag -}}
{{- end -}}
{{- end -}}

{{/* Convert arbitrary annotation values to strings. */}}
{{- define "template-library.stringMap" -}}
{{- $input := . | default dict -}}
{{- $out := dict -}}
{{- range $key, $value := $input -}}
  {{- if kindIs "invalid" $value -}}
    {{- $_ := set $out $key "" -}}
  {{- else -}}
    {{- $_ := set $out $key (toString $value) -}}
  {{- end -}}
{{- end -}}
{{- toYaml $out -}}
{{- end -}}

{{/* Merge custom pod labels while protecting labels used by a controller selector. */}}
{{- define "template-library.mergedPodLabelsWithSelectors" -}}
{{- $root := .root -}}
{{- $custom := .custom | default dict -}}
{{- $selectors := .selectors | default dict -}}
{{- $base := include "template-library.labels" $root | fromYaml -}}
{{- range $key, $value := $selectors -}}
  {{- $_ := set $base $key (toString $value) -}}
{{- end -}}
{{- range $key, $value := $custom -}}
  {{- if and (hasKey $selectors $key) (ne (toString (index $selectors $key)) (toString $value)) -}}
    {{- fail (printf "pod label %q cannot override selector label %q" $key (index $selectors $key)) -}}
  {{- end -}}
  {{- $_ := set $base $key (toString $value) -}}
{{- end -}}
{{- toYaml $base -}}
{{- end -}}

{{- define "template-library.mergedPodLabels" -}}
{{- $selectors := include "template-library.selectorLabels" .root | fromYaml -}}
{{- include "template-library.mergedPodLabelsWithSelectors" (dict "root" .root "custom" (.custom | default dict) "selectors" $selectors) -}}
{{- end -}}

{{- define "template-library.mergedCronJobPodLabels" -}}
{{- $selectors := include "template-library.cronJobSelectorLabels" (dict "root" .root "name" .name) | fromYaml -}}
{{- include "template-library.mergedPodLabelsWithSelectors" (dict "root" .root "custom" (.custom | default dict) "selectors" $selectors) -}}
{{- end -}}

{{- define "template-library.mergedLabels" -}}
{{- $root := .root -}}
{{- $custom := .custom | default dict -}}
{{- $base := include "template-library.labels" $root | fromYaml -}}
{{- range $key, $value := $custom -}}
  {{- $_ := set $base $key (toString $value) -}}
{{- end -}}
{{- toYaml $base -}}
{{- end -}}

{{- define "template-library.serviceAccountName" -}}
{{- $serviceAccount := .Values.serviceAccount | default dict -}}
{{- if (get $serviceAccount "create") -}}
{{- $name := default (include "template-library.fullname" .) (get $serviceAccount "name") | trunc 63 | trimSuffix "-" -}}
{{- include "template-library.validateDNSName" (dict "value" $name "path" "serviceAccount.name") -}}
{{- else -}}
{{- $name := default "default" (get $serviceAccount "name") -}}
{{- include "template-library.validateDNSName" (dict "value" $name "path" "serviceAccount.name") -}}
{{- end -}}
{{- end -}}

{{/*
Merge override into local, but only for keys already present in local.
Both arguments must be dictionaries. Output is YAML.
*/}}
{{- define "template-library.mergeExistingKeys" -}}
{{- $local := .local | default dict -}}
{{- $override := .override | default dict -}}
{{- $out := dict -}}
{{- range $key, $localValue := $local -}}
  {{- if hasKey $override $key -}}
    {{- $overrideValue := index $override $key -}}
    {{- if and (kindIs "map" $localValue) (kindIs "map" $overrideValue) -}}
      {{- $_ := set $out $key (include "template-library.mergeExistingKeys" (dict "local" $localValue "override" $overrideValue) | fromYaml) -}}
    {{- else -}}
      {{- $_ := set $out $key $overrideValue -}}
    {{- end -}}
  {{- else -}}
    {{- $_ := set $out $key $localValue -}}
  {{- end -}}
{{- end -}}
{{- toYaml $out -}}
{{- end -}}

{{/* Resolve an effective host for one Ingress host rule. */}}
{{- define "template-library.ingressHost" -}}
{{- $root := .root -}}
{{- $entry := .entry | default dict -}}
{{- $host := .host | default dict -}}
{{- $globalDomain := .globalDomain | default "" -}}
{{- if (get $entry "hostOverride") -}}
{{- tpl (toString (get $entry "hostOverride")) $root -}}
{{- else if (get $host "useGlobalDomain") -}}
{{- required "ingress host sets useGlobalDomain=true, but global.portalSubDomain/global.baseDomain do not define a global domain" $globalDomain -}}
{{- else -}}
{{- tpl (required "ingress host.host is required when no hostOverride/global domain is used" (get $host "host")) $root -}}
{{- end -}}
{{- end -}}
