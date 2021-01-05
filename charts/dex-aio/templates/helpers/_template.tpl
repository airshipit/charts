{{- define "helpers.template.overlay" -}}
  {{- $local := dict -}}
  {{/*
  By default we merge lists with a 'name' key's values
  */}}
  {{- $_ := set $local "merge_same_named" true -}}
  {{- if kindIs "map" $ -}}
    {{- if hasKey $ "merge_same_named" -}}
      {{- $_ := set $local "merge_same_named" $.merge_same_named -}}
    {{- end -}}
  {{- end -}}
  {{- $_ := set $local "input" ( fromYaml ( toString ( include $.template_definition $.Global ) ) )  -}}
  {{- $target := dict -}}
  {{- $overlay_keys := regexSplit "-+" ( trimSuffix ".yaml" ( lower ( base $.Global.Template.Name ) ) ) 2 }}
  {{- $_ := set $local "overlay" dict -}}
  {{- if hasKey $.Global.Values.over_rides ( index $overlay_keys 0 ) -}}
    {{- if hasKey ( index $.Global.Values.over_rides ( index $overlay_keys 0 ) ) ( index $overlay_keys 1 ) -}}
      {{- $_ := set $local "overlay" ( index $.Global.Values.over_rides ( index $overlay_keys 0 ) ( index $overlay_keys 1 ) )  -}}
    {{- end }}
  {{- end }}
  {{- range $item := tuple $local.input $local.overlay -}}
    {{- $call := dict "target" $target "source" . "merge_same_named" $local.merge_same_named -}}
    {{- $_ := include "helpers._merge" $call -}}
    {{- $_ := set $local "result" $call.result -}}
  {{- end -}}
  {{- if kindIs "map" $ -}}
    {{- $_ := set $ "result" $local.result -}}
  {{- end -}}
  {{ $target | toYaml }}
{{- end -}}

{{- define "helpers._merge" -}}
  {{- $local := dict -}}
  {{- $_ := set $ "result" $.source -}}
  {{/*
  TODO: Should we `fail` when trying to merge a collection (map or slice) with
  either a different kind of collection or a scalar?
  */}}
  {{- if and (kindIs "map" $.target) (kindIs "map" $.source) -}}
    {{- range $key, $sourceValue := $.source -}}
      {{- if not (hasKey $.target $key) -}}
        {{- $_ := set $local "newTargetValue" $sourceValue -}}
        {{- if kindIs "map" $sourceValue -}}
          {{- $copy := dict -}}
          {{- $call := dict "target" $copy "source" $sourceValue -}}
          {{- $_ := include "helpers._merge.shallow" $call -}}
          {{- $_ := set $local "newTargetValue" $copy -}}
        {{- end -}}
      {{- else -}}
        {{- $targetValue := index $.target $key -}}
        {{- $call := dict "target" $targetValue "source" $sourceValue "merge_same_named" $.merge_same_named -}}
        {{- $_ := include "helpers._merge" $call -}}
        {{- $_ := set $local "newTargetValue" $call.result -}}
      {{- end -}}
      {{- $_ := set $.target $key $local.newTargetValue -}}
    {{- end -}}
    {{- $_ := set $ "result" $.target -}}
  {{- else if and (kindIs "slice" $.target) (kindIs "slice" $.source) -}}
    {{- $call := dict "target" $.target "source" $.source -}}
    {{- $_ := include "helpers._merge.append_slice" $call -}}
    {{- if $.merge_same_named -}}
      {{- $_ := set $local "result" list -}}
      {{- $_ := set $local "named_items" dict -}}
      {{- range $item := $call.result -}}
      {{- $_ := set $local "has_name_key" false -}}
        {{- if kindIs "map" $item -}}
          {{- if hasKey $item "name" -}}
            {{- $_ := set $local "has_name_key" true -}}
          {{- end -}}
        {{- end -}}
        {{- if $local.has_name_key -}}
          {{- if hasKey $local.named_items $item.name -}}
            {{- $named_item := index $local.named_items $item.name -}}
            {{- $call := dict "target" $named_item "source" $item "merge_same_named" $.merge_same_named -}}
            {{- $_ := include "helpers._merge" $call -}}
          {{- else -}}
            {{- $copy := dict -}}
            {{- $copy_call := dict "target" $copy "source" $item -}}
            {{- $_ := include "helpers._merge.shallow" $copy_call -}}
            {{- $_ := set $local.named_items $item.name $copy -}}
            {{- $_ := set $local "result" (append $local.result $copy) -}}
          {{- end -}}
        {{- else -}}
          {{- $_ := set $local "result" (append $local.result $item) -}}
        {{- end -}}
      {{- end -}}
    {{- else -}}
      {{- $_ := set $local "result" $call.result -}}
    {{- end -}}
    {{- $_ := set $ "result" (uniq $local.result) -}}
  {{- end -}}
{{- end -}}

{{- define "helpers._merge.shallow" -}}
  {{- range $key, $value := $.source -}}
    {{- $_ := set $.target $key $value -}}
  {{- end -}}
{{- end -}}

{{- define "helpers._merge.append_slice" -}}
  {{- $local := dict -}}
  {{- $_ := set $local "result" $.target -}}
  {{- range $value := $.source -}}
    {{- $_ := set $local "result" (append $local.result $value) -}}
  {{- end -}}
  {{- $_ := set $ "result" $local.result -}}
{{- end -}}
