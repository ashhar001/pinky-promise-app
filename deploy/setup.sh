#!/bin/bash

# Pinky Promise App - Deployment Setup Script
# This script helps set up the deployment environment for the Pinky Promise application.

# Set strict error handling
set -e

# Define colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Define log file
LOG_FILE="deploy_setup.log"
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")

# Create log file or truncate if exists
> "$LOG_FILE"

# Utility functions
log() {
  echo -e "${GREEN}[INFO]${NC} $1"
  echo "[$TIMESTAMP] [INFO] $1" >> "$LOG_FILE"
}

warn() {
  echo -e "${YELLOW}[WARNING]${NC} $1"
  echo "[$TIMESTAMP] [WARNING] $1" >> "$LOG_FILE"
}

error() {
  echo -e "${RED}[ERROR]${NC} $1"
  echo "[$TIMESTAMP] [ERROR] $1" >> "$LOG_FILE"
  exit 1
}

check_command() {
  if ! command -v "$1" &> /dev/null; then
    error "$1 is required but not installed. Please install it and try again."
  else
    log "$1 is installed ($(command -v $1))"
  fi
}

# Display banner
echo -e "${GREEN}"
echo "============================================================"
echo "            Pinky Promise App - Deployment Setup"
echo "============================================================"
echo -e "${NC}"

# Check prerequisites
log "Checking prerequisites..."
check_command "docker"
check_command "docker-compose"
check_command "gcloud"
check_command "node"
check_command "npm"

# Check Docker status
if ! docker info &>/dev/null; then
  warn "Docker is not running. Please start Docker and try again."
  exit 1
fi

# Check for project root directory
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
log "Project root directory: $PROJECT_ROOT"

if [ ! -d "$PROJECT_ROOT/backend" ] || [ ! -d "$PROJECT_ROOT/pinky-promise-app" ]; then
  error "Cannot find backend or frontend directories. Make sure you're running this script from the correct location."
fi

# Ensure deploy directory structure
log "Setting up deployment directory structure..."
mkdir -p "$PROJECT_ROOT/deploy/backend"
mkdir -p "$PROJECT_ROOT/deploy/frontend"
mkdir -p "$PROJECT_ROOT/deploy/scripts"

# Create environment files
log "Creating environment files..."

# Create backend .env file if it doesn't exist
if [ ! -f "$PROJECT_ROOT/backend/.env" ]; then
  log "Creating backend .env file..."
  cat > "$PROJECT_ROOT/backend/.env" << EOL
# Server Configuration
PORT=5001
NODE_ENV=development

# Database Configuration
DATABASE_URL=postgresql://postgres:postgres@localhost:5432/pinky_promise

# JWT Configuration
JWT_SECRET=local_jwt_secret
JWT_REFRESH_SECRET=local_jwt_refresh_secret

# reCAPTCHA Configuration
RECAPTCHA_SECRET_KEY=local_recaptcha_secret_key
EOL
  log "Backend .env file created"
else
  warn "Backend .env file already exists. Skipping creation."
fi

# Create frontend .env file if it doesn't exist
if [ ! -f "$PROJECT_ROOT/pinky-promise-app/.env" ]; then
  log "Creating frontend .env file..."
  cat > "$PROJECT_ROOT/pinky-promise-app/.env" << EOL
# API URL - Local development
REACT_APP_API_URL=http://localhost:5001
REACT_APP_RECAPTCHA_SITE_KEY=6LdMSUgrAAAAAFKCwbzfd18UmzlY7aez137XtsJh
EOL
  log "Frontend .env file created"
else
  warn "Frontend .env file already exists. Skipping creation."
fi

# Create docker-compose environment file
log "Creating docker-compose environment file..."
cat > "$PROJECT_ROOT/deploy/.env" << EOL
# Docker Compose Environment Variables
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres
POSTGRES_DB=pinky_promise
JWT_SECRET=local_jwt_secret
JWT_REFRESH_SECRET=local_jwt_refresh_secret
RECAPTCHA_SECRET_KEY=local_recaptcha_secret_key
EOL
log "Docker-compose .env file created"

