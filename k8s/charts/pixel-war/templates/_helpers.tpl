{{/*
nom du chart
*/}}
{{- define "pixel-war.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
nom complet
*/}}
{{- define "pixel-war.fullname" -}}
{{- printf "%s" .Release.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
label du chart
*/}}
{{- define "pixel-war.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
labels communs
*/}}
{{- define "pixel-war.labels" -}}
helm.sh/chart:                {{ include "pixel-war.chart" . }}
app.kubernetes.io/name:       {{ include "pixel-war.name" . }}
app.kubernetes.io/instance:   {{ .Release.Name }}
app.kubernetes.io/version:    {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
labels pour les selectors
*/}}
{{- define "pixel-war.selectorLabels" -}}
app.kubernetes.io/name:     {{ include "pixel-war.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
