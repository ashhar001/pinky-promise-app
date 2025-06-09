#!/bin/bash

# Production Monitoring Setup for Pinky Promise App
# This script sets up comprehensive monitoring, logging, and alerting

set -e

PROJECT_ID="pinky-promise-app"
REGION="us-central1"
NOTIFICATION_EMAIL="devops@pinky-promise.example.com"  # Replace with your email

# Set default region for Cloud Run
gcloud config set run/region $REGION

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[INFO]${NC} $1"; }
info() { echo -e "${BLUE}[MONITORING]${NC} $1"; }

echo -e "${GREEN}"
echo "============================================================"
echo "      Production Monitoring & Alerting Setup"
echo "============================================================"
echo -e "${NC}"

# 1. Enable monitoring APIs
info "Enabling monitoring and alerting APIs..."
gcloud services enable monitoring.googleapis.com \
    logging.googleapis.com \
    alerting.googleapis.com \
    cloudtrace.googleapis.com \
    cloudprofiler.googleapis.com

# 2. Create notification channels
info "Setting up notification channels..."

# Email notification channel
EMAIL_CHANNEL=$(gcloud alpha monitoring channels create \
    --display-name="DevOps Team Email" \
    --type=email \
    --channel-labels=email_address=$NOTIFICATION_EMAIL \
    --format="value(name)" 2>/dev/null || echo "")

if [ -z "$EMAIL_CHANNEL" ]; then
    EMAIL_CHANNEL=$(gcloud alpha monitoring channels list \
        --filter="displayName='DevOps Team Email'" \
        --format="value(name)")
fi

log "Email notification channel: $EMAIL_CHANNEL"

# 3. Create alerting policies
info "Creating alerting policies..."

# Backend Error Rate Alert
gcloud alpha monitoring policies create --policy-from-file=- <<EOF
displayName: "Backend High Error Rate"
combiner: OR
conditions:
- displayName: "Backend 5xx Error Rate"
  conditionThreshold:
    filter: 'resource.type="cloud_run_revision" AND resource.labels.service_name="pinky-promise-backend" AND metric.type="run.googleapis.com/request_count" AND metric.labels.response_code_class="5xx"'
    comparison: COMPARISON_GREATER_THAN
    thresholdValue: 5
    duration: 300s
    aggregations:
    - alignmentPeriod: 60s
      perSeriesAligner: ALIGN_RATE
      crossSeriesReducer: REDUCE_SUM
notificationChannels:
- $EMAIL_CHANNEL
EOF

# High Latency Alert
gcloud alpha monitoring policies create --policy-from-file=- <<EOF
displayName: "Backend High Latency"
combiner: OR
conditions:
- displayName: "Backend Response Time > 2s"
  conditionThreshold:
    filter: 'resource.type="cloud_run_revision" AND resource.labels.service_name="pinky-promise-backend" AND metric.type="run.googleapis.com/request_latencies"'
    comparison: COMPARISON_GREATER_THAN
    thresholdValue: 2000
    duration: 300s
    aggregations:
    - alignmentPeriod: 60s
      perSeriesAligner: ALIGN_PERCENTILE_95
      crossSeriesReducer: REDUCE_MEAN
notificationChannels:
- $EMAIL_CHANNEL
EOF

# Database Connection Alert
gcloud alpha monitoring policies create --policy-from-file=- <<EOF
displayName: "Database Connection Issues"
combiner: OR
conditions:
- displayName: "Database CPU > 80%"
  conditionThreshold:
    filter: 'resource.type="cloudsql_database" AND metric.type="cloudsql.googleapis.com/database/cpu/utilization"'
    comparison: COMPARISON_GREATER_THAN
    thresholdValue: 0.8
    duration: 300s
    aggregations:
    - alignmentPeriod: 60s
      perSeriesAligner: ALIGN_MEAN
      crossSeriesReducer: REDUCE_MEAN
notificationChannels:
- $EMAIL_CHANNEL
EOF

# Memory Usage Alert
gcloud alpha monitoring policies create --policy-from-file=- <<EOF
displayName: "High Memory Usage"
combiner: OR
conditions:
- displayName: "Cloud Run Memory > 80%"
  conditionThreshold:
    filter: 'resource.type="cloud_run_revision" AND metric.type="run.googleapis.com/container/memory/utilizations"'
    comparison: COMPARISON_GREATER_THAN
    thresholdValue: 0.8
    duration: 300s
    aggregations:
    - alignmentPeriod: 60s
      perSeriesAligner: ALIGN_MEAN
      crossSeriesReducer: REDUCE_MEAN
notificationChannels:
- $EMAIL_CHANNEL
EOF

# 4. Create custom dashboards
info "Creating monitoring dashboards..."