# Check GCP configuration
log "Checking GCP configuration..."
if gcloud config get-value project &>/dev/null; then
  CURRENT_PROJECT=$(gcloud config get-value project)
  log "Currently configured GCP project: $CURRENT_PROJECT"
  
  read -p "Would you like to use this project for deployment? (y/n): " use_current_project
  if [[ "$use_current_project" != "y" ]]; then
    read -p "Enter the GCP project ID you want to use: " project_id
    gcloud config set project "$project_id" || error "Failed to set GCP project"
    log "GCP project set to: $project_id"
  fi
else
  warn "No GCP project configured."
  read -p "Enter the GCP project ID you want to use: " project_id
  gcloud config set project "$project_id" || error "Failed to set GCP project"
  log "GCP project set to: $project_id"
fi

# Create a cloud build test configuration
log "Creating test cloud build configuration..."
cat > "$PROJECT_ROOT/deploy/cloudbuild-test.yaml" << EOL
# Cloud Build test configuration
steps:
  # Install dependencies and run tests for backend
  - name: 'gcr.io/cloud-builders/npm'
    id: 'backend-install'
    dir: 'backend'
    args: ['ci']

  - name: 'gcr.io/cloud-builders/npm'
    id: 'backend-test'
    dir: 'backend'
    args: ['test']
    waitFor: ['backend-install']

  # Install dependencies and run tests for frontend
  - name: 'gcr.io/cloud-builders/npm'
    id: 'frontend-install'
    dir: 'pinky-promise-app'
    args: ['ci']

  - name: 'gcr.io/cloud-builders/npm'
    id: 'frontend-test'
    dir: 'pinky-promise-app'
    args: ['test', '--', '--watchAll=false']
    waitFor: ['frontend-install']

timeout: 1800s
EOL
log "Test cloud build configuration created"

# Create a deployment helper script
log "Creating deployment helper script..."
cat > "$PROJECT_ROOT/deploy/scripts/deploy-local.sh" << 'EOL'
#!/bin/bash
# Helper script for local deployment testing

set -e

# Navigate to project root
cd "$(dirname "${BASH_SOURCE[0]}")/../.."
PROJECT_ROOT="$(pwd)"

# Check if Docker is running
if ! docker info &>/dev/null; then
  echo "Error: Docker is not running. Please start Docker and try again."
  exit 1
fi

# Build and run the application with docker-compose
echo "Building and starting containers..."
docker-compose -f "$PROJECT_ROOT/deploy/docker-compose.yml" up --build -d

# Display container status
echo "Container status:"
docker-compose -f "$PROJECT_ROOT/deploy/docker-compose.yml" ps

# Display access URLs
echo ""
echo "Your application is now running!"
echo "Frontend: http://localhost"
echo "Backend API: http://localhost:5001"
echo ""
echo "To view logs:"
echo "  docker-compose -f \"$PROJECT_ROOT/deploy/docker-compose.yml\" logs -f"
echo ""
echo "To stop the application:"
echo "  docker-compose -f \"$PROJECT_ROOT/deploy/docker-compose.yml\" down"
EOL

chmod +x "$PROJECT_ROOT/deploy/scripts/deploy-local.sh"
log "Deployment helper script created and made executable"

# Success message
echo -e "${GREEN}"
echo "============================================================"
echo "            Setup completed successfully!"
echo "============================================================"
echo -e "${NC}"
echo "Next steps:"
echo "1. Review the deployment documentation in deploy/DEPLOYMENT.md"
echo "2. Test local deployment with: ./deploy/scripts/deploy-local.sh"
echo "3. Set up GCP resources following the guide in DEPLOYMENT.md"
echo ""
echo "For more details, check the log file: $LOG_FILE"

