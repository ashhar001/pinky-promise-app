# Alternative Deployment Options for Pinky Promise App

## Overview

This document outlines various deployment alternatives to Cloud Run for the Pinky Promise application on Google Cloud Platform (GCP).

## Deployment Options Comparison

| Option | Complexity | Control | Scalability | Cost | Best For |
|--------|------------|---------|-------------|------|----------|
| **Google Kubernetes Engine (GKE)** | Medium-High | High | Excellent | Medium | Production apps needing fine control |
| **Compute Engine VMs** | Medium | Very High | Good | Low-Medium | Traditional deployments, custom configs |
| **App Engine** | Low | Medium | Excellent | Medium | Simple web apps, quick deployments |
| **Firebase Hosting + Cloud Functions** | Low | Low | Good | Low | Static sites with serverless backend |
| **Container-Optimized OS** | Medium | High | Manual | Low | Docker-focused deployments |

---

## Option 1: Google Kubernetes Engine (GKE) - **RECOMMENDED**

### Why Choose GKE?
- **Industry Standard**: Kubernetes is the de facto standard for container orchestration
- **High Control**: Fine-grained control over deployment, scaling, and networking
- **Production Ready**: Built for enterprise-grade applications
- **Future Proof**: Easy to migrate to other cloud providers or on-premises

### Architecture
```
┌─────────────────────────────────────────────────────────┐
│                    GKE Cluster                          │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐    │
│  │   Frontend  │  │   Backend   │  │   Database  │    │
│  │    Pods     │  │    Pods     │  │  (Cloud SQL)│    │
│  │   (React)   │  │  (Node.js)  │  │             │    │
│  └─────────────┘  └─────────────┘  └─────────────┘    │
│         │               │                │            │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐      │
│  │   Service   │ │   Service   │ │   ConfigMap │      │
│  │ (Load Bal.) │ │ (Load Bal.) │ │   Secrets   │      │
│  └─────────────┘ └─────────────┘ └─────────────┘      │
└─────────────────────────────────────────────────────────┘
```

### Implementation Steps

#### 1. Create GKE Cluster
```bash
# Create autopilot cluster (recommended for simplicity)
gcloud container clusters create-auto pinky-promise-cluster \
    --region=us-central1 \
    --release-channel=regular

# OR create standard cluster for more control
gcloud container clusters create pinky-promise-cluster \
    --region=us-central1 \
    --num-nodes=3 \
    --machine-type=e2-medium \
    --enable-autoscaling \
    --min-nodes=1 \
    --max-nodes=10
```

#### 2. Kubernetes Manifests

**backend-deployment.yaml**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: pinky-promise-backend
spec:
  replicas: 3
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
        image: gcr.io/PROJECT_ID/pinky-promise-backend:latest
        ports:
        - containerPort: 5001
        env:
        - name: NODE_ENV
          value: "production"
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: app-secrets
              key: database-url
        - name: JWT_SECRET
          valueFrom:
            secretKeyRef:
              name: app-secrets
              key: jwt-secret
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
---
apiVersion: v1
kind: Service
metadata:
  name: pinky-promise-backend-service
spec:
  selector:
    app: pinky-promise-backend
  ports:
  - port: 80
    targetPort: 5001
  type: ClusterIP
```

**frontend-deployment.yaml**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: pinky-promise-frontend
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
        image: gcr.io/PROJECT_ID/pinky-promise-frontend:latest
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
---
apiVersion: v1
kind: Service
metadata:
  name: pinky-promise-frontend-service
spec:
  selector:
    app: pinky-promise-frontend
  ports:
  - port: 80
    targetPort: 80
  type: LoadBalancer
```

**ingress.yaml** (For custom domain)
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: pinky-promise-ingress
  annotations:
    kubernetes.io/ingress.global-static-ip-name: "pinky-promise-ip"
    networking.gke.io/managed-certificates: "pinky-promise-ssl-cert"
spec:
  rules:
  - host: app.pinky-promise.com
    http:
      paths:
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: pinky-promise-backend-service
            port:
              number: 80
      - path: /
        pathType: Prefix
        backend:
          service:
            name: pinky-promise-frontend-service
            port:
              number: 80
```

#### 3. Deployment Script
```bash
#!/bin/bash
# deploy-gke.sh

set -e

