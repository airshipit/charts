{{- define "helpers.config.renderer" -}}
    {{- $Global := index . "Global" -}}
    {{- $key := index . "key" -}}

    {{- $local := dict -}}
    {{- $_ := set $local "templateRaw" ( index $Global.Values.config $key )  -}}

    {{- with $Global -}}
        {{- if not (kindIs "string" $local.templateRaw)  -}}
            {{- $_ := set $local "template" ( toString ( toPrettyJson ( $local.templateRaw ) ) ) -}}
            {{- $_ := set $local "render" ( toString ( toYaml ( fromJson ( tpl $local.template . ) ) ) ) -}}
        {{- else -}}
            {{- $_ := set $local "template" $local.templateRaw -}}
            {{- $_ := set $local "render" ( tpl $local.template . ) -}}
        {{- end }}
{{ printf "%s: |" $key }}
{{ $local.render | indent 2 }}
    {{- end -}}
{{- end -}}


{{- define "helpers.config.hash" -}}
    {{- $name := index . "TemplateName" -}}
    {{- $context := index . "Global" -}}
    {{- $last := base $context.Template.Name }}
    {{- $wtf := $context.Template.Name | replace $last $name -}}
    {{- include $wtf $context | sha256sum | quote -}}
{{- end -}}