#!/bin/bash

# Pinky Promise App - Deployment Setup Script
# This script helps set up the deployment environment for the Pinky Promise application.

# Set strict error handling
set -e

# Define colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Define log file
LOG_FILE="deploy_setup.log"
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")

# Create log file or truncate if exists
> "$LOG_FILE"

# Utility functions
log() {
  echo -e "${GREEN}[INFO]${NC} $1"
  echo "[$TIMESTAMP] [INFO] $1" >> "$LOG_FILE"
}

warn() {
  echo -e "${YELLOW}[WARNING]${NC} $1"
  echo "[$TIMESTAMP] [WARNING] $1" >> "$LOG_FILE"
}

error() {
  echo -e "${RED}[ERROR]${NC} $1"
  echo "[$TIMESTAMP] [ERROR] $1" >> "$LOG_FILE"
  exit 1
}

check_command() {
  if ! command -v "$1" &> /dev/null; then
    error "$1 is required but not installed. Please install it and try again."
  else
    log "$1 is installed ($(command -v $1))"
  fi
}

# Display banner
echo -e "${GREEN}"
echo "============================================================"
echo "            Pinky Promise App - Deployment Setup"
echo "============================================================"
echo -e "${NC}"

# Check prerequisites
log "Checking prerequisites..."
check_command "docker"
check_command "docker-compose"
check_command "gcloud"
check_command "node"
check_command "npm"

# Check Docker status
if ! docker info &>/dev/null; then
  warn "Docker is not running. Please start Docker and try again."
  exit 1
fi

# Check for project root directory
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
log "Project root directory: $PROJECT_ROOT"

if [ ! -d "$PROJECT_ROOT/backend" ] || [ ! -d "$PROJECT_ROOT/pinky-promise-app" ]; then
  error "Cannot find backend or frontend directories. Make sure you're running this script from the correct location."
fi

# Ensure deploy directory structure
log "Setting up deployment directory structure..."
mkdir -p "$PROJECT_ROOT/deploy/backend"
mkdir -p "$PROJECT_ROOT/deploy/frontend"
mkdir -p "$PROJECT_ROOT/deploy/scripts"

# Create environment files
log "Creating environment files..."

# Create backend .env file if it doesn't exist
if [ ! -f "$PROJECT_ROOT/backend/.env" ]; then
  log "Creating backend .env file..."
  cat > "$PROJECT_ROOT/backend/.env" << EOL
# Server Configuration
PORT=5001
NODE_ENV=development

# Database Configuration
DATABASE_URL=postgresql://postgres:postgres@localhost:5432/pinky_promise

# JWT Configuration
JWT_SECRET=local_jwt_secret
JWT_REFRESH_SECRET=local_jwt_refresh_secret

# reCAPTCHA Configuration
RECAPTCHA_SECRET_KEY=local_recaptcha_secret_key
EOL
  log "Backend .env file created"
else
  warn "Backend .env file already exists. Skipping creation."
fi

# Create frontend .env file if it doesn't exist
if [ ! -f "$PROJECT_ROOT/pinky-promise-app/.env" ]; then
  log "Creating frontend .env file..."
  cat > "$PROJECT_ROOT/pinky-promise-app/.env" << EOL
# API URL - Local development
REACT_APP_API_URL=http://localhost:5001
REACT_APP_RECAPTCHA_SITE_KEY=6LdMSUgrAAAAAFKCwbzfd18UmzlY7aez137XtsJh
EOL
  log "Frontend .env file created"
else
  warn "Frontend .env file already exists. Skipping creation."
fi

# Create docker-compose environment file
log "Creating docker-compose environment file..."
cat > "$PROJECT_ROOT/deploy/.env" << EOL
# Docker Compose Environment Variables
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres
POSTGRES_DB=pinky_promise
JWT_SECRET=local_jwt_secret
JWT_REFRESH_SECRET=local_jwt_refresh_secret
RECAPTCHA_SECRET_KEY=local_recaptcha_secret_key
EOL
log "Docker-compose .env file created"