PROJECT_ID="your-project-id"
CLUSTER_NAME="pinky-promise-cluster"
REGION="us-central1"

# Get cluster credentials
gcloud container clusters get-credentials $CLUSTER_NAME --region=$REGION

# Create namespace
kubectl create namespace pinky-promise --dry-run=client -o yaml | kubectl apply -f -

# Create secrets
kubectl create secret generic app-secrets \
  --from-literal=database-url="postgresql://user:pass@host:5432/db" \
  --from-literal=jwt-secret="your-jwt-secret" \
  --namespace=pinky-promise

# Deploy applications
kubectl apply -f k8s/ --namespace=pinky-promise

# Wait for deployment
kubectl rollout status deployment/pinky-promise-backend --namespace=pinky-promise
kubectl rollout status deployment/pinky-promise-frontend --namespace=pinky-promise

echo "Deployment completed!"
echo "Frontend URL: $(kubectl get service pinky-promise-frontend-service --namespace=pinky-promise -o jsonpath='{.status.loadBalancer.ingress[0].ip}')"
```

---

## Option 2: Compute Engine VMs

### Why Choose Compute Engine?
- **Full Control**: Complete control over the operating system and environment
- **Cost Effective**: Can be very cost-effective, especially with sustained use discounts
- **Familiar**: Traditional server deployment model
- **Customizable**: Can install any software or configuration needed

### Architecture
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Load Balancer │    │  Frontend VMs   │    │  Backend VMs    │
│   (Cloud LB)    │───▶│   (Nginx)       │───▶│   (Node.js)     │
│                 │    │   (React)       │    │   (Express)     │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                │                      │
                                ▼                      ▼
                       ┌─────────────────┐    ┌─────────────────┐
                       │   Cloud SQL     │    │   Monitoring    │
                       │  (PostgreSQL)   │    │   (Ops Agent)   │
                       └─────────────────┘    └─────────────────┘
```

### Implementation

#### 1. Create VM Template
```bash
# Create instance template for backend
gcloud compute instance-templates create pinky-promise-backend-template \
    --machine-type=e2-medium \
    --image-family=ubuntu-2004-lts \
    --image-project=ubuntu-os-cloud \
    --boot-disk-size=20GB \
    --tags=backend-server \
    --metadata-from-file startup-script=startup-backend.sh

# Create instance template for frontend
gcloud compute instance-templates create pinky-promise-frontend-template \
    --machine-type=e2-small \
    --image-family=ubuntu-2004-lts \
    --image-project=ubuntu-os-cloud \
    --boot-disk-size=10GB \
    --tags=frontend-server \
    --metadata-from-file startup-script=startup-frontend.sh
```

#### 2. Startup Scripts

**startup-backend.sh**
```bash
#!/bin/bash

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
sudo usermod -aG docker $USER

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Pull and run backend container
sudo docker pull gcr.io/PROJECT_ID/pinky-promise-backend:latest
sudo docker run -d \
  --name pinky-promise-backend \
  --restart unless-stopped \
  -p 5001:5001 \
  -e NODE_ENV=production \
  -e DATABASE_URL="postgresql://user:pass@CLOUD_SQL_IP:5432/db" \
  gcr.io/PROJECT_ID/pinky-promise-backend:latest

# Install monitoring agent
curl -sSO https://dl.google.com/cloudagents/add-google-cloud-ops-agent-repo.sh
sudo bash add-google-cloud-ops-agent-repo.sh --also-install
```

#### 3. Managed Instance Groups
```bash
# Create managed instance groups
gcloud compute instance-groups managed create pinky-promise-backend-group \
    --template=pinky-promise-backend-template \
    --size=2 \
    --zone=us-central1-a

gcloud compute instance-groups managed create pinky-promise-frontend-group \
    --template=pinky-promise-frontend-template \
    --size=2 \
    --zone=us-central1-a

# Set up autoscaling
gcloud compute instance-groups managed set-autoscaling pinky-promise-backend-group \
    --max-num-replicas=5 \
    --min-num-replicas=2 \
    --target-cpu-utilization=0.7 \
    --zone=us-central1-a
```

---

## Option 3: App Engine

### Why Choose App Engine?
- **Simplest Deployment**: Just upload your code
- **Automatic Scaling**: Handles traffic spikes automatically
- **Integrated Services**: Built-in integration with other GCP services
- **Zero Infrastructure Management**: No servers to manage

