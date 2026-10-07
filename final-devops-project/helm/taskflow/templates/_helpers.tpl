{{/* Chart name. */}}
{{- define "taskflow.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Fully qualified app name. With release name "taskflow" this is just "taskflow",
so the objects get the same names as the plain manifests in kubernetes/.
*/}}
{{- define "taskflow.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{- define "taskflow.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/* Common labels. */}}
{{- define "taskflow.labels" -}}
helm.sh/chart: {{ include "taskflow.chart" . }}
app.kubernetes.io/name: {{ include "taskflow.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/part-of: taskflow
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/* Selector labels for one component: include "taskflow.selectorLabels" (dict "ctx" . "component" "backend") */}}
{{- define "taskflow.selectorLabels" -}}
app.kubernetes.io/name: {{ include "taskflow.name" .ctx }}
app.kubernetes.io/instance: {{ .ctx.Release.Name }}
app.kubernetes.io/component: {{ .component }}
{{- end }}

{{/* Labels for one component (common + component). */}}
{{- define "taskflow.componentLabels" -}}
{{ include "taskflow.labels" .ctx }}
app.kubernetes.io/component: {{ .component }}
{{- end }}

{{- define "taskflow.backend.fullname" -}}
{{- printf "%s-backend" (include "taskflow.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "taskflow.frontend.fullname" -}}
{{- printf "%s-frontend" (include "taskflow.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "taskflow.postgres.fullname" -}}
{{- printf "%s-postgres" (include "taskflow.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/* Name of the Secret holding DB_USER / DB_PASSWORD. */}}
{{- define "taskflow.secretName" -}}
{{- if .Values.database.existingSecret }}
{{- .Values.database.existingSecret }}
{{- else }}
{{- printf "%s-db" (include "taskflow.fullname" .) }}
{{- end }}
{{- end }}

{{/* Database host: the bundled PostgreSQL Service or an external endpoint. */}}
{{- define "taskflow.dbHost" -}}
{{- if .Values.postgres.enabled }}
{{- include "taskflow.postgres.fullname" . }}
{{- else }}
{{- required "database.externalHost is required when postgres.enabled=false" .Values.database.externalHost }}
{{- end }}
{{- end }}

{{- define "taskflow.backend.image" -}}
{{- printf "%s:%s" .Values.backend.image.repository (.Values.backend.image.tag | default .Chart.AppVersion | toString) }}
{{- end }}

{{- define "taskflow.frontend.image" -}}
{{- printf "%s:%s" .Values.frontend.image.repository (.Values.frontend.image.tag | default .Chart.AppVersion | toString) }}
{{- end }}

{{/* DB credentials as env vars (shared by the migrate initContainer and the backend). */}}
{{- define "taskflow.dbCredentialsEnv" -}}
- name: DB_USER
  valueFrom:
    secretKeyRef:
      name: {{ include "taskflow.secretName" . }}
      key: DB_USER
- name: DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "taskflow.secretName" . }}
      key: DB_PASSWORD
{{- end }}
