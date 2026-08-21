{{- define "template-library.networkPolicy" -}}
{{- $rootConfig := .Values.networkPolicies | default dict -}}
{{- if (get $rootConfig "enabled") }}
{{- $_ := include "template-library.assertKind" (dict "value" (get $rootConfig "policies") "kind" "slice" "path" "networkPolicies.policies") }}
{{- range $index, $policy := (get $rootConfig "policies" | default list) }}
{{- $name := required (printf "networkPolicies.policies[%d].name is required" $index) (get $policy "name") -}}
{{- $hasIngress := hasKey $policy "ingress" -}}
{{- $hasEgress := hasKey $policy "egress" -}}
{{- $_ := include "template-library.assertOptionalKind" (dict "parent" $policy "key" "ingress" "kind" "slice" "path" (printf "networkPolicies.policies[%d].ingress" $index)) -}}
{{- $_ := include "template-library.assertOptionalKind" (dict "parent" $policy "key" "egress" "kind" "slice" "path" (printf "networkPolicies.policies[%d].egress" $index)) -}}
{{- $_ := include "template-library.assertOptionalKind" (dict "parent" $policy "key" "policyTypes" "kind" "slice" "path" (printf "networkPolicies.policies[%d].policyTypes" $index)) -}}
{{- $policyTypes := get $policy "policyTypes" | default list -}}
{{- if not $policyTypes -}}
  {{- $derivedTypes := list -}}
  {{- if $hasIngress }}{{- $derivedTypes = append $derivedTypes "Ingress" }}{{- end -}}
  {{- if $hasEgress }}{{- $derivedTypes = append $derivedTypes "Egress" }}{{- end -}}
  {{- $policyTypes = $derivedTypes -}}
{{- end -}}
{{- range $policyType := $policyTypes -}}
  {{- if not (or (eq $policyType "Ingress") (eq $policyType "Egress")) -}}{{- fail (printf "networkPolicies.policies[%d].policyTypes may contain only Ingress or Egress" $index) -}}{{- end -}}
{{- end -}}
{{- if and $hasIngress (not (has "Ingress" $policyTypes)) -}}{{- fail (printf "networkPolicies.policies[%d].policyTypes must include Ingress when ingress is defined" $index) -}}{{- end -}}
{{- if and $hasEgress (not (has "Egress" $policyTypes)) -}}{{- fail (printf "networkPolicies.policies[%d].policyTypes must include Egress when egress is defined" $index) -}}{{- end -}}
{{- if and (eq (include "template-library.workloadEnabled" $) "false") (not (hasKey $policy "podSelector")) -}}
{{- fail (printf "networkPolicies.policies[%d] requires podSelector when the workload is disabled" $index) -}}
{{- end -}}
{{- if not $policyTypes -}}
{{- fail (printf "networkPolicies.policies[%d] must define policyTypes and/or ingress/egress" $index) -}}
{{- end }}
{{- printf "\n---\n" }}
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: {{ include "template-library.resourceName" (dict "root" $ "suffix" $name "maxLength" 63) }}
  labels:
    {{- include "template-library.mergedLabels" (dict "root" $ "custom" (get $policy "labels" | default dict)) | nindent 4 }}
  {{- with (get $policy "annotations") }}
  annotations:
    {{- include "template-library.stringMap" . | nindent 4 }}
  {{- end }}
spec:
  {{- if hasKey $policy "podSelector" }}
  {{- $podSelector := get $policy "podSelector" }}
  {{- if $podSelector }}
  podSelector:
    {{- toYaml $podSelector | nindent 4 }}
  {{- else }}
  podSelector: {}
  {{- end }}
  {{- else }}
  podSelector:
    matchLabels:
      {{- include "template-library.selectorLabels" $ | nindent 6 }}
  {{- end }}
  policyTypes:
    {{- toYaml $policyTypes | nindent 4 }}
  {{- if $hasIngress }}
  {{- $ingressRules := get $policy "ingress" }}
  {{- if $ingressRules }}
  ingress:
    {{- toYaml $ingressRules | nindent 4 }}
  {{- else }}
  ingress: []
  {{- end }}
  {{- end }}
  {{- if $hasEgress }}
  {{- $egressRules := get $policy "egress" }}
  {{- if $egressRules }}
  egress:
    {{- toYaml $egressRules | nindent 4 }}
  {{- else }}
  egress: []
  {{- end }}
  {{- end }}
{{- end }}
{{- end }}
{{- end -}}
