{{/*
Expand the name of the chart.
*/}}
{{- define "helpers.labels.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "helpers.labels.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "helpers.labels.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Labels to use on {deploy|sts}.spec.selector.matchLabels and svc.spec.selector
*/}}
{{- define "helpers.labels.matchLabels" -}}
{{- $Global := index . "Global" -}}
{{- $Component := index . "Component" -}}
app.kubernetes.io/name: {{ include "helpers.labels.name" $Global }}
app.kubernetes.io/instance: {{ $Global.Values.release_group | default $Global.Release.Name }}
{{- if $Component }}
app.kubernetes.io/component: {{ $Component }}
{{- end }}
{{- end -}}

{{/*
Common labels
*/}}
{{- define "helpers.labels.labels" -}}
{{- $Global := index . "Global" -}}
{{- $PartOf := index . "PartOf" -}}
{{- $Component := index . "Component" -}}
{{- $Version := index . "Version" -}}
{{ include "helpers.labels.matchLabels" (dict "Global" $Global )}}
app.kubernetes.io/managed-by: {{ $Global.Release.Service }}
{{- if $PartOf }}
app.kubernetes.io/part-of: {{ $PartOf }}
{{- end }}
{{- if $Component }}
app.kubernetes.io/component: {{ $Component }}
{{- end }}
{{- if $Version }}
app.kubernetes.io/version: {{ $Version }}
{{- end }}
helm.sh/chart: {{ include "helpers.labels.chart" $Global }}
{{- end -}}
