#!/bin/bash

# Script to update reCAPTCHA configuration for Pinky Promise App
# Run this after creating new reCAPTCHA keys for your domain

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# Configuration
PROJECT_ID="pinky-promise-app"
REGION="us-central1"
FRONTEND_DOMAIN="pinky-promise-frontend-834416223716.us-central1.run.app"

log() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
info() { echo -e "${BLUE}[UPDATE]${NC} $1"; }

echo -e "${GREEN}"
echo "============================================================"
echo "         reCAPTCHA Configuration Update"
echo "============================================================"
echo -e "${NC}"

echo "Your frontend domain: https://$FRONTEND_DOMAIN"
echo ""
echo "To set up reCAPTCHA:"
echo "1. Go to: https://www.google.com/recaptcha/admin"
echo "2. Create a new site with the following settings:"
echo "   - Type: reCAPTCHA v2 ('I'm not a robot' checkbox)"
echo "   - Domain: $FRONTEND_DOMAIN"
echo "3. Copy the Site Key and Secret Key"
echo ""

# Get user input for the keys
read -p "Enter your new reCAPTCHA Site Key: " SITE_KEY
read -p "Enter your new reCAPTCHA Secret Key: " SECRET_KEY

if [ -z "$SITE_KEY" ] || [ -z "$SECRET_KEY" ]; then
    error "Both Site Key and Secret Key are required!"
fi

info "Updating frontend configuration..."

# Update frontend .env.production
cat > ../pinky-promise-app/.env.production << EOF
REACT_APP_API_URL=https://pinky-promise-backend-834416223716.us-central1.run.app
# reCAPTCHA Site Key for Cloud Run domain
# Domain: $FRONTEND_DOMAIN
REACT_APP_RECAPTCHA_SITE_KEY=$SITE_KEY
EOF

log "Frontend configuration updated"

info "Updating backend secret in Secret Manager..."

# Update the secret in Secret Manager
echo -n "$SECRET_KEY" | gcloud secrets versions add recaptcha-secret-key --data-file=-

log "Backend secret updated in Secret Manager"

info "Rebuilding and deploying frontend with new reCAPTCHA configuration..."

# Rebuild frontend with new environment variables
docker build --platform linux/amd64 \
    -t gcr.io/$PROJECT_ID/pinky-promise-frontend:recaptcha-fix \
    -f ../deploy/frontend/Dockerfile \
    ../pinky-promise-app

# Push the new image
docker push gcr.io/$PROJECT_ID/pinky-promise-frontend:recaptcha-fix

# Deploy the updated frontend
gcloud run deploy pinky-promise-frontend \
    --image gcr.io/$PROJECT_ID/pinky-promise-frontend:recaptcha-fix \
    --region $REGION \
    --platform managed \
    --allow-unauthenticated

info "Updating backend to use new reCAPTCHA secret..."

# Update backend service to use the new secret
gcloud run services update pinky-promise-backend \
    --region $REGION \
    --update-env-vars RECAPTCHA_SECRET_KEY=$SECRET_KEY

log "Backend updated with new reCAPTCHA secret"

echo -e "${GREEN}"
echo "============================================================"
echo "         reCAPTCHA Update Completed Successfully!"
echo "============================================================"
echo -e "${NC}"
echo "✅ Frontend deployed with new Site Key"
echo "✅ Backend updated with new Secret Key"
echo "✅ Secret stored securely in Secret Manager"
echo ""
echo "🌐 Test your application at: https://$FRONTEND_DOMAIN"
echo "📝 The login and signup forms should now work with reCAPTCHA"
echo ""
echo "Note: It may take a few minutes for the changes to take effect."

