# Application Repository Setup Guide

This guide explains how to set up the **Application Repository** that ArgoCD will monitor for automatic deployments.

## 📋 Repository Structure for Application Repository

Create a new repository with this structure:

```
pinky-promise-app-source/
├── .github/
│   └── workflows/
│       ├── build-backend.yml       # Backend CI/CD pipeline
│       ├── build-frontend.yml      # Frontend CI/CD pipeline
│       └── update-manifests.yml    # Update K8s manifests
├── src/
│   ├── backend/                    # Backend source code
│   │   ├── Dockerfile
│   │   ├── package.json
│   │   └── src/
│   └── frontend/                   # Frontend source code
│       ├── Dockerfile
│       ├── package.json
│       └── src/
├── kubernetes/
│   └── manifests/                  # Kubernetes manifests (ArgoCD watches this)
│       ├── namespace.yaml
│       ├── backend/
│       │   ├── deployment.yaml
│       │   ├── service.yaml
│       │   ├── configmap.yaml
│       │   └── hpa.yaml
│       ├── frontend/
│       │   ├── deployment.yaml
│       │   ├── service.yaml
│       │   └── hpa.yaml
│       └── database/
│           ├── secret.yaml
│           └── configmap.yaml
└── scripts/
    └── update-image-tags.sh        # Script to update image tags
```

## 🔄 Application CI/CD Pipeline

### Backend Pipeline (`build-backend.yml`)

```yaml
name: Build and Deploy Backend

on:
  push:
    branches: [ main, develop ]
    paths:
      - 'src/backend/**'
      - '.github/workflows/build-backend.yml'
  pull_request:
    branches: [ main ]
    paths:
      - 'src/backend/**'

env:
  PROJECT_ID: 'pinky-promise-app'
  REGION: 'us-central1'
  REPOSITORY: 'pinky-promise-repo'
  IMAGE_NAME: 'pinky-promise-backend'

jobs:
  test:
    name: 'Test Backend'
    runs-on: ubuntu-latest
    steps:
    - name: Checkout
      uses: actions/checkout@v4
    
    - name: Setup Node.js
      uses: actions/setup-node@v4
      with:
        node-version: '18'
        cache: 'npm'
        cache-dependency-path: 'src/backend/package-lock.json'
    
    - name: Install dependencies
      run: |
        cd src/backend
        npm ci
    
    - name: Run tests
      run: |
        cd src/backend
        npm test
    
    - name: Run linting
      run: |
        cd src/backend
        npm run lint

  build-and-push:
    name: 'Build and Push'
    runs-on: ubuntu-latest
    needs: test
    if: github.ref == 'refs/heads/main'
    
    steps:
    - name: Checkout
      uses: actions/checkout@v4
    
    - name: Authenticate to Google Cloud
      uses: google-github-actions/auth@v2
      with:
        credentials_json: ${{ secrets.GCP_SA_KEY }}
    
    - name: Set up Cloud SDK
      uses: google-github-actions/setup-gcloud@v2
      with:
        project_id: ${{ env.PROJECT_ID }}
    
    - name: Configure Docker
      run: gcloud auth configure-docker ${{ env.REGION }}-docker.pkg.dev
    
    - name: Build Docker image
      run: |
        cd src/backend
        docker build -t ${{ env.REGION }}-docker.pkg.dev/${{ env.PROJECT_ID }}/${{ env.REPOSITORY }}/${{ env.IMAGE_NAME }}:${{ github.sha }} .
        docker build -t ${{ env.REGION }}-docker.pkg.dev/${{ env.PROJECT_ID }}/${{ env.REPOSITORY }}/${{ env.IMAGE_NAME }}:latest .
    
    - name: Push Docker image
      run: |
        docker push ${{ env.REGION }}-docker.pkg.dev/${{ env.PROJECT_ID }}/${{ env.REPOSITORY }}/${{ env.IMAGE_NAME }}:${{ github.sha }}
        docker push ${{ env.REGION }}-docker.pkg.dev/${{ env.PROJECT_ID }}/${{ env.REPOSITORY }}/${{ env.IMAGE_NAME }}:latest
    
    - name: Update Kubernetes manifests
      run: |
        # Update backend deployment with new image tag
        sed -i "s|image: .*pinky-promise-backend:.*|image: ${{ env.REGION }}-docker.pkg.dev/${{ env.PROJECT_ID }}/${{ env.REPOSITORY }}/${{ env.IMAGE_NAME }}:${{ github.sha }}|g" kubernetes/manifests/backend/deployment.yaml
        
        # Commit and push the changes
        git config --global user.name 'GitHub Actions'
        git config --global user.email 'actions@github.com'
        git add kubernetes/manifests/backend/deployment.yaml
        git commit -m "Update backend image to ${{ github.sha }}" || exit 0
        git push
```

