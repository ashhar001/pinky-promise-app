#!/bin/bash

# Production Setup Script for Pinky Promise App
# This script sets up production-ready infrastructure and security

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_ID="pinky-promise-app"
REGION="us-central1"
DOMAIN="pinky-promise.example.com"  # Replace with your actual domain

log() {
  echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
  echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
  echo -e "${RED}[ERROR]${NC} $1"
  exit 1
}

info() {
  echo -e "${BLUE}[SETUP]${NC} $1"
}

echo -e "${GREEN}"
echo "============================================================"
echo "       Pinky Promise App - Production Setup"
echo "============================================================"
echo -e "${NC}"

# 1. Set up production secrets
info "Setting up production secrets in Secret Manager..."

# Generate strong production secrets
JWT_SECRET=$(openssl rand -base64 32)
JWT_REFRESH_SECRET=$(openssl rand -base64 32)
DB_PASSWORD=$(openssl rand -base64 16 | tr -d "=+/" | cut -c1-16)

# Create or update secrets
echo -n "$JWT_SECRET" | gcloud secrets create jwt-secret-prod --data-file=- 2>/dev/null || \
echo -n "$JWT_SECRET" | gcloud secrets versions add jwt-secret-prod --data-file=-

echo -n "$JWT_REFRESH_SECRET" | gcloud secrets create jwt-refresh-secret-prod --data-file=- 2>/dev/null || \
echo -n "$JWT_REFRESH_SECRET" | gcloud secrets versions add jwt-refresh-secret-prod --data-file=-

echo -n "$DB_PASSWORD" | gcloud secrets create db-password-prod --data-file=- 2>/dev/null || \
echo -n "$DB_PASSWORD" | gcloud secrets versions add db-password-prod --data-file=-

log "Production secrets created successfully"

# 2. Set up production database
info "Setting up production Cloud SQL instance..."

gcloud sql instances create pinky-promise-db-prod \
    --database-version=POSTGRES_14 \
    --tier=db-custom-2-4096 \
    --region=$REGION \
    --storage-type=SSD \
    --storage-size=50GB \
    --backup-start-time=02:00 \
    --availability-type=regional \
    --enable-bin-log \
    --deletion-protection 2>/dev/null || log "Production database instance already exists"

# Create database and user
gcloud sql databases create pinky_promise_prod --instance=pinky-promise-db-prod 2>/dev/null || log "Production database already exists"

gcloud sql users create pinky_promise_prod_user \
    --instance=pinky-promise-db-prod \
    --password=$DB_PASSWORD 2>/dev/null || log "Production database user already exists"

log "Production database setup completed"

# 3. Set up production Cloud Run services with proper scaling and security
info "Setting up production Cloud Run services..."

# Backend service
gcloud run services replace - --region=$REGION <<EOF
apiVersion: serving.knative.dev/v1
kind: Service
metadata:
  name: pinky-promise-backend-prod
  annotations:
    run.googleapis.com/cloudsql-instances: $PROJECT_ID:$REGION:pinky-promise-db-prod
    run.googleapis.com/cpu-throttling: "false"
spec:
  template:
    metadata:
      annotations:
        run.googleapis.com/cloudsql-instances: $PROJECT_ID:$REGION:pinky-promise-db-prod
        run.googleapis.com/vpc-access-connector: projects/$PROJECT_ID/locations/$REGION/connectors/vpc-connector
        autoscaling.knative.dev/minScale: "2"
        autoscaling.knative.dev/maxScale: "100"
        run.googleapis.com/execution-environment: gen2
    spec:
      containerConcurrency: 100
      timeoutSeconds: 300
      containers:
      - image: gcr.io/$PROJECT_ID/pinky-promise-backend:prod-latest
        resources:
          limits:
            cpu: "2"
            memory: "2Gi"
        env:
        - name: NODE_ENV
          value: production
        - name: PORT
          value: "8080"
        - name: DATABASE_URL
          value: postgresql://pinky_promise_prod_user:$DB_PASSWORD@localhost:5432/pinky_promise_prod?host=/cloudsql/$PROJECT_ID:$REGION:pinky-promise-db-prod
        - name: JWT_SECRET
          valueFrom:
            secretKeyRef:
              name: jwt-secret-prod
              key: latest
        - name: JWT_REFRESH_SECRET
          valueFrom:
            secretKeyRef:
              name: jwt-refresh-secret-prod
              key: latest
EOF

log "Production Cloud Run services configured"

# 4. Set up monitoring and alerting
info "Setting up production monitoring..."

# Enable required APIs for monitoring
gcloud services enable monitoring.googleapis.com logging.googleapis.com alerting.googleapis.com

# Create uptime checks
gcloud monitoring uptime-check-configs create \
    --display-name="Production Backend Health Check" \
    --http-check-path="/health" \
    --http-check-port=443 \
    --http-check-request-method=GET \
    --selected-regions=us-central1-a,us-east1-a,europe-west1-a \
    --period=60s \
    --timeout=10s \
    --hostname="api.$DOMAIN" 2>/dev/null || log "Backend uptime check already exists"

gcloud monitoring uptime-check-configs create \
    --display-name="Production Frontend Health Check" \
    --http-check-path="/" \
    --http-check-port=443 \
    --http-check-request-method=GET \
    --selected-regions=us-central1-a,us-east1-a,europe-west1-a \
    --period=60s \
    --timeout=10s \
    --hostname="$DOMAIN" 2>/dev/null || log "Frontend uptime check already exists"

log "Production monitoring setup completed"

# 5. Set up security policies
info "Setting up security policies..."

# Enable security scanner for container images
gcloud services enable containeranalysis.googleapis.com

# Create IAM policies for least privilege access
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:service-$(gcloud projects describe $PROJECT_ID --format='value(projectNumber)')@gcp-sa-cloudrun.iam.gserviceaccount.com" \
    --role="roles/cloudsql.client"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:service-$(gcloud projects describe $PROJECT_ID --format='value(projectNumber)')@gcp-sa-cloudrun.iam.gserviceaccount.com" \
    --role="roles/secretmanager.secretAccessor"

log "Security policies configured"

# 6. Set up backup and disaster recovery
info "Setting up backup and disaster recovery..."

# Configure automated backups for Cloud SQL
gcloud sql instances patch pinky-promise-db-prod \
    --backup-start-time=02:00 \
    --retained-backups-count=30 \
    --retained-transaction-log-days=7

log "Backup and disaster recovery configured"

echo -e "${GREEN}"
echo "============================================================"
echo "         Production Setup Completed Successfully!"
echo "============================================================"
echo -e "${NC}"
echo "Next steps:"
echo "1. Set up your custom domain and SSL certificates"
echo "2. Configure CDN with Cloud Load Balancer"
echo "3. Set up CI/CD triggers for automated deployments"
echo "4. Review and test all monitoring alerts"
echo "5. Perform security audit and penetration testing"
echo ""
echo "Important: Store the following credentials securely:"
echo "Database Password: $DB_PASSWORD"
echo "JWT Secret: [Stored in Secret Manager]"
echo "JWT Refresh Secret: [Stored in Secret Manager]"

