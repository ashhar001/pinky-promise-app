# 🚀 Pinky Promise Infrastructure & Application Deployment Action Plan

## 🏁 Complete Two-Repository Strategy

### Repository 1: Infrastructure Repository (THIS REPO)
**Purpose**: Infrastructure deployment and GitOps management

✅ **COMPLETED**:
- ✅ Terraform infrastructure code
- ✅ Infrastructure CI/CD pipeline (`.github/workflows/infrastructure.yml`)
- ✅ ArgoCD configuration
- ✅ Kubernetes base manifests
- ✅ Comprehensive documentation

### Repository 2: Application Repository (TO BE CREATED)
**Purpose**: Application source code and deployment manifests

## 📝 Action Steps

### Phase 1: Setup Google Cloud Infrastructure 🏇️

#### Step 1.1: GCP Project Setup
```bash
# Set your project ID
export PROJECT_ID="pinky-promise-app"  # Change this to your actual project ID
gcloud config set project $PROJECT_ID

# Enable required APIs
gcloud services enable container.googleapis.com
gcloud services enable sqladmin.googleapis.com
gcloud services enable compute.googleapis.com
gcloud services enable servicenetworking.googleapis.com
gcloud services enable cloudresourcemanager.googleapis.com
gcloud services enable artifactregistry.googleapis.com

# Create service account for GitHub Actions
gcloud iam service-accounts create github-actions \
    --description="Service account for GitHub Actions" \
    --display-name="GitHub Actions"

# Grant permissions
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:github-actions@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/editor"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:github-actions@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/container.admin"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:github-actions@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/cloudsql.admin"

# Create service account key
gcloud iam service-accounts keys create github-actions-key.json \
    --iam-account=github-actions@$PROJECT_ID.iam.gserviceaccount.com

# Create Terraform state bucket
gsutil mb gs://$PROJECT_ID-terraform-state
gsutil versioning set on gs://$PROJECT_ID-terraform-state
```

#### Step 1.2: Configure GitHub Secrets (Infrastructure Repository)
Add these secrets to this repository:
- `GCP_SA_KEY`: Contents of `github-actions-key.json`
- `TF_STATE_BUCKET`: `your-project-id-terraform-state`

#### Step 1.3: Update Configuration Files
1. **Update `terraform/terraform.tfvars`**:
   ```hcl
   project_id = "your-actual-project-id"
   environment = "production"
   alert_email = "your-email@example.com"
   ```

2. **Update `.github/workflows/infrastructure.yml`**:
   ```yaml
   env:
     PROJECT_ID: 'your-actual-project-id'
   ```

### Phase 2: Deploy Infrastructure 📍

#### Step 2.1: Test Infrastructure Pipeline
```bash
# Create a feature branch
git checkout -b setup-infrastructure

# Make a small change to test the pipeline
echo "# Infrastructure setup" >> terraform/README.md

# Commit and push
git add .
git commit -m "Setup infrastructure pipeline"
git push origin setup-infrastructure

# Create a pull request to test validation pipeline
```

#### Step 2.2: Deploy Infrastructure
```bash
# Merge to main to trigger deployment
git checkout main
git merge setup-infrastructure
git push origin main

# Monitor the GitHub Actions deployment
```

### Phase 3: Create Application Repository 📁

#### Step 3.1: Create New Repository
1. Create a new GitHub repository: `pinky-promise-app-source`
2. Clone it locally:
   ```bash
   git clone https://github.com/YOUR_USERNAME/pinky-promise-app-source.git
   cd pinky-promise-app-source
   ```

#### Step 3.2: Move Application Code
```bash
# From your infrastructure repository root
cd /path/to/pinky-promise-app

# Create application repository structure
mkdir -p ../pinky-promise-app-source/src
cp -r pinky-promise-app ../pinky-promise-app-source/src/frontend
cp -r backend ../pinky-promise-app-source/src/backend

# Copy Dockerfiles
cp deploy/backend/Dockerfile ../pinky-promise-app-source/src/backend/
cp deploy/frontend/Dockerfile ../pinky-promise-app-source/src/frontend/
cp deploy/frontend/nginx.conf ../pinky-promise-app-source/src/frontend/
```

#### Step 3.3: Create Application Kubernetes Manifests
Refer to `docs/APPLICATION_REPOSITORY_SETUP.md` for detailed manifests.

#### Step 3.4: Set Up Application CI/CD Pipelines
Copy the pipeline configurations from `docs/APPLICATION_REPOSITORY_SETUP.md`.

#### Step 3.5: Configure Application Repository Secrets
Add the same secrets as the infrastructure repository:
- `GCP_SA_KEY`