### Frontend Pipeline (`build-frontend.yml`)

```yaml
name: Build and Deploy Frontend

on:
  push:
    branches: [ main, develop ]
    paths:
      - 'src/frontend/**'
      - '.github/workflows/build-frontend.yml'
  pull_request:
    branches: [ main ]
    paths:
      - 'src/frontend/**'

env:
  PROJECT_ID: 'pinky-promise-app'
  REGION: 'us-central1'
  REPOSITORY: 'pinky-promise-repo'
  IMAGE_NAME: 'pinky-promise-frontend'

jobs:
  test:
    name: 'Test Frontend'
    runs-on: ubuntu-latest
    steps:
    - name: Checkout
      uses: actions/checkout@v4
    
    - name: Setup Node.js
      uses: actions/setup-node@v4
      with:
        node-version: '18'
        cache: 'npm'
        cache-dependency-path: 'src/frontend/package-lock.json'
    
    - name: Install dependencies
      run: |
        cd src/frontend
        npm ci
    
    - name: Run tests
      run: |
        cd src/frontend
        npm test -- --coverage --watchAll=false
    
    - name: Build application
      run: |
        cd src/frontend
        npm run build

  build-and-push:
    name: 'Build and Push'
    runs-on: ubuntu-latest
    needs: test
    if: github.ref == 'refs/heads/main'
    
    steps:
    - name: Checkout
      uses: actions/checkout@v4
    
    - name: Authenticate to Google Cloud
      uses: google-github-actions/auth@v2
      with:
        credentials_json: ${{ secrets.GCP_SA_KEY }}
    
    - name: Set up Cloud SDK
      uses: google-github-actions/setup-gcloud@v2
      with:
        project_id: ${{ env.PROJECT_ID }}
    
    - name: Configure Docker
      run: gcloud auth configure-docker ${{ env.REGION }}-docker.pkg.dev
    
    - name: Build Docker image
      run: |
        cd src/frontend
        docker build -t ${{ env.REGION }}-docker.pkg.dev/${{ env.PROJECT_ID }}/${{ env.REPOSITORY }}/${{ env.IMAGE_NAME }}:${{ github.sha }} .
        docker build -t ${{ env.REGION }}-docker.pkg.dev/${{ env.PROJECT_ID }}/${{ env.REPOSITORY }}/${{ env.IMAGE_NAME }}:latest .
    
    - name: Push Docker image
      run: |
        docker push ${{ env.REGION }}-docker.pkg.dev/${{ env.PROJECT_ID }}/${{ env.REPOSITORY }}/${{ env.IMAGE_NAME }}:${{ github.sha }}
        docker push ${{ env.REGION }}-docker.pkg.dev/${{ env.PROJECT_ID }}/${{ env.REPOSITORY }}/${{ env.IMAGE_NAME }}:latest
    
    - name: Update Kubernetes manifests
      run: |
        # Update frontend deployment with new image tag
        sed -i "s|image: .*pinky-promise-frontend:.*|image: ${{ env.REGION }}-docker.pkg.dev/${{ env.PROJECT_ID }}/${{ env.REPOSITORY }}/${{ env.IMAGE_NAME }}:${{ github.sha }}|g" kubernetes/manifests/frontend/deployment.yaml
        
        # Commit and push the changes
        git config --global user.name 'GitHub Actions'
        git config --global user.email 'actions@github.com'
        git add kubernetes/manifests/frontend/deployment.yaml
        git commit -m "Update frontend image to ${{ github.sha }}" || exit 0
        git push
```

## 📦 Sample Kubernetes Manifests

### Namespace (`kubernetes/manifests/namespace.yaml`)

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: pinky-promise
  labels:
    name: pinky-promise
    app: pinky-promise
