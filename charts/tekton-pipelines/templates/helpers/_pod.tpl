{{- define "helpers.pod.container.image" -}}
    {{- $Global := index . "Global" -}}
    {{- $Component := index . "Component" -}}
    {{- with index $.Global.Values.images.applications $Component -}}
        {{- printf "%s/%s:%s" .repo .name ( .tag | toString ) -}}
    {{- end -}}
{{- end -}}

{{- define "helpers.pod.node_selector" -}}
    {{- $Global := index . "Global" -}}
    {{- $Component := index . "Component" -}}
    {{- with index $.Global.Values.node_labels $Component -}}
        {{ if kindIs "slice" . }}
            {{ range $k, $item := . }}
{{ $item.key }}: {{ $item.value | quote }}
            {{ end }}
        {{ else }}
{{ .key }}: {{ .value | quote }}
        {{ end }}
    {{- end }}
{{- end }}