# Check GCP configuration
log "Checking GCP configuration..."
if gcloud config get-value project &>/dev/null; then
  CURRENT_PROJECT=$(gcloud config get-value project)
  log "Currently configured GCP project: $CURRENT_PROJECT"
  
  read -p "Would you like to use this project for deployment? (y/n): " use_current_project
  if [[ "$use_current_project" != "y" ]]; then
    read -p "Enter the GCP project ID you want to use: " project_id
    gcloud config set project "$project_id" || error "Failed to set GCP project"
    log "GCP project set to: $project_id"
  fi
else
  warn "No GCP project configured."
  read -p "Enter the GCP project ID you want to use: " project_id
  gcloud config set project "$project_id" || error "Failed to set GCP project"
  log "GCP project set to: $project_id"
fi

# Create a cloud build test configuration
log "Creating test cloud build configuration..."
cat > "$PROJECT_ROOT/deploy/cloudbuild-test.yaml" << EOL
# Cloud Build test configuration
steps:
  # Install dependencies and run tests for backend
  - name: 'gcr.io/cloud-builders/npm'
    id: 'backend-install'
    dir: 'backend'
    args: ['ci']

  - name: 'gcr.io/cloud-builders/npm'
    id: 'backend-test'
    dir: 'backend'
    args: ['test']
    waitFor: ['backend-install']

  # Install dependencies and run tests for frontend
  - name: 'gcr.io/cloud-builders/npm'
    id: 'frontend-install'
    dir: 'pinky-promise-app'
    args: ['ci']

  - name: 'gcr.io/cloud-builders/npm'
    id: 'frontend-test'
    dir: 'pinky-promise-app'
    args: ['test', '--', '--watchAll=false']
    waitFor: ['frontend-install']

timeout: 1800s
EOL
log "Test cloud build configuration created"

# Create a deployment helper script
log "Creating deployment helper script..."
cat > "$PROJECT_ROOT/deploy/scripts/deploy-local.sh" << 'EOL'
#!/bin/bash
# Helper script for local deployment testing

set -e

# Navigate to project root
cd "$(dirname "${BASH_SOURCE[0]}")/../.."
PROJECT_ROOT="$(pwd)"

# Check if Docker is running
if ! docker info &>/dev/null; then
  echo "Error: Docker is not running. Please start Docker and try again."
  exit 1
fi

# Build and run the application with docker-compose
echo "Building and starting containers..."
docker-compose -f "$PROJECT_ROOT/deploy/docker-compose.yml" up --build -d

# Display container status
echo "Container status:"
docker-compose -f "$PROJECT_ROOT/deploy/docker-compose.yml" ps

# Display access URLs
echo ""
echo "Your application is now running!"
echo "Frontend: http://localhost"
echo "Backend API: http://localhost:5001"
echo ""
echo "To view logs:"
echo "  docker-compose -f \"$PROJECT_ROOT/deploy/docker-compose.yml\" logs -f"
echo ""
echo "To stop the application:"
echo "  docker-compose -f \"$PROJECT_ROOT/deploy/docker-compose.yml\" down"
EOL

chmod +x "$PROJECT_ROOT/deploy/scripts/deploy-local.sh"
log "Deployment helper script created and made executable"

# Success message
echo -e "${GREEN}"
echo "============================================================"
echo "            Setup completed successfully!"
echo "============================================================"
echo -e "${NC}"
echo "Next steps:"
echo "1. Review the deployment documentation in deploy/DEPLOYMENT.md"
echo "2. Test local deployment with: ./deploy/scripts/deploy-local.sh"
echo "3. Set up GCP resources following the guide in DEPLOYMENT.md"
echo ""
echo "For more details, check the log file: $LOG_FILE"

