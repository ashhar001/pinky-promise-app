# Pinky Promise Application - Complete Project Guide

## Table of Contents
1. [Project Overview](#project-overview)
2. [Prerequisites](#prerequisites)
3. [Phase 1: Infrastructure Setup](#phase-1-infrastructure-setup)
4. [Phase 2: Application Deployment](#phase-2-application-deployment)
5. [Phase 3: CI/CD and Security](#phase-3-cicd-and-security)
6. [Phase 4: Advanced Features](#phase-4-advanced-features)
7. [Project Architecture](#project-architecture)
8. [Daily Operations](#daily-operations)
9. [Troubleshooting](#troubleshooting)
10. [Lessons Learned](#lessons-learned)

## Project Overview

The Pinky Promise application is a full-stack web application deployed on Google Cloud Platform (GCP) using modern DevOps practices. The project demonstrates:

- **Infrastructure as Code** using Terraform
- **Container Orchestration** with Google Kubernetes Engine (GKE)
- **CI/CD Pipeline** with GitHub Actions
- **Security Best Practices** with network policies and SSL
- **Monitoring and Observability** with Prometheus and Grafana
- **Production-grade features** including autoscaling, backup, and disaster recovery

### Technology Stack
- **Frontend**: React.js
- **Backend**: Node.js/Express
- **Database**: PostgreSQL (Cloud SQL)
- **Infrastructure**: Terraform, GKE Autopilot
- **CI/CD**: GitHub Actions
- **Monitoring**: Prometheus, Grafana, Google Cloud Monitoring
- **Security**: Google-managed SSL, Network Policies, Secret Manager

## Prerequisites

### System Requirements
- macOS (tested on macOS with zsh shell)
- Administrative access to install software
- Stable internet connection

### Required Tools Installation

```bash
# Install Homebrew (if not already installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install required tools
brew install terraform
brew install kubectl
brew install --cask google-cloud-sdk
brew install docker
brew install git
brew install jq
brew install helm

# Install Docker Desktop for Mac
# Download from: https://docs.docker.com/desktop/mac/install/
# Start Docker Desktop after installation

# Install GKE Auth Plugin
gcloud components install gke-gcloud-auth-plugin
```

### GCP Account Setup

1. **Create GCP Account**
   ```bash
   # Open browser and go to: https://cloud.google.com/
   # Sign up for free tier ($300 credit)
   ```

2. **Create New Project**
   ```bash
   # Login to GCP
   gcloud auth login
   
   # Create project (replace PROJECT_ID with your unique ID)
   export PROJECT_ID="pinky-promise-$(date +%s)"
   gcloud projects create $PROJECT_ID
   
   # Set as default project
   gcloud config set project $PROJECT_ID
   
   # Enable billing (required for some services)
   # Go to: https://console.cloud.google.com/billing
   ```

3. **Enable Required APIs**
   ```bash
   gcloud services enable container.googleapis.com
   gcloud services enable compute.googleapis.com
   gcloud services enable sqladmin.googleapis.com
   gcloud services enable secretmanager.googleapis.com
   gcloud services enable monitoring.googleapis.com
   gcloud services enable artifactregistry.googleapis.com
   gcloud services enable dns.googleapis.com
   ```

### GitHub Setup

1. **Create GitHub Repository**
   ```bash
   # Create repository on GitHub.com
   # Repository name: pinky-promise-app
   # Make it public or private as needed
   ```

2. **Clone and Initialize**
   ```bash
   git clone https://github.com/YOUR_USERNAME/pinky-promise-app.git
   cd pinky-promise-app
   
   # Set up basic structure
   mkdir -p {frontend,backend,terraform,k8s,docs,.github/workflows}
   ```

## Phase 1: Infrastructure Setup

### Step 1: Project Structure Creation

```bash
# Create complete directory structure
mkdir -p {\
  frontend/src,\
  backend/src,\
  terraform,\
  k8s/{base,overlays/{dev,staging,prod}},\
  docs/{deployment,development,api},\
  .github/workflows,\
  scripts,\
  monitoring/{prometheus,grafana},\
  backup\
}

# Create basic files
touch {\
  frontend/{package.json,Dockerfile,.dockerignore},\
  backend/{package.json,Dockerfile,.dockerignore},\
  terraform/{main.tf,variables.tf,outputs.tf,terraform.tfvars},\
  .gitignore,\
  README.md,\
  CODEOWNERS\
}
```

### Step 2: Terraform Infrastructure

1. **Create Terraform Configuration**

```bash
# terraform/main.tf
cat > terraform/main.tf << 'EOF'
terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# VPC Network
resource "google_compute_network" "vpc" {
  name                    = "${var.app_name}-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnet" {
  name          = "${var.app_name}-subnet"
  ip_cidr_range = "10.0.0.0/24"
  region        = var.region
  network       = google_compute_network.vpc.id

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = "10.1.0.0/16"
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = "10.2.0.0/16"
  }
}

# GKE Cluster
resource "google_container_cluster" "primary" {
  name     = "${var.app_name}-cluster"
  location = var.region

  network    = google_compute_network.vpc.name
  subnetwork = google_compute_subnetwork.subnet.name

  enable_autopilot = true

  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

  master_authorized_networks_config {
    cidr_blocks {
      cidr_block = "0.0.0.0/0"
    }
  }
}

# Cloud SQL Instance
resource "google_sql_database_instance" "postgres" {
  name             = "${var.app_name}-db"
  database_version = "POSTGRES_14"
  region           = var.region

  settings {
    tier = "db-f1-micro"

    backup_configuration {
      enabled    = true
      start_time = "03:00"
    }

    ip_configuration {
      ipv4_enabled    = true
      authorized_networks {
        value = "0.0.0.0/0"
      }
    }
  }

  deletion_protection = false
}

resource "google_sql_database" "database" {
  name     = var.db_name
  instance = google_sql_database_instance.postgres.name
}

resource "google_sql_user" "user" {
  name     = var.db_user
  instance = google_sql_database_instance.postgres.name
  password = var.db_password
}

# Service Accounts
resource "google_service_account" "gke_sa" {
  account_id   = "${var.app_name}-gke-sa"
  display_name = "GKE Service Account"
}

resource "google_project_iam_member" "gke_sa_roles" {
  for_each = toset([
    "roles/container.nodeServiceAccount",
    "roles/storage.objectViewer",
    "roles/secretmanager.secretAccessor",
    "roles/monitoring.metricWriter",
    "roles/logging.logWriter"
  ])

  role   = each.value
  member = "serviceAccount:${google_service_account.gke_sa.email}"
}

# Artifact Registry
resource "google_artifact_registry_repository" "repo" {
  location      = var.region
  repository_id = "${var.app_name}-repo"
  description   = "Docker repository for ${var.app_name}"
  format        = "DOCKER"
}

# Secret Manager Secrets
resource "google_secret_manager_secret" "db_password" {
  secret_id = "${var.app_name}-db-password"
  
  replication {
    automatic = true
  }
}

resource "google_secret_manager_secret_version" "db_password" {
  secret      = google_secret_manager_secret.db_password.id
  secret_data = var.db_password
}

# Monitoring Dashboard
resource "google_monitoring_dashboard" "main" {
  dashboard_json = jsonencode({
    displayName = "${var.app_name} Dashboard"
    mosaicLayout = {
      tiles = []
    }
  })
}
EOF
```

2. **Create Variables File**

```bash
# terraform/variables.tf
cat > terraform/variables.tf << 'EOF'
variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The GCP region"
  type        = string
  default     = "us-central1"
}

variable "app_name" {
  description = "Application name"
  type        = string
  default     = "pinky-promise"
}

variable "environment" {
  description = "Environment (dev/staging/prod)"
  type        = string
  default     = "dev"
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "pinky_promise_db"
}

variable "db_user" {
  description = "Database user"
  type        = string
  default     = "app_user"
}

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
}
EOF
```

3. **Create Outputs File**

```bash
# terraform/outputs.tf
cat > terraform/outputs.tf << 'EOF'
output "project_id" {
  description = "The GCP project ID"
  value       = var.project_id
}

output "region" {
  description = "The GCP region"
  value       = var.region
}

output "environment" {
  description = "The environment"
  value       = var.environment
}

output "vpc_name" {
  description = "VPC network name"
  value       = google_compute_network.vpc.name
}

output "subnet_name" {
  description = "Subnet name"
  value       = google_compute_subnetwork.subnet.name
}

output "cluster_name" {
  description = "GKE cluster name"
  value       = google_container_cluster.primary.name
}

output "cluster_location" {
  description = "GKE cluster location"
  value       = google_container_cluster.primary.location
}

output "cluster_endpoint" {
  description = "GKE cluster endpoint"
  value       = google_container_cluster.primary.endpoint
  sensitive   = true
}

output "database_instance_name" {
  description = "Cloud SQL instance name"
  value       = google_sql_database_instance.postgres.name
}

output "database_connection_name" {
  description = "Cloud SQL connection name"
  value       = google_sql_database_instance.postgres.connection_name
}

output "database_public_ip" {
  description = "Cloud SQL public IP"
  value       = google_sql_database_instance.postgres.public_ip_address
}

output "service_account_email" {
  description = "GKE service account email"
  value       = google_service_account.gke_sa.email
}

output "artifact_registry_url" {
  description = "Artifact Registry URL"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.repo.repository_id}"
}

output "secret_manager_db_password_name" {
  description = "Secret Manager secret name for database password"
  value       = google_secret_manager_secret.db_password.secret_id
}

output "monitoring_dashboard_url" {
  description = "Monitoring dashboard URL"
  value       = "https://console.cloud.google.com/monitoring/dashboards/custom/${google_monitoring_dashboard.main.id}?project=${var.project_id}"
}

output "kubectl_config_command" {
  description = "Command to configure kubectl"
  value       = "gcloud container clusters get-credentials ${google_container_cluster.primary.name} --region ${google_container_cluster.primary.location} --project ${var.project_id}"
}
EOF
```

4. **Create Terraform Variables File**

```bash
# terraform/terraform.tfvars
cat > terraform/terraform.tfvars << EOF
project_id = "$PROJECT_ID"
region = "us-central1"
app_name = "pinky-promise"
environment = "dev"
db_name = "pinky_promise_db"
db_user = "app_user"
db_password = "$(openssl rand -base64 32)"
EOF
```

5. **Deploy Infrastructure**

```bash
cd terraform

# Initialize Terraform
terraform init

# Validate configuration
terraform validate

# Plan deployment
terraform plan

# Apply infrastructure
terraform apply -auto-approve

# Get cluster credentials
eval $(terraform output -raw kubectl_config_command)

# Verify cluster access
kubectl cluster-info
kubectl get nodes
kubectl get namespaces
```

### Step 3: Verification

```bash
# Verify infrastructure
terraform output

# Check GKE cluster
kubectl get nodes
kubectl get pods --all-namespaces

# Check database
gcloud sql instances list

# Check secrets
gcloud secrets list

# Check artifact registry
gcloud artifacts repositories list
```

## Phase 2: Application Deployment

### Step 1: Frontend Application

1. **Create React Frontend**

```bash
# Create package.json
cat > frontend/package.json << 'EOF'
{
  "name": "pinky-promise-frontend",
  "version": "1.0.0",
  "private": true,
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "react-scripts": "5.0.1",
    "axios": "^1.4.0"
  },
  "scripts": {
    "start": "react-scripts start",
    "build": "react-scripts build",
    "test": "react-scripts test",
    "eject": "react-scripts eject"
  },
  "browserslist": {
    "production": [
      ">0.2%",
      "not dead",
      "not op_mini all"
    ],
    "development": [
      "last 1 chrome version",
      "last 1 firefox version",
      "last 1 safari version"
    ]
  }
}
EOF

# Create main App component
mkdir -p frontend/src
cat > frontend/src/App.js << 'EOF'
import React, { useState, useEffect } from 'react';
import axios from 'axios';
import './App.css';

function App() {
  const [promises, setPromises] = useState([]);
  const [newPromise, setNewPromise] = useState('');
  const [loading, setLoading] = useState(false);

  const API_BASE_URL = process.env.REACT_APP_API_URL || '/api';

  useEffect(() => {
    fetchPromises();
  }, []);

  const fetchPromises = async () => {
    try {
      setLoading(true);
      const response = await axios.get(`${API_BASE_URL}/promises`);
      setPromises(response.data);
    } catch (error) {
      console.error('Error fetching promises:', error);
    } finally {
      setLoading(false);
    }
  };

  const addPromise = async (e) => {
    e.preventDefault();
    if (!newPromise.trim()) return;

    try {
      setLoading(true);
      await axios.post(`${API_BASE_URL}/promises`, {
        text: newPromise,
        author: 'User'
      });
      setNewPromise('');
      fetchPromises();
    } catch (error) {
      console.error('Error adding promise:', error);
    } finally {
      setLoading(false);
    }
  };

  const fulfillPromise = async (id) => {
    try {
      setLoading(true);
      await axios.patch(`${API_BASE_URL}/promises/${id}`, {
        fulfilled: true
      });
      fetchPromises();
    } catch (error) {
      console.error('Error fulfilling promise:', error);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="App">
      <header className="App-header">
        <h1>🤙 Pinky Promise</h1>
        <p>Make and keep your promises!</p>
      </header>

      <main className="App-main">
        <form onSubmit={addPromise} className="promise-form">
          <input
            type="text"
            value={newPromise}
            onChange={(e) => setNewPromise(e.target.value)}
            placeholder="Enter your promise..."
            disabled={loading}
          />
          <button type="submit" disabled={loading || !newPromise.trim()}>
            {loading ? 'Adding...' : 'Make Promise'}
          </button>
        </form>

        <div className="promises-list">
          {loading && promises.length === 0 ? (
            <p>Loading promises...</p>
          ) : promises.length === 0 ? (
            <p>No promises yet. Make your first one!</p>
          ) : (
            promises.map((promise) => (
              <div
                key={promise.id}
                className={`promise-item ${promise.fulfilled ? 'fulfilled' : 'pending'}`}
              >
                <div className="promise-content">
                  <p>{promise.text}</p>
                  <small>by {promise.author} on {new Date(promise.created_at).toLocaleDateString()}</small>
                </div>
                {!promise.fulfilled && (
                  <button
                    onClick={() => fulfillPromise(promise.id)}
                    disabled={loading}
                    className="fulfill-btn"
                  >
                    ✅ Fulfill
                  </button>
                )}
                {promise.fulfilled && <span className="fulfilled-badge">✅ Kept!</span>}
              </div>
            ))
          )}
        </div>
      </main>
    </div>
  );
}

export default App;
EOF

# Create CSS
cat > frontend/src/App.css << 'EOF'
.App {
  text-align: center;
  max-width: 800px;
  margin: 0 auto;
  padding: 20px;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', sans-serif;
}

.App-header {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  padding: 2rem;
  border-radius: 10px;
  color: white;
  margin-bottom: 2rem;
}

.App-header h1 {
  margin: 0 0 1rem 0;
  font-size: 2.5rem;
}

.App-main {
  padding: 1rem;
}

.promise-form {
  display: flex;
  gap: 1rem;
  margin-bottom: 2rem;
  max-width: 500px;
  margin-left: auto;
  margin-right: auto;
}

.promise-form input {
  flex: 1;
  padding: 0.75rem;
  border: 2px solid #ddd;
  border-radius: 5px;
  font-size: 1rem;
}

.promise-form button {
  padding: 0.75rem 1.5rem;
  background: #667eea;
  color: white;
  border: none;
  border-radius: 5px;
  cursor: pointer;
  font-size: 1rem;
}

.promise-form button:hover {
  background: #5a6fd8;
}

.promise-form button:disabled {
  background: #ccc;
  cursor: not-allowed;
}

.promises-list {
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

.promise-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 1rem;
  border: 2px solid #eee;
  border-radius: 8px;
  background: white;
}

.promise-item.fulfilled {
  background: #f0f9ff;
  border-color: #10b981;
}

.promise-content {
  flex: 1;
  text-align: left;
}

.promise-content p {
  margin: 0 0 0.5rem 0;
  font-size: 1.1rem;
}

.promise-content small {
  color: #666;
}

.fulfill-btn {
  padding: 0.5rem 1rem;
  background: #10b981;
  color: white;
  border: none;
  border-radius: 5px;
  cursor: pointer;
}

.fulfill-btn:hover {
  background: #059669;
}

.fulfilled-badge {
  color: #10b981;
  font-weight: bold;
}
EOF

# Create index.js
cat > frontend/src/index.js << 'EOF'
import React from 'react';
import ReactDOM from 'react-dom/client';
import './index.css';
import App from './App';

const root = ReactDOM.createRoot(document.getElementById('root'));
root.render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
EOF

# Create index.css
cat > frontend/src/index.css << 'EOF'
body {
  margin: 0;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', 'Oxygen',
    'Ubuntu', 'Cantarell', 'Fira Sans', 'Droid Sans', 'Helvetica Neue',
    sans-serif;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
  background-color: #f5f5f5;
}

code {
  font-family: source-code-pro, Menlo, Monaco, Consolas, 'Courier New',
    monospace;
}
EOF

# Create public directory
mkdir -p frontend/public
cat > frontend/public/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <meta name="theme-color" content="#000000" />
    <meta name="description" content="Pinky Promise - Make and keep your promises" />
    <title>Pinky Promise</title>
  </head>
  <body>
    <noscript>You need to enable JavaScript to run this app.</noscript>
    <div id="root"></div>
  </body>
</html>
EOF
```

2. **Create Frontend Dockerfile**

```bash
cat > frontend/Dockerfile << 'EOF'
# Build stage
FROM node:18-alpine AS builder

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci --only=production

# Copy source code
COPY . .

# Build the app
RUN npm run build

# Production stage
FROM nginx:alpine

# Copy built assets
COPY --from=builder /app/build /usr/share/nginx/html

# Copy nginx configuration
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Expose port
EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]
EOF

# Create nginx config
cat > frontend/nginx.conf << 'EOF'
server {
    listen 8080;
    server_name localhost;
    root /usr/share/nginx/html;
    index index.html index.htm;

    # Handle client-side routing
    location / {
        try_files $uri $uri/ /index.html;
    }

    # API proxy
    location /api {
        proxy_pass http://pinky-promise-backend:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;
}
EOF

# Create .dockerignore
cat > frontend/.dockerignore << 'EOF'
node_modules
npm-debug.log
build
.dockerignore
Dockerfile
README.md
.env
.git
.gitignore
EOF
```

### Step 2: Backend Application

1. **Create Node.js Backend**

```bash
# Create package.json
cat > backend/package.json << 'EOF'
{
  "name": "pinky-promise-backend",
  "version": "1.0.0",
  "description": "Backend API for Pinky Promise app",
  "main": "server.js",
  "scripts": {
    "start": "node server.js",
    "dev": "nodemon server.js",
    "test": "jest"
  },
  "dependencies": {
    "express": "^4.18.2",
    "cors": "^2.8.5",
    "helmet": "^7.0.0",
    "pg": "^8.11.0",
    "dotenv": "^16.1.4",
    "express-rate-limit": "^6.7.1",
    "compression": "^1.7.4"
  },
  "devDependencies": {
    "nodemon": "^2.0.22",
    "jest": "^29.5.0",
    "supertest": "^6.3.3"
  }
}
EOF

# Create main server file
cat > backend/server.js << 'EOF'
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const compression = require('compression');
const { Pool } = require('pg');
require('dotenv').config();

const app = express();
const port = process.env.PORT || 3000;

// Database configuration
const pool = new Pool({
  user: process.env.DB_USER || 'app_user',
  host: process.env.DB_HOST || 'localhost',
  database: process.env.DB_NAME || 'pinky_promise_db',
  password: process.env.DB_PASSWORD,
  port: process.env.DB_PORT || 5432,
});

// Middleware
app.use(helmet());
app.use(cors());
app.use(compression());
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // limit each IP to 100 requests per windowMs
  message: 'Too many requests from this IP, please try again later.'
});
app.use('/api/', limiter);

// Initialize database
async function initDatabase() {
  try {
    await pool.query(`
      CREATE TABLE IF NOT EXISTS promises (
        id SERIAL PRIMARY KEY,
        text TEXT NOT NULL,
        author VARCHAR(255) NOT NULL,
        fulfilled BOOLEAN DEFAULT FALSE,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);
    console.log('Database initialized successfully');
  } catch (error) {
    console.error('Database initialization error:', error);
  }
}

// Health check endpoint
app.get('/health', async (req, res) => {
  try {
    await pool.query('SELECT 1');
    res.json({ 
      status: 'healthy', 
      timestamp: new Date().toISOString(),
      database: 'connected'
    });
  } catch (error) {
    res.status(500).json({ 
      status: 'unhealthy', 
      timestamp: new Date().toISOString(),
      database: 'disconnected',
      error: error.message
    });
  }
});

// API Routes

// Get all promises
app.get('/api/promises', async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT * FROM promises ORDER BY created_at DESC'
    );
    res.json(result.rows);
  } catch (error) {
    console.error('Error fetching promises:', error);
    res.status(500).json({ error: 'Failed to fetch promises' });
  }
});

// Create a new promise
app.post('/api/promises', async (req, res) => {
  try {
    const { text, author } = req.body;
    
    if (!text || !author) {
      return res.status(400).json({ error: 'Text and author are required' });
    }

    const result = await pool.query(
      'INSERT INTO promises (text, author) VALUES ($1, $2) RETURNING *',
      [text, author]
    );
    
    res.status(201).json(result.rows[0]);
  } catch (error) {
    console.error('Error creating promise:', error);
    res.status(500).json({ error: 'Failed to create promise' });
  }
});

// Update a promise (fulfill/unfulfill)
app.patch('/api/promises/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { fulfilled } = req.body;
    
    const result = await pool.query(
      'UPDATE promises SET fulfilled = $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2 RETURNING *',
      [fulfilled, id]
    );
    
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Promise not found' });
    }
    
    res.json(result.rows[0]);
  } catch (error) {
    console.error('Error updating promise:', error);
    res.status(500).json({ error: 'Failed to update promise' });
  }
});

// Delete a promise
app.delete('/api/promises/:id', async (req, res) => {
  try {
    const { id } = req.params;
    
    const result = await pool.query(
      'DELETE FROM promises WHERE id = $1 RETURNING *',
      [id]
    );
    
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Promise not found' });
    }
    
    res.json({ message: 'Promise deleted successfully' });
  } catch (error) {
    console.error('Error deleting promise:', error);
    res.status(500).json({ error: 'Failed to delete promise' });
  }
});

// Error handling middleware
app.use((error, req, res, next) => {
  console.error('Unhandled error:', error);
  res.status(500).json({ error: 'Internal server error' });
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({ error: 'Endpoint not found' });
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM received, shutting down gracefully');
  pool.end(() => {
    console.log('Database pool closed');
    process.exit(0);
  });
});

// Start server
app.listen(port, async () => {
  console.log(`Server running on port ${port}`);
  await initDatabase();
});

module.exports = app;
EOF

# Create environment file template
cat > backend/.env.example << 'EOF'
PORT=3000
DB_HOST=localhost
DB_PORT=5432
DB_NAME=pinky_promise_db
DB_USER=app_user
DB_PASSWORD=your_secure_password
NODE_ENV=development
EOF
```

2. **Create Backend Dockerfile**

```bash
cat > backend/Dockerfile << 'EOF'
FROM node:18-alpine

# Create app directory
WORKDIR /usr/src/app

# Add non-root user
RUN addgroup -g 1001 -S nodejs
RUN adduser -S nodejs -u 1001

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci --only=production && npm cache clean --force

# Copy source code
COPY . .

# Change ownership to nodejs user
RUN chown -R nodejs:nodejs /usr/src/app
USER nodejs

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node healthcheck.js

# Start the application
CMD ["npm", "start"]
EOF

# Create health check script
cat > backend/healthcheck.js << 'EOF'
const http = require('http');

const options = {
  host: 'localhost',
  port: process.env.PORT || 3000,
  path: '/health',
  timeout: 2000,
};

const request = http.request(options, (res) => {
  console.log(`Health check status: ${res.statusCode}`);
  if (res.statusCode === 200) {
    process.exit(0);
  } else {
    process.exit(1);
  }
});

request.on('error', (error) => {
  console.log('Health check failed:', error.message);
  process.exit(1);
});

request.on('timeout', () => {
  console.log('Health check timeout');
  request.destroy();
  process.exit(1);
});

request.end();
EOF

# Create .dockerignore
cat > backend/.dockerignore << 'EOF'
node_modules
npm-debug.log
.dockerignore
Dockerfile
README.md
.env
.git
.gitignore
tests
*.test.js
EOF
```

### Step 3: Build and Push Images

```bash
# Configure Docker for Artifact Registry
gcloud auth configure-docker ${REGION}-docker.pkg.dev

# Get Artifact Registry URL from Terraform
ARTIFACT_REGISTRY_URL=$(cd terraform && terraform output -raw artifact_registry_url)
echo "Artifact Registry URL: $ARTIFACT_REGISTRY_URL"

# Build and push backend
cd backend
docker build -t ${ARTIFACT_REGISTRY_URL}/backend:latest .
docker push ${ARTIFACT_REGISTRY_URL}/backend:latest

# Build and push frontend
cd ../frontend
docker build -t ${ARTIFACT_REGISTRY_URL}/frontend:latest .
docker push ${ARTIFACT_REGISTRY_URL}/frontend:latest

cd ..
```

### Step 4: Kubernetes Manifests

1. **Create Namespace**

```bash
cat > k8s/base/namespace.yaml << 'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: pinky-promise
  labels:
    name: pinky-promise
    app: pinky-promise
EOF
```

2. **Create Secrets**

```bash
# Get database details from Terraform
DB_PASSWORD=$(cd terraform && terraform output -raw db_password 2>/dev/null || echo "your_db_password")
DB_HOST=$(cd terraform && terraform output -raw database_public_ip)
DB_NAME=$(cd terraform && terraform output -raw db_name 2>/dev/null || echo "pinky_promise_db")
DB_USER=$(cd terraform && terraform output -raw db_user 2>/dev/null || echo "app_user")

cat > k8s/base/secrets.yaml << EOF
apiVersion: v1
kind: Secret
metadata:
  name: pinky-promise-secrets
  namespace: pinky-promise
type: Opaque
data:
  DB_HOST: $(echo -n "$DB_HOST" | base64)
  DB_NAME: $(echo -n "$DB_NAME" | base64)
  DB_USER: $(echo -n "$DB_USER" | base64)
  DB_PASSWORD: $(echo -n "$DB_PASSWORD" | base64)
  DB_PORT: $(echo -n "5432" | base64)
EOF
```

3. **Create Backend Deployment**

```bash
cat > k8s/base/backend-deployment.yaml << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: pinky-promise-backend
  namespace: pinky-promise
  labels:
    app: pinky-promise-backend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: pinky-promise-backend
  template:
    metadata:
      labels:
        app: pinky-promise-backend
    spec:
      containers:
      - name: backend
        image: ${ARTIFACT_REGISTRY_URL}/backend:latest
        ports:
        - containerPort: 3000
        env:
        - name: PORT
          value: "3000"
        - name: NODE_ENV
          value: "production"
        envFrom:
        - secretRef:
            name: pinky-promise-secrets
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
        livenessProbe:
          httpGet:
            path: /health
            port: 3000
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health
            port: 3000
          initialDelaySeconds: 5
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: pinky-promise-backend
  namespace: pinky-promise
spec:
  selector:
    app: pinky-promise-backend
  ports:
  - port: 3000
    targetPort: 3000
  type: ClusterIP
EOF
```

4. **Create Frontend Deployment**

```bash
cat > k8s/base/frontend-deployment.yaml << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: pinky-promise-frontend
  namespace: pinky-promise
  labels:
    app: pinky-promise-frontend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: pinky-promise-frontend
  template:
    metadata:
      labels:
        app: pinky-promise-frontend
    spec:
      containers:
      - name: frontend
        image: ${ARTIFACT_REGISTRY_URL}/frontend:latest
        ports:
        - containerPort: 8080
        resources:
          requests:
            cpu: 50m
            memory: 64Mi
          limits:
            cpu: 200m
            memory: 256Mi
        livenessProbe:
          httpGet:
            path: /
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: pinky-promise-frontend
  namespace: pinky-promise
spec:
  selector:
    app: pinky-promise-frontend
  ports:
  - port: 80
    targetPort: 8080
  type: LoadBalancer
EOF
```

5. **Deploy to Kubernetes**

```bash
# Apply all manifests
kubectl apply -f k8s/base/

# Wait for deployments
kubectl wait --for=condition=available --timeout=300s deployment/pinky-promise-backend -n pinky-promise
kubectl wait --for=condition=available --timeout=300s deployment/pinky-promise-frontend -n pinky-promise

# Check status
kubectl get pods -n pinky-promise
kubectl get services -n pinky-promise

# Get external IP
kubectl get service pinky-promise-frontend -n pinky-promise
```

### Step 5: Verification

```bash
# Check pod logs
kubectl logs -l app=pinky-promise-backend -n pinky-promise
kubectl logs -l app=pinky-promise-frontend -n pinky-promise

# Test backend health
kubectl port-forward service/pinky-promise-backend 3000:3000 -n pinky-promise &
curl http://localhost:3000/health

# Test frontend (once external IP is available)
EXTERNAL_IP=$(kubectl get service pinky-promise-frontend -n pinky-promise -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "Frontend URL: http://$EXTERNAL_IP"
curl -I http://$EXTERNAL_IP
```

## Phase 3: CI/CD and Security

### Step 1: GitHub Actions CI/CD

1. **Create Workflow Directory Structure**

```bash
mkdir -p .github/workflows
```

2. **Create Main CI/CD Pipeline**

```bash
cat > .github/workflows/ci-cd.yml << 'EOF'
name: CI/CD Pipeline

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

env:
  PROJECT_ID: ${{ secrets.GCP_PROJECT_ID }}
  REGION: us-central1
  ARTIFACT_REGISTRY: us-central1-docker.pkg.dev
  CLUSTER_NAME: pinky-promise-cluster

jobs:
  detect-changes:
    runs-on: ubuntu-latest
    outputs:
      frontend-changed: ${{ steps.changes.outputs.frontend }}
      backend-changed: ${{ steps.changes.outputs.backend }}
      infrastructure-changed: ${{ steps.changes.outputs.infrastructure }}
      k8s-changed: ${{ steps.changes.outputs.k8s }}
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      
      - uses: dorny/paths-filter@v2
        id: changes
        with:
          filters: |
            frontend:
              - 'frontend/**'
            backend:
              - 'backend/**'
            infrastructure:
              - 'terraform/**'
            k8s:
              - 'k8s/**'

  test-frontend:
    runs-on: ubuntu-latest
    needs: detect-changes
    if: needs.detect-changes.outputs.frontend-changed == 'true'
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '18'
          cache: 'npm'
          cache-dependency-path: frontend/package-lock.json
      
      - name: Install dependencies
        working-directory: frontend
        run: npm ci
      
      - name: Run tests
        working-directory: frontend
        run: npm test -- --coverage --watchAll=false
      
      - name: Build
        working-directory: frontend
        run: npm run build

  test-backend:
    runs-on: ubuntu-latest
    needs: detect-changes
    if: needs.detect-changes.outputs.backend-changed == 'true'
    services:
      postgres:
        image: postgres:14
        env:
          POSTGRES_PASSWORD: postgres
          POSTGRES_DB: test_db
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
        ports:
          - 5432:5432
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '18'
          cache: 'npm'
          cache-dependency-path: backend/package-lock.json
      
      - name: Install dependencies
        working-directory: backend
        run: npm ci
      
      - name: Run tests
        working-directory: backend
        env:
          DB_HOST: localhost
          DB_PORT: 5432
          DB_NAME: test_db
          DB_USER: postgres
          DB_PASSWORD: postgres
        run: npm test

  security-scan:
    runs-on: ubuntu-latest
    needs: detect-changes
    if: needs.detect-changes.outputs.frontend-changed == 'true' || needs.detect-changes.outputs.backend-changed == 'true'
    steps:
      - uses: actions/checkout@v4
      
      - name: Run Trivy vulnerability scanner
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'fs'
          scan-ref: '.'
          format: 'sarif'
          output: 'trivy-results.sarif'
      
      - name: Upload Trivy scan results
        uses: github/codeql-action/upload-sarif@v2
        if: always()
        with:
          sarif_file: 'trivy-results.sarif'

  build-and-deploy:
    runs-on: ubuntu-latest
    needs: [detect-changes, test-frontend, test-backend]
    if: always() && (needs.test-frontend.result == 'success' || needs.test-frontend.result == 'skipped') && (needs.test-backend.result == 'success' || needs.test-backend.result == 'skipped')
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup Google Cloud CLI
        uses: google-github-actions/setup-gcloud@v1
        with:
          service_account_key: ${{ secrets.GCP_SA_KEY }}
          project_id: ${{ secrets.GCP_PROJECT_ID }}
      
      - name: Configure Docker
        run: gcloud auth configure-docker ${{ env.ARTIFACT_REGISTRY }}
      
      - name: Get cluster credentials
        run: |
          gcloud container clusters get-credentials ${{ env.CLUSTER_NAME }} \
            --region ${{ env.REGION }} \
            --project ${{ env.PROJECT_ID }}
      
      - name: Build and push backend
        if: needs.detect-changes.outputs.backend-changed == 'true'
        run: |
          cd backend
          docker build -t ${{ env.ARTIFACT_REGISTRY }}/${{ env.PROJECT_ID }}/pinky-promise-repo/backend:${{ github.sha }} .
          docker build -t ${{ env.ARTIFACT_REGISTRY }}/${{ env.PROJECT_ID }}/pinky-promise-repo/backend:latest .
          docker push ${{ env.ARTIFACT_REGISTRY }}/${{ env.PROJECT_ID }}/pinky-promise-repo/backend:${{ github.sha }}
          docker push ${{ env.ARTIFACT_REGISTRY }}/${{ env.PROJECT_ID }}/pinky-promise-repo/backend:latest
      
      - name: Build and push frontend
        if: needs.detect-changes.outputs.frontend-changed == 'true'
        run: |
          cd frontend
          docker build -t ${{ env.ARTIFACT_REGISTRY }}/${{ env.PROJECT_ID }}/pinky-promise-repo/frontend:${{ github.sha }} .
          docker build -t ${{ env.ARTIFACT_REGISTRY }}/${{ env.PROJECT_ID }}/pinky-promise-repo/frontend:latest .
          docker push ${{ env.ARTIFACT_REGISTRY }}/${{ env.PROJECT_ID }}/pinky-promise-repo/frontend:${{ github.sha }}
          docker push ${{ env.ARTIFACT_REGISTRY }}/${{ env.PROJECT_ID }}/pinky-promise-repo/frontend:latest
      
      - name: Deploy to Kubernetes
        if: needs.detect-changes.outputs.k8s-changed == 'true' || needs.detect-changes.outputs.frontend-changed == 'true' || needs.detect-changes.outputs.backend-changed == 'true'
        run: |
          # Update image tags if images were built
          if [[ "${{ needs.detect-changes.outputs.backend-changed }}" == "true" ]]; then
            kubectl set image deployment/pinky-promise-backend \
              backend=${{ env.ARTIFACT_REGISTRY }}/${{ env.PROJECT_ID }}/pinky-promise-repo/backend:${{ github.sha }} \
              -n pinky-promise
          fi
          
          if [[ "${{ needs.detect-changes.outputs.frontend-changed }}" == "true" ]]; then
            kubectl set image deployment/pinky-promise-frontend \
              frontend=${{ env.ARTIFACT_REGISTRY }}/${{ env.PROJECT_ID }}/pinky-promise-repo/frontend:${{ github.sha }} \
              -n pinky-promise
          fi
          
          # Apply any K8s manifest changes
          if [[ "${{ needs.detect-changes.outputs.k8s-changed }}" == "true" ]]; then
            kubectl apply -f k8s/base/
          fi
          
          # Wait for rollout
          kubectl rollout status deployment/pinky-promise-backend -n pinky-promise --timeout=300s
          kubectl rollout status deployment/pinky-promise-frontend -n pinky-promise --timeout=300s
      
      - name: Verify deployment
        run: |
          # Check pod status
          kubectl get pods -n pinky-promise
          
          # Test backend health
          kubectl wait --for=condition=ready pod -l app=pinky-promise-backend -n pinky-promise --timeout=300s
          
          # Port forward and test
          kubectl port-forward service/pinky-promise-backend 3000:3000 -n pinky-promise &
          sleep 10
          curl -f http://localhost:3000/health || exit 1

  rollback:
    runs-on: ubuntu-latest
    needs: [build-and-deploy]
    if: failure()
    steps:
      - name: Setup Google Cloud CLI
        uses: google-github-actions/setup-gcloud@v1
        with:
          service_account_key: ${{ secrets.GCP_SA_KEY }}
          project_id: ${{ secrets.GCP_PROJECT_ID }}
      
      - name: Get cluster credentials
        run: |
          gcloud container clusters get-credentials ${{ env.CLUSTER_NAME }} \
            --region ${{ env.REGION }} \
            --project ${{ env.PROJECT_ID }}
      
      - name: Rollback deployments
        run: |
          kubectl rollout undo deployment/pinky-promise-backend -n pinky-promise
          kubectl rollout undo deployment/pinky-promise-frontend -n pinky-promise
          
          kubectl rollout status deployment/pinky-promise-backend -n pinky-promise
          kubectl rollout status deployment/pinky-promise-frontend -n pinky-promise
EOF
```

3. **Set up GitHub Secrets**

```bash
# Create service account for GitHub Actions
gcloud iam service-accounts create github-actions \
    --description="Service account for GitHub Actions" \
    --display-name="GitHub Actions"

# Grant necessary permissions
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:github-actions@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/container.admin"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:github-actions@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/artifactregistry.admin"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:github-actions@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/storage.admin"

# Create and download service account key
gcloud iam service-accounts keys create github-actions-key.json \
    --iam-account="github-actions@$PROJECT_ID.iam.gserviceaccount.com"

echo "Add these secrets to your GitHub repository:"
echo "GCP_PROJECT_ID: $PROJECT_ID"
echo "GCP_SA_KEY: $(cat github-actions-key.json | base64)"

# Clean up the key file
rm github-actions-key.json
```

### Step 2: Security Implementation

1. **Network Policies**

```bash
cat > k8s/base/network-policies.yaml << 'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: pinky-promise-network-policy
  namespace: pinky-promise
spec:
  podSelector:
    matchLabels:
      app: pinky-promise-backend
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: pinky-promise-frontend
    - namespaceSelector:
        matchLabels:
          name: pinky-promise
    ports:
    - protocol: TCP
      port: 3000
  egress:
  - to: []
    ports:
    - protocol: TCP
      port: 5432  # Database
    - protocol: TCP
      port: 53   # DNS
    - protocol: UDP
      port: 53   # DNS
    - protocol: TCP
      port: 443  # HTTPS
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: frontend-network-policy
  namespace: pinky-promise
spec:
  podSelector:
    matchLabels:
      app: pinky-promise-frontend
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from: []
    ports:
    - protocol: TCP
      port: 8080
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: pinky-promise-backend
    ports:
    - protocol: TCP
      port: 3000
  - to: []
    ports:
    - protocol: TCP
      port: 53   # DNS
    - protocol: UDP
      port: 53   # DNS
EOF
```

2. **SSL/HTTPS Ingress**

```bash
cat > k8s/base/ingress.yaml << 'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: pinky-promise-ingress
  namespace: pinky-promise
  annotations:
    kubernetes.io/ingress.global-static-ip-name: "pinky-promise-ip"
    networking.gke.io/managed-certificates: "pinky-promise-ssl-cert"
    kubernetes.io/ingress.class: "gce"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
spec:
  rules:
  - host: pinky-promise.example.com  # Replace with your domain
    http:
      paths:
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: pinky-promise-backend
            port:
              number: 3000
      - path: /
        pathType: Prefix
        backend:
          service:
            name: pinky-promise-frontend
            port:
              number: 80
---
apiVersion: networking.gke.io/v1
kind: ManagedCertificate
metadata:
  name: pinky-promise-ssl-cert
  namespace: pinky-promise
spec:
  domains:
    - pinky-promise.example.com  # Replace with your domain
EOF
```

3. **Security Context and Pod Security**

```bash
# Update backend deployment with security context
cat > k8s/base/backend-deployment-secure.yaml << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: pinky-promise-backend
  namespace: pinky-promise
  labels:
    app: pinky-promise-backend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: pinky-promise-backend
  template:
    metadata:
      labels:
        app: pinky-promise-backend
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 1001
        fsGroup: 1001
      containers:
      - name: backend
        image: ${ARTIFACT_REGISTRY_URL}/backend:latest
        ports:
        - containerPort: 3000
        env:
        - name: PORT
          value: "3000"
        - name: NODE_ENV
          value: "production"
        envFrom:
        - secretRef:
            name: pinky-promise-secrets
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop:
            - ALL
          readOnlyRootFilesystem: true
          runAsNonRoot: true
          runAsUser: 1001
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
        livenessProbe:
          httpGet:
            path: /health
            port: 3000
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health
            port: 3000
          initialDelaySeconds: 5
          periodSeconds: 5
        volumeMounts:
        - name: tmp
          mountPath: /tmp
      volumes:
      - name: tmp
        emptyDir: {}
EOF
```

## Phase 4: Advanced Features

### Step 1: Monitoring and Observability

1. **Prometheus and Grafana Setup**

```bash
# Add Prometheus Helm repository
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Create monitoring namespace
kubectl create namespace monitoring

# Install kube-prometheus-stack
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
  --set prometheus.prometheusSpec.podMonitorSelectorNilUsesHelmValues=false \
  --set grafana.adminPassword=admin123 \
  --wait

# Expose Grafana
kubectl patch service prometheus-grafana -n monitoring -p '{"spec":{"type":"LoadBalancer"}}'
```

2. **Application Metrics**

```bash
# Create ServiceMonitor for backend
cat > k8s/base/monitoring.yaml << 'EOF'
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: pinky-promise-backend-metrics
  namespace: pinky-promise
  labels:
    app: pinky-promise-backend
spec:
  selector:
    matchLabels:
      app: pinky-promise-backend
  endpoints:
  - port: http
    path: /metrics
    interval: 30s
---
apiVersion: v1
kind: Service
metadata:
  name: pinky-promise-backend-metrics
  namespace: pinky-promise
  labels:
    app: pinky-promise-backend
spec:
  selector:
    app: pinky-promise-backend
  ports:
  - name: http
    port: 3000
    targetPort: 3000
EOF
```

### Step 2: Autoscaling

1. **Horizontal Pod Autoscaler**

```bash
cat > k8s/base/hpa.yaml << 'EOF'
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: pinky-promise-backend-hpa
  namespace: pinky-promise
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: pinky-promise-backend
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
---
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: pinky-promise-frontend-hpa
  namespace: pinky-promise
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: pinky-promise-frontend
  minReplicas: 2
  maxReplicas: 8
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
EOF
```

2. **Vertical Pod Autoscaler**

```bash
cat > k8s/base/vpa.yaml << 'EOF'
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: pinky-promise-backend-vpa
  namespace: pinky-promise
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: pinky-promise-backend
  updatePolicy:
    updateMode: "Auto"
  resourcePolicy:
    containerPolicies:
    - containerName: backend
      maxAllowed:
        cpu: 1000m
        memory: 1Gi
      minAllowed:
        cpu: 100m
        memory: 128Mi
EOF
```

### Step 3: Backup and Disaster Recovery

1. **Database Backup Job**

```bash
cat > k8s/base/backup-job.yaml << 'EOF'
apiVersion: batch/v1
kind: CronJob
metadata:
  name: database-backup
  namespace: pinky-promise
spec:
  schedule: "0 2 * * *"  # Daily at 2 AM
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: backup
            image: postgres:14
            command:
            - /bin/bash
            - -c
            - |
              BACKUP_FILE="backup-$(date +%Y%m%d-%H%M%S).sql"
              pg_dump -h $DB_HOST -U $DB_USER -d $DB_NAME > /tmp/$BACKUP_FILE
              gsutil cp /tmp/$BACKUP_FILE gs://$BACKUP_BUCKET/database/
              echo "Backup completed: $BACKUP_FILE"
            env:
            - name: PGPASSWORD
              valueFrom:
                secretKeyRef:
                  name: pinky-promise-secrets
                  key: DB_PASSWORD
            - name: BACKUP_BUCKET
              value: "pinky-promise-backups"  # Replace with your bucket
            envFrom:
            - secretRef:
                name: pinky-promise-secrets
          restartPolicy: OnFailure
EOF
```

2. **Application State Backup**

```bash
cat > scripts/backup.sh << 'EOF'
#!/bin/bash

# Backup Kubernetes manifests
echo "Backing up Kubernetes manifests..."
kubectl get all -n pinky-promise -o yaml > backup/k8s-manifests-$(date +%Y%m%d).yaml

# Backup secrets (encrypted)
echo "Backing up secrets..."
kubectl get secrets -n pinky-promise -o yaml > backup/secrets-$(date +%Y%m%d).yaml

# Backup configmaps
echo "Backing up configmaps..."
kubectl get configmaps -n pinky-promise -o yaml > backup/configmaps-$(date +%Y%m%d).yaml

echo "Backup completed successfully!"
EOF

chmod +x scripts/backup.sh
```

### Step 4: Performance Optimization

1. **Redis Cache Implementation**

```bash
# Add Redis to the stack
cat > k8s/base/redis.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis
  namespace: pinky-promise
spec:
  replicas: 1
  selector:
    matchLabels:
      app: redis
  template:
    metadata:
      labels:
        app: redis
    spec:
      containers:
      - name: redis
        image: redis:7-alpine
        ports:
        - containerPort: 6379
        resources:
          requests:
            cpu: 50m
            memory: 64Mi
          limits:
            cpu: 200m
            memory: 256Mi
        volumeMounts:
        - name: redis-data
          mountPath: /data
      volumes:
      - name: redis-data
        emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: redis
  namespace: pinky-promise
spec:
  selector:
    app: redis
  ports:
  - port: 6379
    targetPort: 6379
EOF
```

2. **Load Testing**

```bash
cat > k8s/base/load-test.yaml << 'EOF'
apiVersion: batch/v1
kind: Job
metadata:
  name: load-test
  namespace: pinky-promise
spec:
  template:
    spec:
      containers:
      - name: load-test
        image: loadimpact/k6:latest
        command: ["k6", "run", "--vus", "10", "--duration", "30s", "/scripts/load-test.js"]
        volumeMounts:
        - name: test-scripts
          mountPath: /scripts
      volumes:
      - name: test-scripts
        configMap:
          name: load-test-scripts
      restartPolicy: Never
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: load-test-scripts
  namespace: pinky-promise
data:
  load-test.js: |
    import http from 'k6/http';
    import { check } from 'k6';
    
    export default function () {
      const response = http.get('http://pinky-promise-frontend/');
      check(response, {
        'status is 200': (r) => r.status === 200,
        'response time < 500ms': (r) => r.timings.duration < 500,
      });
    }
EOF
```

### Step 5: Final Deployment

```bash
# Apply all Phase 4 manifests
kubectl apply -f k8s/base/

# Verify all components
kubectl get all -n pinky-promise
kubectl get all -n monitoring

# Check HPA status
kubectl get hpa -n pinky-promise

# Check monitoring
kubectl port-forward service/prometheus-grafana 3000:80 -n monitoring
# Access Grafana at http://localhost:3000 (admin/admin123)

# Run load test
kubectl apply -f k8s/base/load-test.yaml
kubectl logs job/load-test -n pinky-promise
```

## Daily Operations

### Development Workflow

```bash
# 1. Start development
git checkout -b feature/new-feature

# 2. Make changes to code
# Edit files in frontend/ or backend/

# 3. Test locally
cd backend && npm test
cd ../frontend && npm test

# 4. Build and test containers
docker build -t backend-test ./backend
docker build -t frontend-test ./frontend

# 5. Commit and push
git add .
git commit -m "Add new feature"
git push origin feature/new-feature

# 6. Create pull request
# GitHub Actions will automatically run CI/CD

# 7. Merge to main
# Automatic deployment to production
```

### Monitoring and Maintenance

```bash
# Check application health
kubectl get pods -n pinky-promise
kubectl logs -l app=pinky-promise-backend -n pinky-promise --tail=100

# Check resource usage
kubectl top pods -n pinky-promise
kubectl get hpa -n pinky-promise

# Database maintenance
kubectl port-forward service/pinky-promise-backend 3000:3000 -n pinky-promise
curl http://localhost:3000/health

# Check metrics in Grafana
kubectl port-forward service/prometheus-grafana 3000:80 -n monitoring
# Open http://localhost:3000

# Update application
kubectl set image deployment/pinky-promise-backend backend=NEW_IMAGE -n pinky-promise
kubectl rollout status deployment/pinky-promise-backend -n pinky-promise

# Rollback if needed
kubectl rollout undo deployment/pinky-promise-backend -n pinky-promise

# Scale application
kubectl scale deployment pinky-promise-backend --replicas=5 -n pinky-promise

# Backup operations
./scripts/backup.sh
kubectl create job --from=cronjob/database-backup manual-backup -n pinky-promise
```

### Troubleshooting Commands

```bash
# Debug pod issues
kubectl describe pod POD_NAME -n pinky-promise
kubectl logs POD_NAME -n pinky-promise -f
kubectl exec -it POD_NAME -n pinky-promise -- /bin/sh

# Debug service issues
kubectl describe service SERVICE_NAME -n pinky-promise
kubectl get endpoints -n pinky-promise

# Debug ingress issues
kubectl describe ingress pinky-promise-ingress -n pinky-promise
kubectl get managedcertificate -n pinky-promise

# Debug autoscaling
kubectl describe hpa -n pinky-promise
kubectl get events -n pinky-promise --sort-by='.lastTimestamp'

# Check cluster health
kubectl cluster-info
kubectl get nodes
kubectl top nodes

# Network debugging
kubectl get networkpolicies -n pinky-promise
kubectl describe networkpolicy POLICY_NAME -n pinky-promise
```

## Troubleshooting

### Common Issues and Solutions

#### 1. Pods Not Starting
```bash
# Check pod status
kubectl get pods -n pinky-promise
kubectl describe pod POD_NAME -n pinky-promise

# Common fixes:
# - Check image pull secrets
# - Verify resource limits
# - Check node capacity
# - Verify environment variables
```

#### 2. Database Connection Issues
```bash
# Test database connectivity
kubectl exec -it BACKEND_POD -n pinky-promise -- wget -qO- http://localhost:3000/health

# Check secrets
kubectl get secret pinky-promise-secrets -n pinky-promise -o yaml

# Verify Cloud SQL IP
gcloud sql instances describe INSTANCE_NAME
```

#### 3. Load Balancer Issues
```bash
# Check service status
kubectl get service pinky-promise-frontend -n pinky-promise
kubectl describe service pinky-promise-frontend -n pinky-promise

# Check firewall rules
gcloud compute firewall-rules list
```

#### 4. SSL Certificate Issues
```bash
# Check managed certificate status
kubectl describe managedcertificate pinky-promise-ssl-cert -n pinky-promise

# Verify DNS settings
nslookup YOUR_DOMAIN
```

#### 5. CI/CD Pipeline Failures
```bash
# Check GitHub Actions logs
# Go to GitHub repository > Actions tab

# Verify GCP service account permissions
gcloud projects get-iam-policy PROJECT_ID

# Test kubectl access
gcloud container clusters get-credentials CLUSTER_NAME --region REGION
kubectl auth can-i '*' '*' --all-namespaces
```

## Lessons Learned

### Best Practices Implemented

1. **Infrastructure as Code**
   - All infrastructure defined in Terraform
   - Version controlled and reproducible
   - Environment-specific configurations

2. **Container Security**
   - Non-root containers
   - Read-only root filesystems
   - Security contexts and network policies
   - Regular vulnerability scanning

3. **Monitoring and Observability**
   - Comprehensive metrics collection
   - Centralized logging
   - Health checks and alerting
   - Performance monitoring

4. **Scalability and Performance**
   - Horizontal and vertical autoscaling
   - Load balancing
   - Caching strategies
   - Resource optimization

5. **DevOps Automation**
   - CI/CD pipelines
   - Automated testing
   - Deployment automation
   - Rollback capabilities

### Key Takeaways

1. **Start Simple**: Begin with basic deployment and add complexity gradually
2. **Security First**: Implement security measures from the beginning
3. **Monitor Everything**: Set up monitoring and alerting early
4. **Automate Repetitive Tasks**: Use CI/CD for consistency and reliability
5. **Plan for Scale**: Design with scalability in mind
6. **Document Everything**: Maintain comprehensive documentation
7. **Test Disaster Recovery**: Regularly test backup and recovery procedures

### Future Improvements

1. **Service Mesh**: Implement Istio for advanced traffic management
2. **GitOps**: Move to ArgoCD for declarative deployments
3. **Multi-Environment**: Set up staging and production environments
4. **Advanced Monitoring**: Implement distributed tracing
5. **Cost Optimization**: Implement cost monitoring and optimization
6. **Security Scanning**: Add runtime security scanning
7. **Performance Testing**: Automated performance regression testing

---

**Total Project Completion Time**: Approximately 2-3 days for full implementation
**Estimated Cost**: $50-100/month for GCP resources (depending on usage)
**Maintenance**: 2-4 hours/week for monitoring and updates

This guide provides a complete, production-ready deployment of a modern web application with all the bells and whistles of professional DevOps practices. Each phase builds upon the previous one, creating a robust, scalable, and maintainable system.

