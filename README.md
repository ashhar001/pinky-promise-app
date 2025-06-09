# Pinky Promise App

A sample Node.js application demonstrating GitOps deployment with ArgoCD on Google Kubernetes Engine.

## Quick Start

### Local Development
```bash
npm install
npm start
```

### Docker
```bash
docker build -t pinky-promise-app .
docker run -p 3000:3000 pinky-promise-app
```

## Deployment

This application is deployed via GitOps using ArgoCD, which monitors this repository and automatically deploys changes to the Kubernetes cluster.

## API Endpoints

- `GET /` - Welcome message
- `GET /health` - Health check
- `GET /ready` - Readiness check  
- `GET /metrics` - Prometheus metrics

## Project Structure

```
.
├── src/app.js              # Main application
├── k8s/                    # Kubernetes manifests
│   ├── base/               # Base configuration
│   └── overlays/           # Environment overlays
│       └── production/     # Production config
├── Dockerfile              # Container definition
└── package.json            # Dependencies
```

## ArgoCD Configuration

- **Repository**: https://github.com/ashhar001/pinky-promise-app.git
- **Path**: k8s/overlays/production
- **Sync**: Automatic with self-healing

## License

MIT License