### Limitations
- **Less Control**: Limited customization options
- **Runtime Restrictions**: Must fit App Engine's runtime model
- **Cost**: Can be expensive for high-traffic applications

### Implementation

#### 1. Backend App Engine

**app.yaml**
```yaml
runtime: nodejs16
service: backend

env_variables:
  NODE_ENV: production
  DATABASE_URL: postgresql://user:pass@/db?host=/cloudsql/PROJECT_ID:REGION:INSTANCE
  JWT_SECRET: your-jwt-secret

beta_settings:
  cloud_sql_instances: PROJECT_ID:REGION:INSTANCE_NAME

automatic_scaling:
  min_instances: 1
  max_instances: 10
  target_cpu_utilization: 0.6

resources:
  cpu: 1
  memory_gb: 1
  disk_size_gb: 10
```

#### 2. Frontend App Engine

**app.yaml** (Frontend)
```yaml
runtime: nodejs16
service: frontend

handlers:
- url: /static
  static_dir: build/static
  secure: always

- url: /(.*\.(json|ico|js))$
  static_files: build/\1
  upload: build/.*\.(json|ico|js)$
  secure: always

- url: /.*
  static_files: build/index.html
  upload: build/index.html
  secure: always

automatic_scaling:
  min_instances: 1
  max_instances: 5
```

#### 3. Deployment Commands
```bash
# Deploy backend
cd backend
gcloud app deploy --service=backend

# Deploy frontend (after building)
cd ../pinky-promise-app
npm run build
gcloud app deploy --service=frontend
```

---

## Option 4: Firebase Hosting + Cloud Functions

### Why Choose Firebase?
- **Global CDN**: Frontend served from global edge locations
- **Serverless Backend**: Pay only for what you use
- **Real-time Features**: Built-in real-time database and auth
- **Mobile Ready**: Easy mobile app integration

### Implementation

#### 1. Frontend on Firebase Hosting

**firebase.json**
```json
{
  "hosting": {
    "public": "build",
    "ignore": [
      "firebase.json",
      "**/.*",
      "**/node_modules/**"
    ],
    "rewrites": [
      {
        "source": "/api/**",
        "function": "api"
      },
      {
        "source": "**",
        "destination": "/index.html"
      }
    ]
  },
  "functions": {
    "source": "functions"
  }
}
```

#### 2. Backend as Cloud Functions

**functions/index.js**
```javascript
const functions = require('firebase-functions');
const express = require('express');
const app = express();

// Your existing Express routes
app.use('/auth', require('./routes/auth'));
app.use('/api', require('./routes/api'));

exports.api = functions.https.onRequest(app);
```

---

## Recommendation Matrix

### For Production Applications: **GKE Autopilot**
- ✅ Industry standard
- ✅ Excellent scaling
- ✅ Future-proof
- ✅ Good cost control
- ✅ High availability

### For Simple Applications: **App Engine**
- ✅ Easiest to deploy
- ✅ No infrastructure management
- ✅ Quick time to market
- ❌ Less control
- ❌ Potential vendor lock-in

### For Cost-Sensitive Deployments: **Compute Engine**
- ✅ Most cost-effective
- ✅ Full control
- ✅ Familiar deployment model
- ❌ More management overhead
- ❌ Manual scaling

### For Static-Heavy Apps: **Firebase Hosting**
- ✅ Global CDN
- ✅ Great performance
- ✅ Serverless backend
- ❌ Limited backend capabilities
- ❌ Firebase ecosystem lock-in

---

## Migration Path from Current Setup

### From Cloud Run to GKE
1. Use existing Docker images
2. Create Kubernetes manifests
3. Deploy to GKE cluster
4. Update DNS/load balancer
5. Monitor and optimize

### From Cloud Run to Compute Engine
1. Create VM templates with Docker
2. Set up managed instance groups
3. Configure load balancer
4. Deploy applications
5. Set up monitoring

### Next Steps
1. **Choose your preferred option** based on your requirements
2. **Review the implementation details** for your chosen option
3. **Test in a development environment** first
4. **Plan the migration strategy** from your current setup
5. **Set up monitoring and alerting** for the new deployment

Would you like me to provide detailed implementation for any specific option?

