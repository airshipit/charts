
{{- define "helpers.pod.container.image" -}}
    {{- $Global := index . "Global" -}}
    {{- $Application := index . "Application" -}}
    {{- with index $.Global.Values.images.applications $Application -}}
        {{- printf "%s/%s:%s" .repo .name ( .tag | toString ) | quote -}}
    {{- end -}}
{{- end -}}

{{- define "helpers.pod.node_selector" -}}
    {{- $Global := index . "Global" -}}
    {{- $Application := index . "Application" -}}
    {{- with index $.Global.Values.node_labels $Application -}}
        {{ if kindIs "slice" . }}
            {{ range $k, $item := . }}
{{ $item.key }}: {{ $item.value | quote }}
            {{ end }}
        {{ else }}
{{ .key }}: {{ .value | quote }}
        {{ end }}
    {{- end }}
{{- end }}