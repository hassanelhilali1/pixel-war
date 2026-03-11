{{/*
Expand the name of the chart.
*/}}
{{- define "pixel-war.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Full name of the release.
*/}}
{{- define "pixel-war.fullname" -}}
{{- printf "%s" .Release.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Chart label.
*/}}
{{- define "pixel-war.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels.
*/}}
{{- define "pixel-war.labels" -}}
helm.sh/chart:                {{ include "pixel-war.chart" . }}
app.kubernetes.io/name:       {{ include "pixel-war.name" . }}
app.kubernetes.io/instance:   {{ .Release.Name }}
app.kubernetes.io/version:    {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels.
*/}}
{{- define "pixel-war.selectorLabels" -}}
app.kubernetes.io/name:     {{ include "pixel-war.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
