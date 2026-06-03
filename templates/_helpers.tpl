{{/*
Expand the name of the chart.
*/}}
{{- define "node-filesystem-updater.name" -}}
{{- .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "node-filesystem-updater.fullname" -}}
{{- if contains .Chart.Name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{/*
Per-updater resource name: "<fullname>-<updater key>", truncated to a valid name.
Call with a dict: (dict "root" $ "name" $name)
*/}}
{{- define "node-filesystem-updater.updaterName" -}}
{{- printf "%s-%s" (include "node-filesystem-updater.fullname" .root) .name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "node-filesystem-updater.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "node-filesystem-updater.labels" -}}
helm.sh/chart: {{ include "node-filesystem-updater.chart" . }}
{{ include "node-filesystem-updater.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "node-filesystem-updater.selectorLabels" -}}
app.kubernetes.io/name: {{ include "node-filesystem-updater.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