```

### Backend Deployment (`kubernetes/manifests/backend/deployment.yaml`)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: pinky-promise-backend
  namespace: pinky-promise
  labels:
    app: pinky-promise
    component: backend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: pinky-promise
      component: backend
  template:
    metadata:
      labels:
        app: pinky-promise
        component: backend
    spec:
      serviceAccountName: pinky-promise-backend
      containers:
      - name: backend
        image: us-central1-docker.pkg.dev/pinky-promise-app/pinky-promise-repo/pinky-promise-backend:latest
        ports:
        - containerPort: 5001
        env:
        - name: NODE_ENV
          value: "production"
        - name: PORT
          value: "5001"
        - name: DB_HOST
          valueFrom:
            secretKeyRef:
              name: database-secret
              key: host
        - name: DB_USER
          valueFrom:
            secretKeyRef:
              name: database-secret
              key: username
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: database-secret
              key: password
        - name: DB_NAME
          valueFrom:
            secretKeyRef:
              name: database-secret
              key: database
        - name: JWT_SECRET
          valueFrom:
            secretKeyRef:
              name: app-secrets
              key: jwt-secret
        resources:
          requests:
            memory: "256Mi"
            cpu: "200m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /health
            port: 5001
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: 5001
          initialDelaySeconds: 5
          periodSeconds: 5
```

### Backend Service (`kubernetes/manifests/backend/service.yaml`)

```yaml
apiVersion: v1
kind: Service
metadata:
  name: pinky-promise-backend
  namespace: pinky-promise
  labels:
    app: pinky-promise
    component: backend
spec:
  selector:
    app: pinky-promise
    component: backend
  ports:
  - port: 5001
    targetPort: 5001
    protocol: TCP
  type: ClusterIP
```

### Frontend Deployment (`kubernetes/manifests/frontend/deployment.yaml`)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: pinky-promise-frontend
  namespace: pinky-promise
  labels:
    app: pinky-promise
    component: frontend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: pinky-promise
      component: frontend
  template:
    metadata:
      labels:
        app: pinky-promise
        component: frontend
    spec:
      containers:
      - name: frontend
        image: us-central1-docker.pkg.dev/pinky-promise-app/pinky-promise-repo/pinky-promise-frontend:latest
        ports:
        - containerPort: 80
        env:
        - name: REACT_APP_API_URL
          value: "http://pinky-promise-backend:5001"
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5
```

## 🚀 Setting Up the Application Repository

### Step 1: Create the Repository

1. Create a new GitHub repository named `pinky-promise-app-source`
2. Clone your current application code into this repository
3. Organize the code according to the structure above

### Step 2: Move Application Code

```bash
# From your current infrastructure repository
mkdir -p ../pinky-promise-app-source/src
cp -r pinky-promise-app ../pinky-promise-app-source/src/frontend
cp -r backend ../pinky-promise-app-source/src/backend
```

### Step 3: Create Kubernetes Manifests

Copy and adapt the manifests from the `kubernetes/manifests` folder in this repository to the application repository.

### Step 4: Set Up GitHub Secrets

In the application repository, add the same GitHub secrets:
- `GCP_SA_KEY`
- Any other application-specific secrets

### Step 5: Update ArgoCD Configuration

In this infrastructure repository, update the ArgoCD application configuration to point to your new application repository:

```yaml
# kubernetes/argocd/pinky-promise-app.yaml
source:
  repoURL: https://github.com/YOUR_USERNAME/pinky-promise-app-source
```

## 🔄 GitOps Workflow

1. **Developer pushes code** to application repository
2. **GitHub Actions builds** and tests the application
3. **Docker images are built** and pushed to Artifact Registry
4. **Kubernetes manifests are updated** with new image tags
5. **ArgoCD detects changes** in the manifests
6. **ArgoCD automatically deploys** the updated application

## 🎯 Benefits of This Approach

- **Separation of Concerns**: Infrastructure and application code are separated
- **GitOps**: Declarative, version-controlled deployments
- **Automated**: No manual deployment steps required
- **Auditable**: Full deployment history in Git
- **Rollback**: Easy to revert to previous versions
- **Scalable**: Multiple applications can follow the same pattern

This setup provides a robust, scalable, and maintainable CI/CD pipeline that follows GitOps best practices!