### Phase 4: Connect ArgoCD to Application Repository 🔗

#### Step 4.1: Update ArgoCD Configuration
In this repository, update `kubernetes/argocd/pinky-promise-app.yaml`:
```yaml
source:
  repoURL: https://github.com/YOUR_USERNAME/pinky-promise-app-source
```

#### Step 4.2: Commit ArgoCD Changes
```bash
git add kubernetes/argocd/pinky-promise-app.yaml
git commit -m "Update ArgoCD to point to application repository"
git push origin main
```

### Phase 5: Test Complete GitOps Workflow 🧪

#### Step 5.1: Access ArgoCD UI
```bash
# Get cluster credentials
gcloud container clusters get-credentials pinky-promise-cluster \
  --zone us-central1-a --project your-project-id

# Port forward to ArgoCD
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Get initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
```

#### Step 5.2: Test Application Deployment
1. Make a change to application code in the application repository
2. Push to main branch
3. Verify GitHub Actions builds and pushes images
4. Verify ArgoCD detects and deploys changes

### Phase 6: Configure Domain and HTTPS 🔒

#### Step 6.1: Set Up External IP and Domain
```bash
# Reserve static IP
gcloud compute addresses create pinky-promise-ip --global

# Get the IP address
gcloud compute addresses describe pinky-promise-ip --global
```

#### Step 6.2: Configure DNS
Point your domain to the reserved IP address.

#### Step 6.3: Set Up HTTPS with Let's Encrypt
This will be handled by the ingress configuration in the Kubernetes manifests.

## 📊 Pipeline Overview

### Infrastructure Repository Pipeline
**Triggers**: Changes to `terraform/` or `kubernetes/`

**Non-main branches**:
- ✅ Terraform Format Check
- ✅ Terraform Validate 
- ✅ Terraform Plan
- ✅ Security Scan

**Main branch (additional)**:
- ✅ Terraform Apply
- ✅ ArgoCD Installation
- ✅ ArgoCD Configuration

### Application Repository Pipeline
**Triggers**: Changes to `src/backend/` or `src/frontend/`

**All branches**:
- ✅ Run Tests
- ✅ Code Linting
- ✅ Build Application

**Main branch (additional)**:
- ✅ Build Docker Images
- ✅ Push to Artifact Registry
- ✅ Update Kubernetes Manifests
- ✅ ArgoCD Auto-Deploy

## 🔄 GitOps Workflow

1. **Developer** pushes code changes to application repository
2. **GitHub Actions** tests, builds, and pushes Docker images
3. **GitHub Actions** updates Kubernetes manifests with new image tags
4. **ArgoCD** detects manifest changes
5. **ArgoCD** automatically deploys to Kubernetes cluster
6. **Application** is updated with zero downtime

## 📈 Benefits

✅ **Separation of Concerns**: Infrastructure and application code are separate
✅ **GitOps**: All deployments are version-controlled and auditable
✅ **Automated**: Zero manual deployment steps
✅ **Scalable**: Can handle multiple applications and environments
✅ **Secure**: Proper secrets management and RBAC
✅ **Observable**: Comprehensive monitoring and alerting
✅ **Resilient**: Automatic rollbacks and health checks

## 🛠️ Maintenance

### Regular Tasks
- Monitor ArgoCD applications
- Review Terraform plan outputs
- Update Docker base images
- Review security scan results
- Monitor resource usage and costs

### Scaling
- Add new applications by creating new ArgoCD Application manifests
- Add new environments by duplicating the application repository structure
- Scale infrastructure by updating Terraform variables

## 🎆 Success Criteria

✅ Infrastructure deploys automatically on merge to main
✅ Application deploys automatically when code changes
✅ ArgoCD UI is accessible and shows application status
✅ Application is accessible via public URL
✅ Database is properly connected and secured
✅ Monitoring and alerting are working
✅ CI/CD pipelines pass all stages
✅ Security scans pass
✅ Application performs under load

## 👥 Team Workflow

### For Infrastructure Changes
1. Create feature branch from infrastructure repository
2. Make changes to Terraform or Kubernetes configs
3. Push branch (triggers validation pipeline)
4. Create pull request
5. Review Terraform plan output
6. Merge to main (triggers deployment)

### For Application Changes
1. Create feature branch from application repository
2. Make code changes to frontend or backend
3. Push branch (triggers tests and builds)
4. Create pull request
5. Review test results and code coverage
6. Merge to main (triggers deployment via ArgoCD)

This comprehensive plan provides a production-ready, scalable, and maintainable infrastructure with full GitOps automation! 🚀

