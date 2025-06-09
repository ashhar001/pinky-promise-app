# Pinky Promise App - Production Deployment Guide

This guide provides step-by-step instructions for deploying the Pinky Promise application to Google Cloud Platform (GCP) with CI/CD pipeline integration. The architecture consists of a React frontend, Node.js backend, and PostgreSQL database.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Initial Setup](#initial-setup)
- [Local Testing with Docker](#local-testing-with-docker)
- [GCP Setup](#gcp-setup)
- [Database Setup](#database-setup)
- [CI/CD Configuration](#cicd-configuration)
- [Manual Deployment](#manual-deployment)
- [Security Best Practices](#security-best-practices)
- [Monitoring and Maintenance](#monitoring-and-maintenance)
- [Troubleshooting](#troubleshooting)

## Prerequisites

- [Google Cloud SDK](https://cloud.google.com/sdk/docs/install)
- [Docker](https://docs.docker.com/get-docker/) and [Docker Compose](https://docs.docker.com/compose/install/)
- [Node.js](https://nodejs.org/) (v14 or later)
- [git](https://git-scm.com/downloads)

## Initial Setup

### 1. Clone the Repository

```bash
git clone https://github.com/your-username/pinky-promise-app.git
cd pinky-promise-app
```

### 2. Set Up Environment Variables

Create `.env` files for both backend and frontend:

**Backend `.env`**:
```bash
# Server Configuration
PORT=5001
NODE_ENV=production

# Database Configuration
DATABASE_URL=postgresql://postgres:postgres@localhost:5432/pinky_promise

# JWT Configuration
JWT_SECRET=your_jwt_secret_here
JWT_REFRESH_SECRET=your_jwt_refresh_secret_here

# reCAPTCHA Configuration
RECAPTCHA_SECRET_KEY=your_recaptcha_secret_key_here
```

**Frontend `.env`**:
```bash
REACT_APP_API_URL=https://api.pinky-promise.example.com
REACT_APP_RECAPTCHA_SITE_KEY=your_recaptcha_site_key_here
```

## Local Testing with Docker

Before deploying to GCP, test your containerized application locally:

```bash
# Navigate to the project root
cd pinky-promise-app

# Create an environment file for docker-compose
cat > .env << EOL
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres
POSTGRES_DB=pinky_promise
JWT_SECRET=local_jwt_secret
JWT_REFRESH_SECRET=local_jwt_refresh_secret
RECAPTCHA_SECRET_KEY=local_recaptcha_secret_key
EOL

# Start the containers
docker-compose -f deploy/docker-compose.yml up --build
```

Visit `http://localhost` to access the application. The API will be available at `http://localhost/api`.

## GCP Setup

### 1. Initialize GCP Project

```bash
# Login to GCP
gcloud auth login

# Create a new project (or use an existing one)
gcloud projects create pinky-promise-app --name="Pinky Promise App"

# Set the project
gcloud config set project pinky-promise-app

# Enable required APIs
gcloud services enable cloudbuild.googleapis.com
gcloud services enable containerregistry.googleapis.com
gcloud services enable run.googleapis.com
gcloud services enable sqladmin.googleapis.com
gcloud services enable secretmanager.googleapis.com
```

### 2. Set Up GCP Secrets

Store sensitive information in Secret Manager:

```bash
# Create secrets
echo -n "your_jwt_secret_here" | gcloud secrets create jwt-secret --data-file=-
echo -n "your_jwt_refresh_secret_here" | gcloud secrets create jwt-refresh-secret --data-file=-
echo -n "your_recaptcha_secret_key_here" | gcloud secrets create recaptcha-secret-key --data-file=-

# Set up IAM permissions for Cloud Run to access secrets
gcloud secrets add-iam-policy-binding jwt-secret \
    --member="serviceAccount:service-PROJECT_NUMBER@gcp-sa-cloudrun.iam.gserviceaccount.com" \
    --role="roles/secretmanager.secretAccessor"

gcloud secrets add-iam-policy-binding jwt-refresh-secret \
    --member="serviceAccount:service-PROJECT_NUMBER@gcp-sa-cloudrun.iam.gserviceaccount.com" \
    --role="roles/secretmanager.secretAccessor"

gcloud secrets add-iam-policy-binding recaptcha-secret-key \
    --member="serviceAccount:service-PROJECT_NUMBER@gcp-sa-cloudrun.iam.gserviceaccount.com" \
    --role="roles/secretmanager.secretAccessor"
```

## Database Setup

### 1. Create Cloud SQL Instance

```bash
# Create PostgreSQL instance
gcloud sql instances create pinky-promise-db \
    --database-version=POSTGRES_14 \
    --tier=db-f1-micro \
    --region=us-central1 \
    --storage-type=SSD \
    --storage-size=10GB \
    --backup-start-time=23:00 \
    --availability-type=zonal

# Create database
gcloud sql databases create pinky_promise --instance=pinky-promise-db

# Create user
gcloud sql users create pinky_promise_user \
    --instance=pinky-promise-db \
    --password=your_secure_password
```

### 2. Set Up Database Connection

Create a connection to Cloud SQL for your Cloud Run services:

```bash
# Create a service account for Cloud SQL
gcloud iam service-accounts create cloud-sql-proxy

# Grant necessary permissions
gcloud projects add-iam-policy-binding pinky-promise-app \
    --member="serviceAccount:cloud-sql-proxy@pinky-promise-app.iam.gserviceaccount.com" \
    --role="roles/cloudsql.client"
```

### 3. Initialize Database Schema

Connect to your database and run your schema migrations:

```bash
# Connect to Cloud SQL instance
gcloud sql connect pinky-promise-db --user=pinky_promise_user

# Run schema migration (inside the SQL prompt)
\i /path/to/schema.sql
```

## CI/CD Configuration

### 1. Set Up Cloud Build Trigger

```bash
# Create a build trigger
gcloud builds triggers create github \
    --repo=your-username/pinky-promise-app \
    --branch-pattern="^main$" \
    --build-config=deploy/cloudbuild.yaml
```

### 2. Configure Service Connections

Update your Cloud Run services to connect to Cloud SQL:

```bash
# Update backend service
gcloud run services update pinky-promise-backend \
    --add-cloudsql-instances=pinky-promise-app:us-central1:pinky-promise-db \
    --update-env-vars="DATABASE_URL=postgresql://pinky_promise_user:your_secure_password@localhost:5432/pinky_promise?host=/cloudsql/pinky-promise-app:us-central1:pinky-promise-db"
```

### 3. Set Up Custom Domain (Optional)

```bash
# Map custom domain to frontend service
gcloud beta run domain-mappings create \
    --service pinky-promise-frontend \
    --domain app.pinky-promise.example.com \
    --region us-central1

# Map custom domain to backend service
gcloud beta run domain-mappings create \
    --service pinky-promise-backend \
    --domain api.pinky-promise.example.com \
    --region us-central1
```

## Manual Deployment

If you need to deploy manually without CI/CD:

### 1. Backend Deployment

```bash
# Build the backend image
docker build -t gcr.io/pinky-promise-app/pinky-promise-backend:latest \
    -f deploy/backend/Dockerfile ./backend

# Push the image
docker push gcr.io/pinky-promise-app/pinky-promise-backend:latest

# Deploy to Cloud Run
gcloud run deploy pinky-promise-backend \
    --image gcr.io/pinky-promise-app/pinky-promise-backend:latest \
    --region us-central1 \
    --platform managed \
    --allow-unauthenticated \
    --add-cloudsql-instances=pinky-promise-app:us-central1:pinky-promise-db \
    --update-env-vars="DATABASE_URL=postgresql://pinky_promise_user:your_secure_password@localhost:5432/pinky_promise?host=/cloudsql/pinky-promise-app:us-central1:pinky-promise-db,JWT_SECRET=sm://projects/pinky-promise-app/secrets/jwt-secret/versions/latest,JWT_REFRESH_SECRET=sm://projects/pinky-promise-app/secrets/jwt-refresh-secret/versions/latest,RECAPTCHA_SECRET_KEY=sm://projects/pinky-promise-app/secrets/recaptcha-secret-key/versions/latest"
```

### 2. Frontend Deployment

```bash
# Update frontend API URL
echo "REACT_APP_API_URL=https://api.pinky-promise.example.com" > ./pinky-promise-app/.env.production

# Build the frontend image
docker build -t gcr.io/pinky-promise-app/pinky-promise-frontend:latest \
    -f deploy/frontend/Dockerfile ./pinky-promise-app

# Push the image
docker push gcr.io/pinky-promise-app/pinky-promise-frontend:latest

# Deploy to Cloud Run
gcloud run deploy pinky-promise-frontend \
    --image gcr.io/pinky-promise-app/pinky-promise-frontend:latest \
    --region us-central1 \
    --platform managed \
    --allow-unauthenticated
```

## Security Best Practices

1. **Keep Secrets in Secret Manager**:
   - Never store secrets in code or environment files
   - Use GCP Secret Manager for all sensitive data

2. **Use Secure Network Policies**:
   - Configure VPC Service Controls to restrict network access
   - Use Cloud IAM to manage service account permissions

3. **Enable Cloud Armor**:
   - Set up Web Application Firewall to protect against attacks
   - Configure rate limiting and IP allow/deny lists

4. **Implement HTTPS**:
   - Use managed SSL certificates for custom domains
   - Configure secure headers in your Nginx configuration

5. **Regular Security Updates**:
   - Keep base images up-to-date
   - Implement vulnerability scanning with Container Analysis

## Monitoring and Maintenance

### 1. Set Up Monitoring

```bash
# Enable Cloud Monitoring API
gcloud services enable monitoring.googleapis.com

# Create uptime checks
gcloud monitoring uptime-check-configs create http-frontend \
    --display-name="Frontend Uptime Check" \
    --http-check=host=app.pinky-promise.example.com,path=/health

gcloud monitoring uptime-check-configs create http-backend \
    --display-name="Backend Uptime Check" \
    --http-check=host=api.pinky-promise.example.com,path=/
```

### 2. Set Up Logging

```bash
# Enable Cloud Logging API
gcloud services enable logging.googleapis.com

# View logs
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=pinky-promise-backend"
```

### 3. Set Up Alerting

```bash
# Create a notification channel (email)
gcloud alpha monitoring channels create \
    --display-name="DevOps Team Email" \
    --type=email \
    --channel-labels=email_address=devops@pinky-promise.example.com

# Create an alert policy
gcloud alpha monitoring policies create \
    --display-name="Backend Error Rate Alert" \
    --condition-filter="resource.type=\"cloud_run_revision\" AND resource.labels.service_name=\"pinky-promise-backend\" AND metric.type=\"logging.googleapis.com/log_entry_count\" AND metric.labels.severity=\"ERROR\"" \
    --condition-threshold-value=10 \
    --condition-threshold-duration=300s \
    --notification-channels=your-channel-id
```

## Troubleshooting

### Common Issues

1. **Database Connection Issues**:
   - Verify Cloud SQL connection string
   - Check IAM permissions for service account
   - Ensure Cloud SQL Admin API is enabled

2. **Deployment Failures**:
   - Check Cloud Build logs: `gcloud builds list`
   - Verify Dockerfile paths and build contexts
   - Check for quota limits and billing status

3. **Runtime Errors**:
   - Check application logs: `gcloud logging read "resource.type=cloud_run_revision"`
   - Verify environment variables are correctly set
   - Check for mismatched API endpoints between frontend and backend

### Getting Help

If you encounter issues not covered in this guide:

1. Check the [GCP documentation](https://cloud.google.com/docs)
2. Visit [Stack Overflow](https://stackoverflow.com/questions/tagged/google-cloud-platform)
3. Contact GCP Support if you have a support plan

---

This guide should provide a comprehensive roadmap for deploying the Pinky Promise application to GCP with CI/CD integration. For specific questions or issues, please contact your DevOps team.

# Pinky Promise App - Production Deployment Guide

This guide provides step-by-step instructions for deploying the Pinky Promise application to Google Cloud Platform (GCP) with CI/CD pipeline integration. The architecture consists of a React frontend, Node.js backend, and PostgreSQL database.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Initial Setup](#initial-setup)
- [Local Testing with Docker](#local-testing-with-docker)
- [GCP Setup](#gcp-setup)
- [Database Setup](#database-setup)
- [CI/CD Configuration](#cicd-configuration)
- [Manual Deployment](#manual-deployment)
- [Security Best Practices](#security-best-practices)
- [Monitoring and Maintenance](#monitoring-and-maintenance)
- [Troubleshooting](#troubleshooting)

## Prerequisites

- [Google Cloud SDK](https://cloud.google.com/sdk/docs/install)
- [Docker](https://docs.docker.com/get-docker/) and [Docker Compose](https://docs.docker.com/compose/install/)
- [Node.js](https://nodejs.org/) (v14 or later)
- [git](https://git-scm.com/downloads)

## Initial Setup

### 1. Clone the Repository

```bash
git clone https://github.com/your-username/pinky-promise-app.git
cd pinky-promise-app
```

### 2. Set Up Environment Variables

Create `.env` files for both backend and frontend:

**Backend `.env`**:
```bash
# Server Configuration
PORT=5001
NODE_ENV=production

# Database Configuration
DATABASE_URL=postgresql://postgres:postgres@localhost:5432/pinky_promise

# JWT Configuration
JWT_SECRET=your_jwt_secret_here
JWT_REFRESH_SECRET=your_jwt_refresh_secret_here

# reCAPTCHA Configuration
RECAPTCHA_SECRET_KEY=your_recaptcha_secret_key_here
```

**Frontend `.env`**:
```bash
REACT_APP_API_URL=https://api.pinky-promise.example.com
REACT_APP_RECAPTCHA_SITE_KEY=your_recaptcha_site_key_here
```

## Local Testing with Docker

Before deploying to GCP, test your containerized application locally:

```bash
# Navigate to the project root
cd pinky-promise-app

# Create an environment file for docker-compose
cat > .env << EOL
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres
POSTGRES_DB=pinky_promise
JWT_SECRET=local_jwt_secret
JWT_REFRESH_SECRET=local_jwt_refresh_secret
RECAPTCHA_SECRET_KEY=local_recaptcha_secret_key
EOL

# Start the containers
docker-compose -f deploy/docker-compose.yml up --build
```

Visit `http://localhost` to access the application. The API will be available at `http://localhost/api`.

## GCP Setup

### 1. Initialize GCP Project

```bash
# Login to GCP
gcloud auth login

# Create a new project (or use an existing one)
gcloud projects create pinky-promise-app --name="Pinky Promise App"

# Set the project
gcloud config set project pinky-promise-app

# Enable required APIs
gcloud services enable cloudbuild.googleapis.com
gcloud services enable containerregistry.googleapis.com
gcloud services enable run.googleapis.com
gcloud services enable sqladmin.googleapis.com
gcloud services enable secretmanager.googleapis.com
```

### 2. Set Up GCP Secrets

Store sensitive information in Secret Manager:

```bash
# Create secrets
echo -n "your_jwt_secret_here" | gcloud secrets create jwt-secret --data-file=-
echo -n "your_jwt_refresh_secret_here" | gcloud secrets create jwt-refresh-secret --data-file=-
echo -n "your_recaptcha_secret_key_here" | gcloud secrets create recaptcha-secret-key --data-file=-

# Set up IAM permissions for Cloud Run to access secrets
gcloud secrets add-iam-policy-binding jwt-secret \
    --member="serviceAccount:service-PROJECT_NUMBER@gcp-sa-cloudrun.iam.gserviceaccount.com" \
    --role="roles/secretmanager.secretAccessor"

gcloud secrets add-iam-policy-binding jwt-refresh-secret \
    --member="serviceAccount:service-PROJECT_NUMBER@gcp-sa-cloudrun.iam.gserviceaccount.com" \
    --role="roles/secretmanager.secretAccessor"

gcloud secrets add-iam-policy-binding recaptcha-secret-key \
    --member="serviceAccount:service-PROJECT_NUMBER@gcp-sa-cloudrun.iam.gserviceaccount.com" \
    --role="roles/secretmanager.secretAccessor"
```

## Database Setup

### 1. Create Cloud SQL Instance

```bash
# Create PostgreSQL instance
gcloud sql instances create pinky-promise-db \
    --database-version=POSTGRES_14 \
    --tier=db-f1-micro \
    --region=us-central1 \
    --storage-type=SSD \
    --storage-size=10GB \
    --backup-start-time=23:00 \
    --availability-type=zonal

# Create database
gcloud sql databases create pinky_promise --instance=pinky-promise-db

# Create user
gcloud sql users create pinky_promise_user \
    --instance=pinky-promise-db \
    --password=your_secure_password
```

### 2. Set Up Database Connection

Create a connection to Cloud SQL for your Cloud Run services:

```bash
# Create a service account for Cloud SQL
gcloud iam service-accounts create cloud-sql-proxy

# Grant necessary permissions
gcloud projects add-iam-policy-binding pinky-promise-app \
    --member="serviceAccount:cloud-sql-proxy@pinky-promise-app.iam.gserviceaccount.com" \
    --role="roles/cloudsql.client"
```

### 3. Initialize Database Schema

Connect to your database and run your schema migrations:

```bash
# Connect to Cloud SQL instance
gcloud sql connect pinky-promise-db --user=pinky_promise_user

# Run schema migration (inside the SQL prompt)
\i /path/to/schema.sql
```

## CI/CD Configuration

### 1. Set Up Cloud Build Trigger

```bash
# Create a build trigger
gcloud builds triggers create github \
    --repo=your-username/pinky-promise-app \
    --branch-pattern="^main$" \
    --build-config=deploy/cloudbuild.yaml
```

### 2. Configure Service Connections

Update your Cloud Run services to connect to Cloud SQL:

```bash
# Update backend service
gcloud run services update pinky-promise-backend \
    --add-cloudsql-instances=pinky-promise-app:us-central1:pinky-promise-db \
    --update-env-vars="DATABASE_URL=postgresql://pinky_promise_user:your_secure_password@localhost:5432/pinky_promise?host=/cloudsql/pinky-promise-app:us-central1:pinky-promise-db"
```

### 3. Set Up Custom Domain (Optional)

```bash
# Map custom domain to frontend service
gcloud beta run domain-mappings create \
    --service pinky-promise-frontend \
    --domain app.pinky-promise.example.com \
    --region us-central1

# Map custom domain to backend service
gcloud beta run domain-mappings create \
    --service pinky-promise-backend \
    --domain api.pinky-promise.example.com \
    --region us-central1
```

## Manual Deployment

If you need to deploy manually without CI/CD:

### 1. Backend Deployment

```bash
# Build the backend image
docker build -t gcr.io/pinky-promise-app/pinky-promise-backend:latest \
    -f deploy/backend/Dockerfile ./backend

# Push the image
docker push gcr.io/pinky-promise-app/pinky-promise-backend:latest

# Deploy to Cloud Run
gcloud run deploy pinky-promise-backend \
    --image gcr.io/pinky-promise-app/pinky-promise-backend:latest \
    --region us-central1 \
    --platform managed \
    --allow-unauthenticated \
    --add-cloudsql-instances=pinky-promise-app:us-central1:pinky-promise-db \
    --update-env-vars="DATABASE_URL=postgresql://pinky_promise_user:your_secure_password@localhost:5432/pinky_promise?host=/cloudsql/pinky-promise-app:us-central1:pinky-promise-db,JWT_SECRET=sm://projects/pinky-promise-app/secrets/jwt-secret/versions/latest,JWT_REFRESH_SECRET=sm://projects/pinky-promise-app/secrets/jwt-refresh-secret/versions/latest,RECAPTCHA_SECRET_KEY=sm://projects/pinky-promise-app/secrets/recaptcha-secret-key/versions/latest"
```

### 2. Frontend Deployment

```bash
# Update frontend API URL
echo "REACT_APP_API_URL=https://api.pinky-promise.example.com" > ./pinky-promise-app/.env.production

# Build the frontend image
docker build -t gcr.io/pinky-promise-app/pinky-promise-frontend:latest \
    -f deploy/frontend/Dockerfile ./pinky-promise-app

# Push the image
docker push gcr.io/pinky-promise-app/pinky-promise-frontend:latest

# Deploy to Cloud Run
gcloud run deploy pinky-promise-frontend \
    --image gcr.io/pinky-promise-app/pinky-promise-frontend:latest \
    --region us-central1 \
    --platform managed \
    --allow-unauthenticated
```

## Security Best Practices

1. **Keep Secrets in Secret Manager**:
   - Never store secrets in code or environment files
   - Use GCP Secret Manager for all sensitive data

2. **Use Secure Network Policies**:
   - Configure VPC Service Controls to restrict network access
   - Use Cloud IAM to manage service account permissions

3. **Enable Cloud Armor**:
   - Set up Web Application Firewall to protect against attacks
   - Configure rate limiting and IP allow/deny lists

4. **Implement HTTPS**:
   - Use managed SSL certificates for custom domains
   - Configure secure headers in your Nginx configuration

5. **Regular Security Updates**:
   - Keep base images up-to-date
   - Implement vulnerability scanning with Container Analysis

## Monitoring and Maintenance

### 1. Set Up Monitoring

```bash
# Enable Cloud Monitoring API
gcloud services enable monitoring.googleapis.com

# Create uptime checks
gcloud monitoring uptime-check-configs create http-frontend \
    --display-name="Frontend Uptime Check" \
    --http-check=host=app.pinky-promise.example.com,path=/health

gcloud monitoring uptime-check-configs create http-backend \
    --display-name="Backend Uptime Check" \
    --http-check=host=api.pinky-promise.example.com,path=/
```

### 2. Set Up Logging

```bash
# Enable Cloud Logging API
gcloud services enable logging.googleapis.com

# View logs
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=pinky-promise-backend"
```

### 3. Set Up Alerting

```bash
# Create a notification channel (email)
gcloud alpha monitoring channels create \
    --display-name="DevOps Team Email" \
    --type=email \
    --channel-labels=email_address=devops@pinky-promise.example.com

# Create an alert policy
gcloud alpha monitoring policies create \
    --display-name="Backend Error Rate Alert" \
    --condition-filter="resource.type=\"cloud_run_revision\" AND resource.labels.service_name=\"pinky-promise-backend\" AND metric.type=\"logging.googleapis.com/log_entry_count\" AND metric.labels.severity=\"ERROR\"" \
    --condition-threshold-value=10 \
    --condition-threshold-duration=300s \
    --notification-channels=your-channel-id
```

## Troubleshooting

### Common Issues

1. **Database Connection Issues**:
   - Verify Cloud SQL connection string
   - Check IAM permissions for service account
   - Ensure Cloud SQL Admin API is enabled

2. **Deployment Failures**:
   - Check Cloud Build logs: `gcloud builds list`
   - Verify Dockerfile paths and build contexts
   - Check for quota limits and billing status

3. **Runtime Errors**:
   - Check application logs: `gcloud logging read "resource.type=cloud_run_revision"`
   - Verify environment variables are correctly set
   - Check for mismatched API endpoints between frontend and backend

### Getting Help

If you encounter issues not covered in this guide:

1. Check the [GCP documentation](https://cloud.google.com/docs)
2. Visit [Stack Overflow](https://stackoverflow.com/questions/tagged/google-cloud-platform)
3. Contact GCP Support if you have a support plan

---

This guide should provide a comprehensive roadmap for deploying the Pinky Promise application to GCP with CI/CD integration. For specific questions or issues, please contact your DevOps team.

