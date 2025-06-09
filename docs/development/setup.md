# 🚀 Development Setup Guide

## Prerequisites

- Node.js 18+
- Docker & Docker Compose
- Google Cloud CLI (`gcloud`)
- kubectl
- Terraform (for infrastructure changes)

## Quick Start

### 1. Clone and Setup
```bash
git clone https://github.com/ashhar001/pinky-promise-app.git
cd pinky-promise-app
```

### 2. Frontend Development
```bash
cd pinky-promise-app
npm install
npm start
# Frontend runs on http://localhost:3000
```

### 3. Backend Development
```bash
cd backend
npm install
npm run dev
# Backend runs on http://localhost:5000
```

### 4. Local Development with Docker
```bash
# Run the full stack locally
docker-compose -f deploy/docker-compose.yml up
```

## Project Structure

```
pinky-promise-app/
├── pinky-promise-app/    # React frontend
├── backend/              # Node.js backend
├── terraform/            # Infrastructure as Code
├── kubernetes/           # K8s manifests
├── deploy/               # Deployment configs
├── docs/                 # Documentation
│   ├── architecture/     # Architecture docs
│   ├── deployment/       # Deployment guides
│   └── development/      # Development guides
└── .github/              # CI/CD workflows
```

## Development Workflow

### Making Changes

1. **Create feature branch**:
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes** in appropriate directory:
   - Frontend: `pinky-promise-app/`
   - Backend: `backend/`
   - Infrastructure: `terraform/`
   - Deployment: `kubernetes/` or `deploy/`

3. **Test locally**:
   ```bash
   # Frontend
   cd pinky-promise-app && npm test
   
   # Backend
   cd backend && npm test
   ```

4. **Commit and push**:
   ```bash
   git add .
   git commit -m "feat: description of your changes"
   git push origin feature/your-feature-name
   ```

5. **Create Pull Request** - CI/CD will automatically:
   - Run tests for changed components only
   - Validate infrastructure changes
   - Build Docker images (on main branch)

### Path-Based CI/CD

Our CI/CD system is smart and only builds/tests what you changed:

- **Frontend changes** (`pinky-promise-app/`) → Frontend CI only
- **Backend changes** (`backend/`) → Backend CI only
- **Infrastructure changes** (`terraform/`) → Terraform validation
- **Kubernetes changes** (`kubernetes/`, `deploy/`) → Manifest validation

### Connecting to Production Resources

```bash
# Get cluster credentials
gcloud container clusters get-credentials production-pinky-promise-cluster --region us-central1 --project pinky-promise-app

# Check production pods
kubectl get pods -n production

# View production logs
kubectl logs -f deployment/your-app -n production
```

## Environment Variables

### Frontend (.env)
```bash
REACT_APP_API_URL=http://localhost:5000/api
REACT_APP_RECAPTCHA_SITE_KEY=your-recaptcha-key
```

### Backend (.env)
```bash
NODE_ENV=development
PORT=5000
DATABASE_URL=postgresql://user:pass@localhost:5432/pinky_promise
JWT_SECRET=your-jwt-secret
JWT_REFRESH_SECRET=your-refresh-secret
```

## Debugging

### Frontend Debugging
```bash
# Run with debugging
npm start
# Use React Developer Tools in browser
```

### Backend Debugging
```bash
# Run with Node debugger
npm run debug
# Attach VS Code debugger to port 9229
```

### Production Debugging
```bash
# Check pod status
kubectl describe pod <pod-name> -n production

# View pod logs
kubectl logs <pod-name> -n production

# Execute into pod
kubectl exec -it <pod-name> -n production -- /bin/bash
```

## Contributing

1. Follow the existing code style
2. Write tests for new features
3. Update documentation as needed
4. Ensure CI/CD passes before merging
5. All changes require PR review from @ashhar001

## Getting Help

- Check existing documentation in `/docs/`
- Review CI/CD logs in GitHub Actions
- Check monitoring dashboard for production issues
- Contact @ashhar001 for infrastructure questions