# Main Application Dashboard
gcloud monitoring dashboards create --config-from-file=- <<EOF
displayName: "Pinky Promise App - Production Dashboard"
mosaicLayout:
  tiles:
  - width: 6
    height: 4
    widget:
      title: "Request Rate"
      xyChart:
        dataSets:
        - timeSeriesQuery:
            timeSeriesFilter:
              filter: 'resource.type="cloud_run_revision" AND resource.labels.service_name="pinky-promise-backend" AND metric.type="run.googleapis.com/request_count"'
              aggregation:
                alignmentPeriod: 60s
                perSeriesAligner: ALIGN_RATE
                crossSeriesReducer: REDUCE_SUM
        yAxis:
          label: "Requests/sec"
  - width: 6
    height: 4
    xPos: 6
    widget:
      title: "Response Time (95th percentile)"
      xyChart:
        dataSets:
        - timeSeriesQuery:
            timeSeriesFilter:
              filter: 'resource.type="cloud_run_revision" AND resource.labels.service_name="pinky-promise-backend" AND metric.type="run.googleapis.com/request_latencies"'
              aggregation:
                alignmentPeriod: 60s
                perSeriesAligner: ALIGN_PERCENTILE_95
                crossSeriesReducer: REDUCE_MEAN
        yAxis:
          label: "Latency (ms)"
  - width: 6
    height: 4
    yPos: 4
    widget:
      title: "Error Rate"
      xyChart:
        dataSets:
        - timeSeriesQuery:
            timeSeriesFilter:
              filter: 'resource.type="cloud_run_revision" AND resource.labels.service_name="pinky-promise-backend" AND metric.type="run.googleapis.com/request_count" AND metric.labels.response_code_class!="2xx"'
              aggregation:
                alignmentPeriod: 60s
                perSeriesAligner: ALIGN_RATE
                crossSeriesReducer: REDUCE_SUM
        yAxis:
          label: "Errors/sec"
  - width: 6
    height: 4
    xPos: 6
    yPos: 4
    widget:
      title: "Database Connections"
      xyChart:
        dataSets:
        - timeSeriesQuery:
            timeSeriesFilter:
              filter: 'resource.type="cloudsql_database" AND metric.type="cloudsql.googleapis.com/database/postgresql/num_backends"'
              aggregation:
                alignmentPeriod: 60s
                perSeriesAligner: ALIGN_MEAN
                crossSeriesReducer: REDUCE_MEAN
        yAxis:
          label: "Connections"
EOF

# 5. Set up log-based metrics
info "Creating log-based metrics..."

# Application errors metric
gcloud logging metrics create application_errors \
    --description="Count of application errors" \
    --log-filter='resource.type="cloud_run_revision" AND resource.labels.service_name="pinky-promise-backend" AND severity>=ERROR'

# Successful user registrations
gcloud logging metrics create user_registrations \
    --description="Count of successful user registrations" \
    --log-filter='resource.type="cloud_run_revision" AND resource.labels.service_name="pinky-promise-backend" AND "user registered successfully"'

# Failed login attempts
gcloud logging metrics create failed_logins \
    --description="Count of failed login attempts" \
    --log-filter='resource.type="cloud_run_revision" AND resource.labels.service_name="pinky-promise-backend" AND "login failed"'

log "Log-based metrics created"

# 6. Set up SLO (Service Level Objectives)
info "Creating SLO configuration..."

cat > slo-config.yaml <<EOF
# Service Level Objectives for Pinky Promise App

services:
- name: "pinky-promise-backend"
  objectives:
  - availability: 99.9%
    latency_p95: 1000ms
    error_rate: 0.1%
    
- name: "pinky-promise-frontend"
  objectives:
  - availability: 99.95%
    latency_p95: 500ms
    error_rate: 0.05%

monitoring:
  alert_thresholds:
    availability: 99.5%
    latency_degradation: 20%
    error_rate_spike: 200%
EOF

log "SLO configuration created in slo-config.yaml"

# 7. Performance optimization monitoring
info "Setting up performance monitoring..."

# Cloud Trace for request tracing
gcloud services enable cloudtrace.googleapis.com

# Cloud Profiler for performance profiling
gcloud services enable cloudprofiler.googleapis.com

log "Performance monitoring tools enabled"

echo -e "${GREEN}"
echo "============================================================"
echo "        Monitoring Setup Completed Successfully!"
echo "============================================================"
echo -e "${NC}"
echo "Monitoring Features Configured:"
echo "✅ Error rate alerts (>5 errors in 5 minutes)"
echo "✅ High latency alerts (>2s response time)"
echo "✅ Database performance alerts (>80% CPU)"
echo "✅ Memory usage alerts (>80% utilization)"
echo "✅ Custom dashboards for key metrics"
echo "✅ Log-based metrics for business events"
echo "✅ Performance profiling tools"
echo "✅ Request tracing capabilities"
echo ""
echo "📊 View dashboards: https://console.cloud.google.com/monitoring/dashboards"
echo "🚨 View alerts: https://console.cloud.google.com/monitoring/alerting"
echo "📈 View metrics: https://console.cloud.google.com/monitoring/metrics-explorer"
echo "📋 View logs: https://console.cloud.google.com/logs"

