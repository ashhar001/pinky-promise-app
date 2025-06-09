#!/bin/bash

# Pinky Promise App - GCP Resource Cleanup Script
# This script safely destroys all GCP resources for the Pinky Promise application

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
  echo -e "${BLUE}[CLEANUP]${NC} $1"
}

echo -e "${RED}"
echo "============================================================"
echo "       Pinky Promise App - GCP Resource Cleanup"
echo "                    ⚠️  WARNING ⚠️"
echo "     This will permanently delete ALL GCP resources!"
echo "============================================================"
echo -e "${NC}"

# Confirm with user
read -p "Are you absolutely sure you want to delete ALL Pinky Promise GCP resources? (type 'YES' to confirm): " confirmation
if [[ "$confirmation" != "YES" ]]; then
  echo "Cleanup cancelled."
  exit 0
fi

echo ""
log "Starting cleanup process..."

# 1. Delete Cloud Run services
info "Deleting Cloud Run services..."
if gcloud run services describe pinky-promise-backend --region=$REGION &>/dev/null; then
  gcloud run services delete pinky-promise-backend --region=$REGION --quiet
  log "Deleted Cloud Run service: pinky-promise-backend"
else
  warn "Cloud Run service pinky-promise-backend not found"
fi

if gcloud run services describe pinky-promise-frontend --region=$REGION &>/dev/null; then
  gcloud run services delete pinky-promise-frontend --region=$REGION --quiet
  log "Deleted Cloud Run service: pinky-promise-frontend"
else
  warn "Cloud Run service pinky-promise-frontend not found"
fi

# 2. Delete Container Registry images
info "Deleting Container Registry images..."
if gcloud container images list --repository=gcr.io/$PROJECT_ID --format="value(name)" 2>/dev/null | grep -q "pinky-promise-backend"; then
  gcloud container images delete gcr.io/$PROJECT_ID/pinky-promise-backend --force-delete-tags --quiet
  log "Deleted container image: pinky-promise-backend"
else
  warn "Container image pinky-promise-backend not found"
fi

if gcloud container images list --repository=gcr.io/$PROJECT_ID --format="value(name)" 2>/dev/null | grep -q "pinky-promise-frontend"; then
  gcloud container images delete gcr.io/$PROJECT_ID/pinky-promise-frontend --force-delete-tags --quiet
  log "Deleted container image: pinky-promise-frontend"
else
  warn "Container image pinky-promise-frontend not found"
fi

# 3. Delete Cloud SQL instance
info "Deleting Cloud SQL instance..."
if gcloud sql instances describe pinky-promise-db &>/dev/null; then
  # Remove deletion protection if enabled
  gcloud sql instances patch pinky-promise-db --no-deletion-protection --quiet
  gcloud sql instances delete pinky-promise-db --quiet
  log "Deleted Cloud SQL instance: pinky-promise-db"
else
  warn "Cloud SQL instance pinky-promise-db not found"
fi

# Check for production database too
if gcloud sql instances describe pinky-promise-db-prod &>/dev/null; then
  gcloud sql instances patch pinky-promise-db-prod --no-deletion-protection --quiet
  gcloud sql instances delete pinky-promise-db-prod --quiet
  log "Deleted Cloud SQL instance: pinky-promise-db-prod"
else
  warn "Cloud SQL instance pinky-promise-db-prod not found"
fi

# 4. Delete secrets from Secret Manager
info "Deleting secrets from Secret Manager..."
secrets=("jwt-secret" "jwt-refresh-secret" "jwt-secret-prod" "jwt-refresh-secret-prod" "db-password-prod" "recaptcha-secret-key")

for secret in "${secrets[@]}"; do
  if gcloud secrets describe "$secret" &>/dev/null; then
    gcloud secrets delete "$secret" --quiet
    log "Deleted secret: $secret"
  else
    warn "Secret $secret not found"
  fi
done

# 5. Delete any Cloud Build triggers (if they exist)
info "Checking for Cloud Build triggers..."
triggers=$(gcloud builds triggers list --format="value(name)" 2>/dev/null | grep -i pinky || true)
if [[ -n "$triggers" ]]; then
  while read -r trigger; do
    if [[ -n "$trigger" ]]; then
      gcloud builds triggers delete "$trigger" --quiet
      log "Deleted build trigger: $trigger"
    fi
  done <<< "$triggers"
else
  warn "No Cloud Build triggers found"
fi

# 6. Clean up any remaining monitoring resources
info "Cleaning up monitoring resources..."
uptime_checks=$(gcloud monitoring uptime-check-configs list --format="value(name)" --filter="displayName:('Production Backend Health Check' OR 'Production Frontend Health Check')" 2>/dev/null || true)
if [[ -n "$uptime_checks" ]]; then
  while read -r check; do
    if [[ -n "$check" ]]; then
      gcloud monitoring uptime-check-configs delete "$check" --quiet
      log "Deleted uptime check: $check"
    fi
  done <<< "$uptime_checks"
else
  warn "No uptime checks found"
fi

# 7. Clean up any IAM policy bindings (optional - be careful with this)
info "Note: IAM policy bindings are left intact for safety"
warn "If you want to clean up IAM bindings, do so manually after reviewing them"

echo ""
echo -e "${GREEN}"
echo "============================================================"
echo "           GCP Resource Cleanup Completed!"
echo "============================================================"
echo -e "${NC}"
echo "The following resources have been deleted:"
echo "✓ Cloud Run services (pinky-promise-backend, pinky-promise-frontend)"
echo "✓ Container Registry images"
echo "✓ Cloud SQL instances (pinky-promise-db, pinky-promise-db-prod if existed)"
echo "✓ Secret Manager secrets"
echo "✓ Cloud Build triggers (if any existed)"
echo "✓ Monitoring uptime checks (if any existed)"
echo ""
echo "Note: The GCP project '$PROJECT_ID' itself was not deleted."
echo "If you want to delete the entire project, run:"
echo "  gcloud projects delete $PROJECT_ID"
echo ""
log "Cleanup completed successfully!"

